local HOST = "127.0.0.1"
local PORT = 8765

-- Found with findAddresses.lua (Soulgold ships no .sym). Re-run it if the ROM version changes.
-- Soulgold v1.1.4:
local PARTY_LOC      = 0x0203901C   -- gPlayerParty
local IN_BATTLE_ADDR = 0x030059F9   -- gMain + 0x439 (bit 1 = inBattle)

-- pokeemerald-expansion 1.15 layout (BoxPokemon = 76 bytes, unencrypted)
-- Party count is derived from leading non-empty slots; the game zeroes vacated slots
-- (CompactPartySlots), so gPlayerPartyCount is not needed.
local PARTY_SIZE     = 6
local PARTY_MON_SIZE = 96
local OFF_OTID       = 4    -- u32
local OFF_NICKNAME   = 8    -- u8[12]
local OFF_EGGFLAGS   = 21   -- u8: isBadEgg:1, hasSpecies:1, isEgg:1 (bit 2), blockBoxRS:1, daysSinceFormChange:3
local OFF_SHINYMOD   = 30   -- u16: hpLost:14, shinyModifier:1 (bit 14), modernFatefulEncounter:1
local OFF_SPECIES    = 32   -- u16, low 11 bits
local SHINY_ODDS     = 256  -- RELEASE_SHINY_ODDS; FLAG_RELEASE_SHINY_ODDS is set by new_game.inc
local OFF_STATUS     = 76   -- u32
local OFF_LEVEL      = 80   -- u8
local OFF_HP         = 82   -- u16
local OFF_MAXHP      = 84   -- u16

local sock = nil
local connected = false

local state = {
    party = nil,
    lockedParty = nil,
}

------------------------------------------------
-- JSON
------------------------------------------------

local function jsonEscape(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\"", "\\\"")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

local function isArray(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    local n = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        if k > n then n = k end
    end
    for i = 1, n do
        if tbl[i] == nil then
            return false
        end
    end
    return true
end

local function encodeJson(v)
    local t = type(v)

    if t == "number" then
        return tostring(v)
    elseif t == "string" then
        return "\"" .. jsonEscape(v) .. "\""
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        local parts = {}

        if isArray(v) then
            for i = 1, #v do
                parts[#parts + 1] = encodeJson(v[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, val in pairs(v) do
                parts[#parts + 1] = "\"" .. jsonEscape(k) .. "\":" .. encodeJson(val)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end

    return "null"
end

------------------------------------------------
-- Networking
------------------------------------------------

local function connect()
    if connected then
        return
    end

    local s = socket.connect(HOST, PORT)
    if not s then
        console:warn("party stream: socket connection failed")
        return
    end

    sock = s
    connected = true
    console:log("party stream connected")
end

local function emit(eventType, payload)
    if not connected or not sock then
        return
    end

    local msg = {
        type = eventType,
        frame = emu:currentFrame(),
        payload = payload
    }

    local ok, err = sock:send(encodeJson(msg) .. "\n")
    if ok == nil then
        connected = false
        console:warn("party stream: send failed: " .. tostring(err))
    end
end

------------------------------------------------
-- Battle state
------------------------------------------------

local function isInBattle()
    return (emu:read8(IN_BATTLE_ADDR) & 0x02) ~= 0
end

------------------------------------------------
-- Text decoding
------------------------------------------------

local terminator=0xFF
local monNameLength=12

local charmap = { [0]=
    " ", "À", "Á", "Â", "Ç", "È", "É", "Ê", "Ë", "Ì", "こ", "Î", "Ï", "Ò", "Ó", "Ô",
    "Œ", "Ù", "Ú", "Û", "Ñ", "ß", "à", "á", "ね", "ç", "è", "é", "ê", "ë", "ì", "ま",
    "î", "ï", "ò", "ó", "ô", "œ", "ù", "ú", "û", "ñ", "º", "ª", "�", "&", "+", "あ",
    "ぃ", "ぅ", "ぇ", "ぉ", "v", "=", "ょ", "が", "ぎ", "ぐ", "げ", "ご", "ざ", "じ", "ず", "ぜ",
    "ぞ", "だ", "ぢ", "づ", "で", "ど", "ば", "び", "ぶ", "べ", "ぼ", "ぱ", "ぴ", "ぷ", "ぺ", "ぽ",
    "っ", "¿", "¡", "P\u{200d}k", "M\u{200d}n", "P\u{200d}o", "K\u{200d}é", "�", "�", "�", "Í", "%", "(", ")", "セ", "ソ",
    "タ", "チ", "ツ", "テ", "ト", "ナ", "ニ", "ヌ", "â", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "í",
    "ミ", "ム", "メ", "モ", "ヤ", "ユ", "ヨ", "ラ", "リ", "⬆", "⬇", "⬅", "➡", "ヲ", "ン", "ァ",
    "ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", "ガ", "ギ", "グ", "ゲ", "ゴ", "ザ", "ジ", "ズ", "ゼ",
    "ゾ", "ダ", "ヂ", "ヅ", "デ", "ド", "バ", "ビ", "ブ", "ベ", "ボ", "パ", "ピ", "プ", "ペ", "ポ",
    "ッ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "!", "?", ".", "-", "・",
    "…", "“", "”", "‘", "’", "♂", "♀", "$", ",", "×", "/", "A", "B", "C", "D", "E",
    "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
    "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
    "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "▶",
    ":", "Ä", "Ö", "Ü", "ä", "ö", "ü", "⬆", "⬇", "⬅", "�", "�", "�", "�", "�", ""
}

local function toString(rawstring)
    local string = ""
    for _, char in ipairs({rawstring:byte(1, #rawstring)}) do
        if char == terminator then
            break
        end
        string = string..(charmap[char] or "")
    end
    return string
end

local function readNickname(address)
    return toString(emu:readRange(address + OFF_NICKNAME, monNameLength))
end

------------------------------------------------
-- Status decoding
------------------------------------------------

local function decodeStatus(status)
    if (status & 0x7) ~= 0 then return "sleep" end
    if (status & 0x80) ~= 0 then return "toxic" end
    if (status & 0x08) ~= 0 then return "poison" end
    if (status & 0x10) ~= 0 then return "burn" end
    if (status & 0x20) ~= 0 then return "freeze" end
    if (status & 0x1000) ~= 0 then return "freeze" end -- frostbite (Soulgold uses it in place of freeze)
    if (status & 0x40) ~= 0 then return "paralyze" end
    return nil
end

------------------------------------------------
-- Pokémon decoding
------------------------------------------------

-- Mirrors MON_DATA_IS_SHINY in pokemon.c: (shinyValue < odds) ^ shinyModifier
local function isShiny(personality, otId, shinyModifier)
    local shinyValue = (otId >> 16) ~ (otId & 0xFFFF) ~ (personality >> 16) ~ (personality & 0xFFFF)
    local byValue = (shinyValue < SHINY_ODDS) and 1 or 0
    return (byValue ~ shinyModifier) == 1
end

local function readPartyMon(address)
    local mon = {}

    mon.personality = emu:read32(address + 0)
    local otId      = emu:read32(address + OFF_OTID)
    local shinyMod  = (emu:read16(address + OFF_SHINYMOD) >> 14) & 1
    mon.shiny       = isShiny(mon.personality, otId, shinyMod)
    mon.egg         = (emu:read8(address + OFF_EGGFLAGS) & 0x04) ~= 0
    mon.species     = emu:read16(address + OFF_SPECIES) & 0x7FF
    mon.nickname    = readNickname(address)
    mon.statusRaw   = emu:read32(address + OFF_STATUS)
    mon.status      = decodeStatus(mon.statusRaw)
    mon.level       = emu:read8(address + OFF_LEVEL)
    mon.hp          = emu:read16(address + OFF_HP)
    mon.maxHP       = emu:read16(address + OFF_MAXHP)

    return mon
end

------------------------------------------------
-- Helpers
------------------------------------------------

local function shallowCopyMon(mon, slot)
    return {
        slot        = slot,
        personality = mon.personality,
        species     = mon.species,
        shiny       = mon.shiny,
        egg         = mon.egg,
        nickname    = mon.nickname,
        statusRaw   = mon.statusRaw,
        status      = mon.status,
        level       = mon.level,
        hp          = mon.hp,
        maxHP       = mon.maxHP
    }
end

local function copyParty(party)
    local out = {}
    for i = 1, #party do
        out[i] = shallowCopyMon(party[i], party[i].slot)
    end
    return out
end

local function snapshotParty()
    local list = {}
    local addr = PARTY_LOC

    for i = 1, PARTY_SIZE do
        local mon = readPartyMon(addr)
        if mon.species == 0 then
            break
        end
        list[i] = shallowCopyMon(mon, i)
        addr = addr + PARTY_MON_SIZE
    end

    return list
end

local function partiesEqualFull(a, b)
    if not a or not b then return false end
    if #a ~= #b then return false end

    for i = 1, #a do
        if a[i].personality ~= b[i].personality then return false end
        if a[i].species ~= b[i].species then return false end
        if a[i].shiny ~= b[i].shiny then return false end
        if a[i].egg ~= b[i].egg then return false end
        if a[i].nickname ~= b[i].nickname then return false end
        if a[i].statusRaw ~= b[i].statusRaw then return false end
        if a[i].level ~= b[i].level then return false end
        if a[i].hp ~= b[i].hp then return false end
        if a[i].maxHP ~= b[i].maxHP then return false end
    end

    return true
end

local function partiesEqualBattleVisible(a, b)
    if not a or not b then return false end
    if #a ~= #b then return false end

    for i = 1, #a do
        if a[i].hp ~= b[i].hp then return false end
        if a[i].maxHP ~= b[i].maxHP then return false end
        if a[i].statusRaw ~= b[i].statusRaw then return false end
    end

    return true
end

local function mergeBattleVisibleIntoLocked(currentParty, lockedParty)
    local byPersonality = {}

    for i = 1, #currentParty do
        byPersonality[currentParty[i].personality] = currentParty[i]
    end

    local merged = copyParty(lockedParty)

    for i = 1, #merged do
        local live = byPersonality[merged[i].personality]
        if live then
            merged[i].hp = live.hp
            merged[i].maxHP = live.maxHP
            merged[i].statusRaw = live.statusRaw
            merged[i].status = live.status
        end
        merged[i].slot = i
    end

    return merged
end

------------------------------------------------
-- Emit filter
------------------------------------------------

-- species is emitted as the raw internal id; the overlay maps it to a sprite (overlays/species.json)
local function filterParty(party)
    local out = {}
    for i = 1, #party do
        local mon = {}
        for k, v in pairs(party[i]) do mon[k] = v end
        out[#out + 1] = mon
    end
    return out
end

------------------------------------------------
-- Detection
------------------------------------------------

local function detectParty()
    local currentParty = snapshotParty()
    local battle = isInBattle()

    if not state.party then
        state.party = copyParty(currentParty)
        state.lockedParty = copyParty(currentParty)

        emit("party_init", {
            party = filterParty(state.party),
            inBattle = battle
        })
        return
    end

    if not battle then
        state.lockedParty = copyParty(currentParty)

        if not partiesEqualFull(currentParty, state.party) then
            state.party = copyParty(currentParty)
            emit("party_changed", {
                party = filterParty(state.party),
                inBattle = false
            })
        end
        return
    end

    if not state.lockedParty then
        state.lockedParty = copyParty(state.party)
    end

    local merged = mergeBattleVisibleIntoLocked(currentParty, state.lockedParty)

    if not partiesEqualBattleVisible(merged, state.party) then
        state.party = merged
        emit("party_changed", {
            party = filterParty(state.party),
            inBattle = true
        })
    end
end

------------------------------------------------
-- Frame callback
------------------------------------------------

local function tick()
    if not connected then
        connect()
        return
    end
    detectParty()
end

callbacks:add("frame", tick)

console:log("soulgold party event stream loaded")
