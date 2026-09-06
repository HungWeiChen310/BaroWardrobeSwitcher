# Baro Wardrobe Switcher

Version **0.5.13** is a release candidate targeting Barotrauma **1.13.4.0** and LuaCs. It separates real equipped gear from saved cosmetic appearances. Automated checks and remaining in-game gates are recorded in [QUALITY_REPORT.md](QUALITY_REPORT.md).

## Setup and use

Enable LuaCs, enable C# scripting, and accept this mod's C# run prompt. LuaCs compiles `CSharp/Client` from source; no DLL is distributed. Restart Barotrauma fully after replacing source files so the loaded Lua and C# versions agree.

Press **F8** to open the scrollable wardrobe panel. Change the key in Settings → Mod Gameplay Settings → Wardrobe → Wardrobe Panel Key; invalid names fall back to F8. The shortcut is ignored while a text field owns keyboard input or an input-blocking menu is open.

1. Select yourself or an eligible crew member.
2. Wear the desired outfit and choose **Save Current Outfit**. The selected character's captured gear is removed from managed worn slots. Inspect the slot results if removal is incomplete.
3. Equip your real combat/utility gear and choose **Apply Saved Look**. Its gameplay effects remain real; the saved appearance is cosmetic.
4. **Clear Look** deactivates the normal appearance without deleting its save. **Forget Saved Look** deletes that save. Neither action deletes the independent diving profile.

Empty looks are valid. Save leaves a look inactive; Apply activates it. Scene restoration follows explicit activation intent. Appearance Layers controls Hair, Beard, Moustache and Face Attachment independently using Auto, Hide and Show. Show has priority over Hide and the appearance XML mask; this also supports character mods that reuse these layers for head parts.

The second page controls movement-animation source, footstep-sound source and diagnostics. Footsteps follow real equipment by default. Only the cosmetic portions of supported effects are replayed; oxygen, protection, inventory and other real equipment effects remain owned by Barotrauma. Conditional/required-item alarms are not captured as fashion effects. Sealed-suit compatibility rules remain in place.

## Crew and multiplayer

Single-player human crew have independent campaign-scoped profiles. Transfer to unconfigured characters defaults to off; enabling it never overwrites a configured crew member. Active NPC profiles restore after the next scene's initial equipment settles. Ambiguous character fingerprints disable automatic disk restoration. Scenes without a campaign save path use memory-only profiles.

Multiplayer retains one saved look per client account. A negotiated crew-target capability allows selecting living human bots on the **same team**. The server independently rejects opposing-team bots, player-controlled targets, unavailable characters and targets owned by another active wardrobe session. Pending commands freeze their target entity ID; a stale UI button cannot silently apply to the player instead. Bot activation is round-local and does not migrate onto the owner's player character after reconnect or round start.

Both updated peers use protocol **5**, wire look schema **4**, revisions, operation IDs, acknowledgements and bounded retries. Older peers retain the six-message v1 bridge, with a five-second hello timeout. V1 cannot synchronize custom colors or the newer preferences. The historical `v2` message names and internal `v3` mode label are implementation names, not the negotiated protocol number.

## Diving appearance

Diving mode cycles through None, Diving suit only and Custom outfit. It follows the native **InPressure environment flag**, including when real pressure protection prevents injury; it does not wait for pressure-affliction damage. Saving a custom diving outfit captures visuals without unequipping items.

While pressure is present, diving appearance temporarily replaces the normal look. Pressure exit restores the latest normal appearance or real equipment if that look was cleared. Normal Apply never reuses the temporary diving payload. Failed activation cleans up and retries after a bounded delay. The mode changes only local rendering; it adds no multiplayer wire fields or pressure protection.

A failed disk write is shown as **session only**. File-read failures remain retryable instead of becoming permanent empty profiles. Unknown future diving-file versions are preserved. Corrupt or oversized files are quarantined with a diagnostic.

## Storage and compatibility

Only stable identifiers, optional packed colors and preferences are stored under the user's Barotrauma ModData directory. Campaign/profile keys are hashed; raw campaign paths are not written into the JSON files.

| File | Schema | Purpose |
| --- | --- | --- |
| ClientLook.json | 5 | Multiplayer client's saved look |
| ServerLooks.json | 5 | Server-authoritative stable-account looks |
| SinglePlayerProfiles.json | 3 | Campaign crew profiles and transfer preference |
| DivingProfiles.json | 1 | Independent local diving profiles |

Valid legacy formats migrate with backups; missing legacy colors use prefab base colors. Anonymous clients have session-only server state. See [ARCHITECTURE.md](ARCHITECTURE.md) and [COMPATIBILITY.md](COMPATIBILITY.md) for boundaries and exact source references.

## Build, verify and package

Use the scripts in [TESTING.md](TESTING.md) with explicit game/Publicized paths. Build products go only under ignored `artifacts`. To create and check an explicit source-only package:

```powershell
python scripts/verify_package.py
python scripts/package_mod.py artifacts/package/BaroWardrobeSwitcher-0.5.13
python scripts/verify_package.py --package-root artifacts/package/BaroWardrobeSwitcher-0.5.13
```

The package contains a SHA-256 manifest. `--release` intentionally fails while compatibility is marked release-candidate; promote it only after the required in-game matrix passes. Game assemblies, compiled output, tests and player runtime data are not deployment inputs.
