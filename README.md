# Baro Wardrobe Switcher

LuaCsForBarotrauma client-side MVP for real equipment plus stored fashion visuals.

## Design

- The currently worn equipment is the real set and keeps the real item effects.
- Fashion A is captured from the current equipped clothes as visual-only item identifiers/names and wearable sprites, then removed from active equipment.
- Wardrobe/fashion data never applies extra stats, buffs, resistances, oxygen, armor, or skill effects.
- No panel is shown by default. Press `F8` to open or close the wardrobe panel.
- The MVP stores:
  - Fashion A: visual-only data plus C# wearable sprite overrides.
- `Capture A` now verifies whether each fashion item actually left its worn slot. If an item is still equipped, the status line lists the failed slot instead of claiming success.
- `Apply Look` applies the stored A visuals to whatever equipment is currently worn. It does not equip B for you.

## Current flow

1. Wear the fashion/look set A.
2. Press `Capture A`; the worn A items are removed from active equipment.
3. Equip any real set B normally.
4. Press `Apply Look`; the character keeps B's real effects while C# replaces B's wearable sprites only during drawing.

## Notes

- Enable `LuaCsForBarotrauma` together with this mod.
- Enable CSharp scripting in the LuaCs Settings menu and accept/enable this mod's C# run prompt; the visual override patch is client-side C#.
- The C# plugin is loaded by LuaCs from `CSharp/Client/WardrobeVisualOverridePlugin.cs`.
- At the start of each round, the mod posts a bilingual in-game notice that the wardrobe control panel opens with `F8`.
- A successful C# load prints:
  - `[Baro Wardrobe Switcher] C# visual override v0.1.7 initializing.`
  - `[Baro Wardrobe Switcher] C# visual override loaded.`
- If the panel says `C# visual override unavailable`, `Capture A` can still remove fashion items, but fashion replacement cannot work yet.
- This version is intentionally conservative: it avoids a permanent extra UI column.
- The visual override is draw-only. It patches `Limb.DrawWearable` and does not mutate `Wearable.wearableSprites`, because changing those arrays can break unequip/swap logic.
- Captured fashion sprites are cloned with their body/hair masking flags disabled, so `hidelimb`, `hidewearablesoftype`, and `hideotherwearables` from fashion XML do not hide the character's base body or hair.
- Only `WearableType.Item` sprites are replaced. Character hair, beard, moustache, and face attachments are left to the original character renderer.
- Masking flags on the real equipped item sprites are temporarily cleared per limb while the override is active, then restored on clear/reload. This keeps gloves, shoes, sleeves, and similar partial gear from hiding the original body parts underneath the visual override.
- Movement and gait still come from the real equipped items and character animation. Visual-only high heels do not currently change walking posture.
- Multiplayer needs host/server validation before this should be treated as production-ready.
