# Soulgold memory addresses by version

The values `sgPartyEvents.lua` needs, per Soulgold release. Found with `findAddresses.lua` (Soulgold ships no `.sym`).
To use an older/newer version, paste that row's values over `PARTY_LOC` and `IN_BATTLE_ADDR` at the top of `sgPartyEvents.lua`.

| Soulgold version | `PARTY_LOC` (gPlayerParty) | `gMain` | `IN_BATTLE_ADDR` (gMain + 0x439) | Notes |
|---|---|---|---|---|
| v1.1.2 | `0x0203901C` | `0x030055C0` | `0x030059F9` | Shipped default |

Mon struct offsets (unchanged across versions unless the game updates its pokeemerald-expansion base, currently 1.15.2):
`personality +0`, `otId +4`, `nickname +8`, `isEgg` bit 2 of u8 at `+21`, `shinyModifier` bit 14 of u16 at `+30`, `species` low 11 bits of u16 at `+32`,
`status +76`, `level +80`, `hp +82`, `maxHP +84`; 96 bytes per party slot.
