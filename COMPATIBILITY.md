# Compatibility contract

## 0.5.19 release candidate

| Input | Pinned value |
| --- | --- |
| Barotrauma target and declared version | `1.13.4.0` |
| Official game source | [`a589d2cee3ff2214c99a7ea30c46f16a5406a01d`](https://github.com/FakeFishGames/Barotrauma/tree/a589d2cee3ff2214c99a7ea30c46f16a5406a01d) |
| LuaCs publicized assemblies | [`85ded59c4efed4d139159c4cb056cc9705a5096e`](https://github.com/evilfactory/LuaCsForBarotrauma/tree/85ded59c4efed4d139159c4cb056cc9705a5096e) |
| Client C# runtime | .NET 8 |
| Protocol / wire look / normal persistence | 5 / 4 / 5 |

The probe reads the expected game version and LuaCs commit from `version.json`. The previous LuaCs pin differs only in macOS platform constant names; see the [upstream comparison](https://github.com/evilfactory/LuaCsForBarotrauma/compare/0d380afcd1feeb842c0c86290d46bcaf198cd5e4...85ded59c4efed4d139159c4cb056cc9705a5096e). Passing signatures does not establish in-game compatibility. The release remains a candidate until [TESTING.md](TESTING.md) is completed.

LuaCs is an upstream dependency, not an official Barotrauma API. Private renderer seams are checked against pinned official source and installed publicized assemblies.

## Source evidence and implementation

| Contract | Application in Wardrobe |
| --- | --- |
| [Official Identifier](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Libraries/BarotraumaLibs/BarotraumaCore/Utils/Identifier.cs) compares without case sensitivity and retains punctuation | Capture dedupe keeps the complete identifier plus color; `hat-a`, `hat_a`, and Unicode names remain distinct. |
| [LuaCs DefaultHook](https://github.com/evilfactory/LuaCsForBarotrauma/blob/85ded59c4efed4d139159c4cb056cc9705a5096e/Barotrauma/BarotraumaShared/LocalMods/LuaCsForBarotrauma/Lua/DefaultHook.lua) invokes equip/unequip before the native operation | Callbacks only mark a character dirty. One subsequent update reads final equipment. The pinned hooks do not establish a reliable character-removal callback; an owned-character sweep fills that gap. |
| [Official Character.InPressure](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaShared/SharedSource/Characters/Character.cs#L973-L979) tests the environment | Clients choose the active diving session locally; there are no pressure packets or injury thresholds. |
| [Official WearableSprite lifecycle](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaShared/SharedSource/Items/Components/Wearable.cs) and [Limb rendering](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaClient/ClientSource/Characters/Limb.cs) | Initialize owned sprites for the character, preserve native tint and physical-limb guards, restore masks, collections, and derived hide caches in finalizers. |
| [Official GUIDropDown](https://github.com/FakeFishGames/Barotrauma/blob/a589d2cee3ff2214c99a7ea30c46f16a5406a01d/Barotrauma/BarotraumaClient/ClientSource/GUI/GUIDropDown.cs) | Use the native dropdown and the callback's target argument; callbacks precede the final selected-data update. |
| [Official performance guide](https://regalis11.github.io/BaroModDoc/Misc/Performance.html) | Reduce repeated high-frequency work: pooled drawing transactions, cached limb candidates, initialized typed delegates, coalesced equipment refresh, cached appearances, and event-driven network state. No FPS percentage is inferred. |

## C# capability checks

Required draw contracts include exact `Limb.Draw(SpriteBatch, Camera, Color?, bool)` and `Limb.DrawWearable(WearableSprite, float, SpriteBatch, Color, float, SpriteEffects)` overloads, `Limb.UpdateWearableTypesToHide()`, initialized `WearableSprite` resources, native `Item.SpriteColor` / `Color.PackedValue`, and `Color(uint)`.

Identity and UI checks include `Character.Info`, `IsBot`, `IsHuman`, `IsOnPlayerTeam`, `InPressure`, `Entity.Removed`, stable `CharacterInfo` fields, `GUIComponent.RemoveFromGUIUpdateList(bool)`, dropdown selection, and list-box scroll position. Network readers require byte access and a bit/byte remaining-length contract for complete optional tails.

Optional capabilities include animation updates/loading, status sound playback and condition metadata, item-component playback/stop, and native footstep impact sounds. The probe also binds the actual open delegates used for drawing, animation, and status sound. Missing required draw hooks disable rendering; missing optional hooks disable their capability. Conditional/required-item alarms are never captured or suppressed as cosmetic sounds.

```powershell
./scripts/Test-Compatibility.ps1 `
  -BarotraumaInstallDir "C:\Program Files (x86)\Steam\steamapps\common\Barotrauma" `
  -LuaCsPublicizedDir "C:\Program Files (x86)\Steam\steamapps\common\Barotrauma\Publicized" `
  -RequireOptional
```

The standalone probe accepts `--version-file <path>`; without it, it reads `version.json` in the working directory.

## Network compatibility

| Peers | Behavior |
| --- | --- |
| 0.5.19 client and server | Protocol 5, look schema 4, normal and diving appearance synchronization. |
| 0.5.19 client and older protocol-5 server | Existing normal synchronization; diving stays local because capability `0x10` is absent. |
| Older protocol-5 client and 0.5.19 server | Existing normal appearance; no diving-state messages are sent to this client. |
| Different protocol versions or v1-only peer | Existing six-message v1 bridge; hello timeout is five seconds. Custom colors and newer preferences cannot synchronize over v1. |

Capability bits are attachment visibility `0x01`, movement source `0x02`, crew targeting `0x04`, footstep source `0x08`, and diving appearance `0x10`. Client hello optionally appends `0x57, 1, capabilities`; absent tails remain valid. Existing normal command/state layouts are unchanged.

The new `diving` and `diving-save` commands use the current operation queue, base revision, ACK, dedupe, and limits. Their mode byte precedes `hasLook` and follows the target ID on the targeted channel. Save carries no client look: the server captures actual equipment/colors without moving items. Settings validate captured state, identifiers, colors, and wearable-slot relationships, with the six-slot / 4 KiB limits.

`barowardrobeswitcher.v2.diving-state` carries protocol, server epoch, round generation, per-character revision, character ID, operation ID, mode, and optional look. Character ID zero marks a snapshot generation. Clients bound entity waits, reject older generations/revisions, and complete commands only after both state and ACK arrive. Snapshots follow hello and round changes; pressure changes generate no Wardrobe messages. Normal Clear/Forget are independent from diving settings.

## Release gates

Keep `compatibilityStatus=release-candidate` and the existing declared game version until the complete game matrix is recorded as passing. Only then promote to `verified` and run `python scripts/verify_package.py --release`. Metadata is a release record, not proof of compatibility. Source packages exclude binaries, game assemblies, runtime data, and `artifacts`.
