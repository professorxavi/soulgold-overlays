# Soulgold memory addresses by version

The values `sgPartyEvents.lua` needs, per Soulgold release. Found with `findAddresses.lua` (Soulgold ships no `.sym`).
To use an older/newer version, paste that row's values over `PARTY_LOC`, `IN_BATTLE_ADDR` and `SAVEBLOCK1_PTR` at the top of `sgPartyEvents.lua`.

| Soulgold version | `PARTY_LOC` (gPlayerParty) | `gMain` | `IN_BATTLE_ADDR` (gMain + 0x439) | `SAVEBLOCK1_PTR` (gSaveBlock1Ptr) | Notes |
|---|---|---|---|---|---|
| v1.1.4 | `0x0203901C` | `0x030055C0` | `0x030059F9` | `0x030040C4` | Shipped default |
| v1.1.3 | `0x0203901C` | `0x030055C0` | `0x030059F9` | | |
| v1.1.2 | `0x0203901C` | `0x030055C0` | `0x030059F9` | | |

Nothing has moved since v1.1.2 — if you're on any of these, the script works as shipped.

Mon struct offsets (unchanged across versions unless the game updates its pokeemerald-expansion base, currently 1.15.2):
`personality +0`, `otId +4`, `nickname +8`, `isEgg` bit 2 of u8 at `+21`, `shinyModifier` bit 14 of u16 at `+30`, `species` low 11 bits of u16 at `+32`,
`status +76`, `level +80`, `hp +82`, `maxHP +84`; 96 bytes per party slot.

Badges are flags `0x993`–`0x99A` in `SaveBlock1.flags` (`+0x1898`, measured in game; neither the `/*0x1270*/` comment in `global.h` nor adding up struct sizes gives this). SaveBlock1 moves on save/load, so the script
follows `gSaveBlock1Ptr` rather than a fixed address.
