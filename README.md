# Baro Wardrobe Switcher

LuaCs wardrobe with saved clothing colors, independent crew profiles, and multiplayer appearance synchronization.

**0.5.19 is a release candidate for Barotrauma 1.13.4.0.** It retains protocol 5, look schema 4, existing saves, and the v1 bridge. Automated checks cover the new behavior; the complete game and multiplayer matrix remains pending. See [TESTING.md](TESTING.md).

## Using the wardrobe

Enable LuaCs, C# scripting, and this mod's C# run permission. LuaCs compiles the included client source; no prebuilt game or mod assemblies are shipped.

1. Press `F8` to open the two-page panel. Change the key in `Settings -> Mod Gameplay Settings -> Wardrobe -> Wardrobe Panel Key`. Names accept mixed case and surrounding whitespace; invalid names fall back to `F8`.
2. Choose yourself or an eligible crew member from the native target dropdown. Multiplayer targets are your own character and friendly living human bots; the server rechecks ownership for every operation.
3. Wear the desired appearance and press `Save Current Outfit`. This normal wardrobe action removes those items from worn slots after validating capture. Failed removals are reported; full inventories retain the existing fallback behavior.
4. Equip functional gear, then press `Apply Saved Look`. Real equipment retains its stats, protection, oxygen, inventory, and health-interface effects.
5. `Clear Look` deactivates the normal appearance without deleting it. `Forget Saved Look` deletes it. Both disable automatic normal reapplication; neither changes diving settings.

Empty outfits are valid. Save alone leaves the normal look inactive; a successfully applied look restores after initial equipment settles in a later scene. Single-player crew profiles restore independently, including NPCs you never control. Appearance transfer to unconfigured single-player characters defaults to off.

`Appearance Layers...` controls Hair, Beard, Moustache, and Face Attachment using `Auto`, `Hide`, or `Show`. Show takes precedence over Hide and the appearance item's XML mask. This supports character mods that use those layers as parts of a composite head. Page two selects fashion/equipment movement and footsteps and contains diagnostics. Ordinary state changes update existing controls; page changes preserve each page's scroll position.

## Diving appearance

`Diving mode` selects `None`, `Diving suit only`, or `Custom outfit`. It follows the native `Character.InPressure` environment flag, not accumulated pressure injury. Leaving pressure restores the latest normal wardrobe appearance, including changes made while diving.

- Suit-only mode displays the actually equipped diving suit and its current color.
- `Save Diving Outfit` captures actual worn identifiers and colors without unequipping, moving, or dropping anything. On a supporting multiplayer server, capture is authoritative.
- `Clear Custom Diving Outfit` clears only that saved diving outfit. An unsaved custom outfit leaves the normal appearance visible; a deliberately saved empty outfit remains valid.
- Supporting protocol-5 clients see one another's diving appearances, including bots and late joiners. Only setting changes and snapshots are transmitted; pressure and ordinary equipment use Barotrauma's native synchronization.
- Older servers retain local diving effects. Older clients keep seeing the normal wardrobe appearance. The panel reports local-only display, pending server operations, unavailable assets, unsaved custom outfits, and session-only storage.
- Your own multiplayer diving settings are restored from the local file and registered with the server. Bot settings last only for the current connection and round and never transfer to replacement characters.

Each character retains at most two committed render sessions, normal and diving. Warm pressure switches reuse them. Equipment callbacks are coalesced until the next update reads the final equipment state; ordinary equipment changes do not recapture custom assets.

## Saving and diagnostics

Normal client/server saves remain `ClientLook.json` / `ServerLooks.json`, schema 5; single-player `SinglePlayerProfiles.json` remains schema 3; `DivingProfiles.json` remains schema 1. Existing migrations, backups, atomic replacement, and corrupt-file quarantine remain supported. Profile readers cache validated documents and reload changed files. Mutations read fresh documents; a transient failure is not treated as a successful empty save.

Campaign paths and character fingerprints are hashed for local keys. Ambiguous single-player fingerprints disable automatic restoration. Campaign-less scenes and anonymous server identities use session storage where a stable identity is unavailable. Legacy client looks import once per campaign into the first controlled non-bot character, without overwriting existing crew profiles or automatically activating the imported look.

Detailed logging defaults to off. Enable `Detailed Logging` in Mod Gameplay Settings when needed. Errors and manual diagnostic dumps remain available in `WardrobeClient.log`; the current log is capped at 64 KiB with one previous file. The server keeps its existing 64 KiB cap and caches log contents in memory. Server detail logging can be enabled with `WardrobeDetailedLogging = true` in its Lua environment.

Open diagnostics and press `Resynchronize` to request current server state and retry local assets. Controls recover after bounded ACK retries. At 512 operations an idle transport starts a fresh session; uncertain Save/Forget results are never automatically replayed with new operation IDs.

The renderer preserves native tint, transparency, limb routing, masking restoration, and resource ownership. Conditional equipment alarms, including low/empty oxygen, remain under the game's native lifecycle. Workshop-specific regressions and Harmony conflicts remain part of the [game matrix](TESTING.md).

## Build and verification

```powershell
./scripts/Build.ps1 `
  -BarotraumaInstallDir "C:\Program Files (x86)\Steam\steamapps\common\Barotrauma" `
  -LuaCsPublicizedDir "C:\Program Files (x86)\Steam\steamapps\common\Barotrauma\Publicized"
```

Run the compatibility, renderer, persistence, Lua, and package checks described in [TESTING.md](TESTING.md). Outputs stay under ignored `artifacts`. The `--release` package check intentionally fails until the game matrix is completed and compatibility metadata is promoted. Workshop publication remains a separate manual step.

[Architecture](ARCHITECTURE.md) · [Pinned official and LuaCs contracts](COMPATIBILITY.md)
