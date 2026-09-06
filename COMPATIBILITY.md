# Compatibility contract

## Current candidate

- Mod: **0.5.13**, `release-candidate`; automated checks do not certify the in-game matrix.
- Target and previously declared game version: **1.13.4.0**.
- Official game source: [`a589d2cee3ff2214c99a7ea30c46f16a5406a01d`](https://github.com/FakeFishGames/Barotrauma/tree/a589d2cee3ff2214c99a7ea30c46f16a5406a01d).
- Installed LuaCs/Publicized source: [`85ded59c4efed4d139159c4cb056cc9705a5096e`](https://github.com/evilfactory/LuaCsForBarotrauma/tree/85ded59c4efed4d139159c4cb056cc9705a5096e).
- Target framework: .NET 8; probes may roll forward to the installed .NET runtime.

The prior LuaCs pin was `0d380afcd1feeb842c0c86290d46bcaf198cd5e4`. The [two-commit difference](https://github.com/evilfactory/LuaCsForBarotrauma/compare/0d380afcd1feeb842c0c86290d46bcaf198cd5e4...85ded59c4efed4d139159c4cb056cc9705a5096e) changes only the macOS platform preprocessor branch in ModUtils. The installed Windows assembly passes the API probes. This is not evidence of macOS or Linux in-game validation.

The probe reads game and LuaCs pins from `version.json`; it does not silently accept arbitrary revisions. Candidate metadata retains `previousVerifiedGameVersion`, while `--release` requires an explicitly verified candidate.

## Official contracts and dependency boundaries

| Area | Source and required behavior |
| --- | --- |
| Package | [Official content-package guide](https://regalis11.github.io/BaroModDoc/Intro/ContentPackages.html): filelist declares every content/config/source input; gameversion is compatibility metadata. |
| Sprites | [Official Wearable.cs](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaShared/SharedSource/Items/Components/Wearable.cs): initialize each owned WearableSprite with its target Character before drawing. |
| Drawing | [Official client Limb.cs](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaClient/ClientSource/Characters/Limb.cs): exact draw overloads; restore WearingItems, masks and UpdateWearableTypesToHide caches after a transaction. |
| Team and pressure | [Official Character.cs](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaShared/SharedSource/Characters/Character.cs): IsOnPlayerTeam includes both PvP teams; compare current TeamID. Diving uses InPressure rather than injury strength. |
| Effects | [Official StatusEffect documentation](https://regalis11.github.io/BaroModDoc/Misc/StatusEffect.html): effect timing, conditions and gameplay ownership must be retained. |
| Input | [Official GUI.cs](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaClient/ClientSource/GUI/GUI.cs): honor InputBlockingMenuOpen and KeyboardDispatcher.Subscriber. |
| Performance | [Official performance guide](https://regalis11.github.io/BaroModDoc/Misc/Performance.html): avoid unnecessary per-frame work; prefer relevant events and bounded checks. |
| LuaCs | [In-memory C# loading](https://evilfactory.github.io/LuaCsForBarotrauma/cs-docs/html/md_manual_inmemorymod.html) and [networking](https://evilfactory.github.io/LuaCsForBarotrauma/lua-docs/manual/networking/): third-party APIs, separate from the official game contract. |

Required renderer seams include `Limb.Draw(SpriteBatch, Camera, Color?, bool)`, `Limb.DrawWearable(WearableSprite, float, SpriteBatch, Color, float, SpriteEffects)`, `Limb.UpdateWearableTypesToHide()`, `WearableSprite.Init(Character)` and Item.SpriteColor/Color.PackedValue. Identity requires Character.Info, CharacterInfo.ID/OriginalName/SpeciesName/HumanPrefabIds and character lifecycle access. Networking requires byte I/O and readable message position/length for bounded optional tails.

Optional animation/sound hooks include AnimController.UpdateAnimations, TryLoadTemporaryAnimation, StatusEffect.PlaySound, ItemComponent.PlaySound and Ragdoll.PlayImpactSound. Missing required draw seams disable rendering; optional capabilities degrade separately. Conditional and required-item status effects remain under native gameplay ownership, including oxygen alarms.

## Wire compatibility

Updated peers negotiate **protocol 5**, **look schema 4**. Existing `v2` message names and `v3` internal mode labels remain unchanged. Hello advertises visibility (`0x01`), movement source (`0x02`), crew targeting (`0x04`) and footstep source (`0x08`). Readers reject partial or unsupported extension tails, unknown bits, overlapping visibility masks and malformed colors.

Older peers use the existing v1 bridge after negotiation or the five-second timeout. Its payload is unchanged and cannot express newer colors/preferences. Targeted NPC operations never fall back to self-only v1 commands. There is no new wire format or bridge removal in 0.5.13.

## Verification

Run `scripts/Test-Compatibility.ps1` with explicit `-BarotraumaInstallDir`, `-LuaCsPublicizedDir` and `-RequireOptional`. Complete [TESTING.md](TESTING.md) before publishing. The actual results and unexecuted scenarios belong in [QUALITY_REPORT.md](QUALITY_REPORT.md); do not infer them from filelist.xml or from the presence of a test.
