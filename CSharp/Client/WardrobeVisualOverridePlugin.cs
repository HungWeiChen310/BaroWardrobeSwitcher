using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Barotrauma;
using Barotrauma.Items.Components;
using Barotrauma.LuaCs;
using HarmonyLib;

namespace BaroWardrobeSwitcher
{
    public sealed class WardrobeVisualOverridePlugin : IAssemblyPlugin
    {
        private Harmony harmonyInstance;

        public void Initialize()
        {
            LuaCsLogger.Log($"[Baro Wardrobe Switcher] C# visual override v{VisualOverride.Version} initializing.");
            harmonyInstance = new Harmony("BaroWardrobeSwitcher.VisualOverride");
        }

        public void OnLoadCompleted()
        {
            harmonyInstance?.PatchAll();
            LuaCsLogger.Log("[Baro Wardrobe Switcher] C# visual override loaded.");
        }

        public void PreInitPatching() { }

        public void Dispose()
        {
            VisualOverride.ClearAll();
            harmonyInstance?.UnpatchSelf();
            LuaCsLogger.Log("[Baro Wardrobe Switcher] C# visual override disposed.");
        }
    }

    public static class VisualOverride
    {
        public const string Version = "0.1.7";

        private static readonly Dictionary<Character, Dictionary<Tuple<WearableType, LimbType>, WearableSprite>> FashionSpritesByCharacter =
            new Dictionary<Character, Dictionary<Tuple<WearableType, LimbType>, WearableSprite>>();
        private static readonly HashSet<Character> ActiveCharacters = new HashSet<Character>();
        private static readonly Dictionary<WearableSprite, SpriteMaskState> OriginalSpriteMasks =
            new Dictionary<WearableSprite, SpriteMaskState>();
        private static readonly MethodInfo OnWearablesChangedMethod = AccessTools.Method(typeof(Character), "OnWearablesChanged");
        private static readonly MethodInfo MemberwiseCloneMethod = AccessTools.Method(typeof(object), "MemberwiseClone");
        private static int drawOverrideLogCount;

        public static bool IsReady()
        {
            return true;
        }

        public static void ClearAll()
        {
            RestoreAllSpriteMasks();
            FashionSpritesByCharacter.Clear();
            ActiveCharacters.Clear();
        }

        public static void RestoreItemVisuals()
        {
            RestoreAllSpriteMasks();
            ActiveCharacters.Clear();
        }

        public static void ClearCharacter(Character character)
        {
            if (character == null) { return; }
            RestoreAllSpriteMasks();
            FashionSpritesByCharacter.Remove(character);
            ActiveCharacters.Remove(character);
            RefreshWearables(character);
        }

        public static int CaptureFashionItem(Character character, Item item)
        {
            if (character == null || item == null) { return 0; }

            Wearable wearable = item.GetComponent<Wearable>();
            if (wearable?.wearableSprites == null || wearable.wearableSprites.Length == 0)
            {
                LuaCsLogger.Log($"[Baro Wardrobe Switcher] No wearable sprites on fashion item: {item.Name}.");
                return 0;
            }

            if (!FashionSpritesByCharacter.TryGetValue(character, out Dictionary<Tuple<WearableType, LimbType>, WearableSprite> spritesBySlot))
            {
                spritesBySlot = new Dictionary<Tuple<WearableType, LimbType>, WearableSprite>();
                FashionSpritesByCharacter[character] = spritesBySlot;
            }

            int count = 0;
            foreach (WearableSprite sprite in wearable.wearableSprites.Where(sprite => sprite != null))
            {
                if (!IsEquipmentSprite(sprite))
                {
                    continue;
                }
                spritesBySlot[Tuple.Create(sprite.Type, sprite.Limb)] = CreateNonMaskingSprite(sprite);
                count++;
            }
            drawOverrideLogCount = 0;
            ActiveCharacters.Remove(character);
            LuaCsLogger.Log($"[Baro Wardrobe Switcher] Captured {count} non-masking wearable sprites from fashion item: {item.Name}.");
            return count;
        }

        public static bool ApplyFashionItemVisual(Character character, Item item, bool carrier)
        {
            if (character == null || item == null) { return false; }
            if (!FashionSpritesByCharacter.TryGetValue(character, out Dictionary<Tuple<WearableType, LimbType>, WearableSprite> spritesBySlot) ||
                spritesBySlot.Count == 0)
            {
                return false;
            }

            Wearable wearable = item.GetComponent<Wearable>();
            if (wearable?.wearableSprites == null || wearable.wearableSprites.Length == 0)
            {
                return false;
            }

            int sanitized = SanitizeEquippedItemMasks(wearable);
            ActiveCharacters.Add(character);
            if (carrier)
            {
                LuaCsLogger.Log($"[Baro Wardrobe Switcher] Enabled draw-only fashion override through carrier: {item.Name}, capturedSprites={spritesBySlot.Count}, sanitizedSprites={sanitized}.");
            }
            drawOverrideLogCount = 0;
            RefreshWearables(character);
            return true;
        }

        internal static bool TryOverrideDrawWearable(Limb limb, WearableSprite original, out WearableSprite replacement, out bool skipOriginal)
        {
            replacement = null;
            skipOriginal = false;
            if (limb == null || original == null) { return false; }
            if (limb.character == null || !ActiveCharacters.Contains(limb.character)) { return false; }
            if (!IsEquipmentSprite(original)) { return false; }
            if (!TryGetFashionSprite(limb.character, original.Type, limb.type, out WearableSprite fashionSprite))
            {
                skipOriginal = true;
                if (drawOverrideLogCount < 12)
                {
                    drawOverrideLogCount++;
                    LuaCsLogger.Log($"[Baro Wardrobe Switcher] DrawWearable hidden original: limb={limb.type}, type={original.Type}.");
                }
                return true;
            }
            replacement = fashionSprite;
            if (drawOverrideLogCount < 12)
            {
                drawOverrideLogCount++;
                LuaCsLogger.Log($"[Baro Wardrobe Switcher] DrawWearable override hit: limb={limb.type}, type={original.Type}.");
            }
            return true;
        }

        private static bool IsEquipmentSprite(WearableSprite sprite)
        {
            return sprite != null && sprite.Type == WearableType.Item;
        }

        private static WearableSprite CreateNonMaskingSprite(WearableSprite original)
        {
            WearableSprite clone = original;
            try
            {
                clone = MemberwiseCloneMethod?.Invoke(original, null) as WearableSprite ?? original;
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[Baro Wardrobe Switcher] Failed to clone fashion sprite, using original: {ex.GetType().Name}: {ex.Message}");
            }

            ClearMask(clone);
            return clone;
        }

        private static int SanitizeEquippedItemMasks(Wearable wearable)
        {
            int count = 0;
            foreach (WearableSprite sprite in wearable.wearableSprites.Where(sprite => IsEquipmentSprite(sprite)))
            {
                SaveOriginalMask(sprite);
                ClearMask(sprite);
                count++;
            }
            return count;
        }

        private static void SaveOriginalMask(WearableSprite sprite)
        {
            if (sprite == null || OriginalSpriteMasks.ContainsKey(sprite)) { return; }
            OriginalSpriteMasks[sprite] = new SpriteMaskState(sprite);
        }

        private static void ClearMask(WearableSprite sprite)
        {
            if (sprite == null) { return; }
            sprite.HideLimb = false;
            sprite.HideWearablesOfType = new List<WearableType>();
            sprite.ObscureOtherWearables = WearableSprite.ObscuringMode.None;
            sprite.CanBeHiddenByOtherWearables = false;
        }

        private static void RestoreAllSpriteMasks()
        {
            foreach (KeyValuePair<WearableSprite, SpriteMaskState> pair in OriginalSpriteMasks.ToList())
            {
                pair.Value.Restore(pair.Key);
            }
            OriginalSpriteMasks.Clear();
        }

        private static void RefreshWearables(Character character)
        {
            if (character == null) { return; }
            try
            {
                OnWearablesChangedMethod?.Invoke(character, null);
            }
            catch (Exception ex)
            {
                LuaCsLogger.Log($"[Baro Wardrobe Switcher] Failed to refresh wearables: {ex.GetType().Name}: {ex.Message}");
            }
        }

        internal static bool TryGetFashionSprite(Character character, WearableType type, LimbType limbType, out WearableSprite sprite)
        {
            sprite = null;
            if (character == null) { return false; }
            return FashionSpritesByCharacter.TryGetValue(character, out Dictionary<Tuple<WearableType, LimbType>, WearableSprite> spritesBySlot) &&
                   spritesBySlot.TryGetValue(Tuple.Create(type, limbType), out sprite) &&
                   sprite != null;
        }

        private sealed class SpriteMaskState
        {
            private readonly bool hideLimb;
            private readonly List<WearableType> hideWearablesOfType;
            private readonly WearableSprite.ObscuringMode obscureOtherWearables;
            private readonly bool canBeHiddenByOtherWearables;

            public SpriteMaskState(WearableSprite sprite)
            {
                hideLimb = sprite.HideLimb;
                hideWearablesOfType = sprite.HideWearablesOfType == null
                    ? null
                    : new List<WearableType>(sprite.HideWearablesOfType);
                obscureOtherWearables = sprite.ObscureOtherWearables;
                canBeHiddenByOtherWearables = sprite.CanBeHiddenByOtherWearables;
            }

            public void Restore(WearableSprite sprite)
            {
                if (sprite == null) { return; }
                sprite.HideLimb = hideLimb;
                sprite.HideWearablesOfType = hideWearablesOfType == null
                    ? null
                    : new List<WearableType>(hideWearablesOfType);
                sprite.ObscureOtherWearables = obscureOtherWearables;
                sprite.CanBeHiddenByOtherWearables = canBeHiddenByOtherWearables;
            }
        }
    }

    [HarmonyPatch]
    internal static class LimbDrawWearablePatch
    {
        private static MethodBase TargetMethod()
        {
            return AccessTools.Method(typeof(Limb), "DrawWearable");
        }

        private static bool Prefix(Limb __instance, ref WearableSprite wearable)
        {
            if (!VisualOverride.TryOverrideDrawWearable(__instance, wearable, out WearableSprite replacement, out bool skipOriginal))
            {
                return true;
            }
            if (skipOriginal)
            {
                return false;
            }
            wearable = replacement;
            return true;
        }
    }
}
