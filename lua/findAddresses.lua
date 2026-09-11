-- One-off helper: locates gPlayerParty and gMain in a running Soulgold ROM
-- (the ROM ships without a .sym).
--
-- Usage: with Soulgold running in mGBA, standing in the overworld with at least
-- one Pokémon in the party, load this script via Tools > Scripting. It scans
-- memory over two frames and prints the values to paste into sgPartyEvents.lua:
--
--   PARTY_LOC      = 0x0202XXXX
--   IN_BATTLE_ADDR = 0x0300XXXX
--
-- Set LEAD_NICKNAME to your lead Pokémon's exact nickname (as shown in game) to
-- also search for its encoded bytes directly - useful if the struct scan finds
-- nothing, since it dumps the raw bytes around every hit.
--
-- After the scan the script keeps printing the inBattle byte of each gMain
-- candidate every ~2s; enter and leave a battle and watch which one flips.

local LEAD_NICKNAME = ""   -- e.g. "CYNDAQUIL"

local EWRAM_BASE, EWRAM_SIZE = 0x02000000, 0x40000
local IWRAM_BASE, IWRAM_SIZE = 0x03000000, 0x8000
local CHUNK = 0x8000

local PARTY_MON_SIZE = 96
local NUM_SPECIES    = 1578

local function readBlock(base, size)
    local parts = {}
    for off = 0, size - 1, CHUNK do
        parts[#parts + 1] = emu:readRange(base + off, math.min(CHUNK, size - off))
    end
    return table.concat(parts)
end

local function u8(s, o)  return (string.unpack("<I1", s, o + 1)) end
local function u16(s, o) return (string.unpack("<I2", s, o + 1)) end
local function u32(s, o) return (string.unpack("<I4", s, o + 1)) end

local function isRomPtr(v)
    return v >= 0x08000000 and v < 0x0A000000
end

local function hexDump(s, o, len)
    local out = {}
    for i = 0, len - 1 do
        out[#out + 1] = string.format("%02X", u8(s, o + i))
        if i % 16 == 15 and i < len - 1 then out[#out + 1] = "\n    " end
    end
    return table.concat(out, " ")
end

------------------------------------------------
-- Text encoding (subset of the GBA charmap)
------------------------------------------------

local function encodeChar(c)
    local b = c:byte()
    if c == " " then return 0x00 end
    if b >= 48 and b <= 57 then return 0xA1 + (b - 48) end   -- 0-9
    if b >= 65 and b <= 90 then return 0xBB + (b - 65) end   -- A-Z
    if b >= 97 and b <= 122 then return 0xD5 + (b - 97) end  -- a-z
    return nil
end

local function decodeChar(b)
    if b == 0x00 then return " " end
    if b >= 0xA1 and b <= 0xAA then return string.char(48 + b - 0xA1) end
    if b >= 0xBB and b <= 0xD4 then return string.char(65 + b - 0xBB) end
    if b >= 0xD5 and b <= 0xEE then return string.char(97 + b - 0xD5) end
    return "?"
end

local function decodeName(s, o, len)
    local out = {}
    for i = 0, len - 1 do
        local b = u8(s, o + i)
        if b == 0xFF then break end
        out[#out + 1] = decodeChar(b)
    end
    return table.concat(out)
end

local function encodeName(name)
    local out = {}
    for c in name:gmatch(".") do
        local b = encodeChar(c)
        if not b then return nil end
        out[#out + 1] = string.char(b)
    end
    return table.concat(out) .. "\xFF"
end

------------------------------------------------
-- gPlayerParty
------------------------------------------------

local function plausibleName(s, o, len)
    local b0 = u8(s, o)
    if b0 == 0x00 or b0 == 0xFF then return false end
    for i = 0, len - 1 do
        local b = u8(s, o + i)
        if b == 0xFF then return true end
        if b ~= 0x00 and (b < 0xA1 or b > 0xEE) then return false end
    end
    return true
end

local function validMon(s, o)
    if u32(s, o) == 0 then return false end                       -- personality
    if not plausibleName(s, o + 8, 12) then return false end
    local species = u16(s, o + 32) & 0x7FF
    if species == 0 or species >= NUM_SPECIES then return false end
    if (u32(s, o + 76) & ~0x1FFF) ~= 0 then return false end       -- status: only known bits
    local level = u8(s, o + 80)
    if level == 0 or level > 100 then return false end
    local hp, maxHP = u16(s, o + 82), u16(s, o + 84)
    if maxHP == 0 or hp > maxHP then return false end
    return true
end

local function findParty(ewram)
    local hits = {}
    local last = EWRAM_SIZE - PARTY_MON_SIZE * 6
    for o = 8, last, 4 do
        if validMon(ewram, o) then
            local slot2 = o + PARTY_MON_SIZE
            if u32(ewram, slot2) == 0 or validMon(ewram, slot2) then
                hits[#hits + 1] = o
            end
        end
    end
    return hits
end

local function describeMon(s, o)
    return string.format("nick=\"%s\" species=%d lvl=%d hp=%d/%d status=0x%X",
        decodeName(s, o + 8, 12), u16(s, o + 32) & 0x7FF,
        u8(s, o + 80), u16(s, o + 82), u16(s, o + 84), u32(s, o + 76))
end

local function findNickname(ewram)
    if LEAD_NICKNAME == "" then return end
    local needle = encodeName(LEAD_NICKNAME)
    if not needle then
        console:warn("[finder] LEAD_NICKNAME has characters I can't encode (use A-Z, a-z, 0-9, space)")
        return
    end
    local pos = 1
    local n = 0
    while true do
        local i = ewram:find(needle, pos, true)
        if not i then break end
        n = n + 1
        local nickOff = i - 1
        local base = nickOff - 8
        console:log(string.format("[finder] nickname hit at 0x%08X (mon base would be 0x%08X)\n    %s\n    bytes from base-8:\n    %s",
            EWRAM_BASE + nickOff, EWRAM_BASE + base, describeMon(ewram, base), hexDump(ewram, base - 8, 104)))
        pos = i + 1
    end
    if n == 0 then
        console:warn("[finder] nickname \"" .. LEAD_NICKNAME .. "\" not found in EWRAM")
    end
end

------------------------------------------------
-- gMain
------------------------------------------------

local function findMain(a, b)
    local hits = {}
    for o = 0, IWRAM_SIZE - 0x440, 4 do
        local ok = true
        for f = 0x00, 0x18, 4 do                                -- callback pointers
            local v = u32(a, o + f)
            if v ~= 0 and not isRomPtr(v) then ok = false break end
        end
        if ok and isRomPtr(u32(a, o + 0x04))                   -- callback2 is never NULL
            and u32(b, o + 0x20) == u32(a, o + 0x20) + 1        -- vblankCounter1
            and u32(b, o + 0x24) == u32(a, o + 0x24) + 1        -- vblankCounter2
        then
            hits[#hits + 1] = IWRAM_BASE + o
        end
    end
    return hits
end

------------------------------------------------
-- Driver
------------------------------------------------

local snapA = nil
local mainHits = {}
local frames = 0

local function report()
    local ewram = readBlock(EWRAM_BASE, EWRAM_SIZE)
    local partyHits = findParty(ewram)

    if #partyHits == 0 then
        console:warn("[finder] no gPlayerParty candidates from struct scan")
    end
    for _, o in ipairs(partyHits) do
        console:log(string.format("[finder] PARTY_LOC = 0x%08X\n    slot1: %s\n    8 bytes before: %s",
            EWRAM_BASE + o, describeMon(ewram, o), hexDump(ewram, o - 8, 8)))
    end

    findNickname(ewram)

    local snapB = readBlock(IWRAM_BASE, IWRAM_SIZE)
    mainHits = findMain(snapA, snapB)

    if #mainHits == 0 then
        console:warn("[finder] no gMain candidates")
    end
    for _, addr in ipairs(mainHits) do
        console:log(string.format("[finder] gMain = 0x%08X  ->  IN_BATTLE_ADDR = 0x%08X", addr, addr + 0x439))
    end
end

local function tick()
    frames = frames + 1
    if frames == 1 then
        snapA = readBlock(IWRAM_BASE, IWRAM_SIZE)
        return
    end
    if frames == 2 then
        report()
        console:log("[finder] scan done - now watching gMain candidates; enter/leave a battle")
        return
    end
    if frames % 120 == 0 then
        for _, addr in ipairs(mainHits) do
            console:log(string.format("[finder] 0x%08X: state=%d flags=0x%02X inBattle=%d",
                addr, emu:read8(addr + 0x438), emu:read8(addr + 0x439), (emu:read8(addr + 0x439) >> 1) & 1))
        end
    end
end

callbacks:add("frame", tick)
console:log("[finder] scanning...")
