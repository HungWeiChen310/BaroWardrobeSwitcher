using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;

// Exercises the real adapter and native cache code without creating a graphics
// device, world, physics body, or item. GPU drawing remains an in-game gate.
internal static class RendererChecks
{
    private const BindingFlags Members = BindingFlags.Public | BindingFlags.NonPublic |
                                         BindingFlags.Instance | BindingFlags.Static;

    public static void Run(Assembly mod)
    {
        Type sessionType = mod.GetType("BaroWardrobeSwitcher.RenderSession", true)!;
        Type visual = mod.GetType("BaroWardrobeSwitcher.VisualOverride", true)!;
        Type transactionType = visual.GetNestedType("LimbRenderTransaction", Members)!;
        Type characterType = sessionType.GetConstructors()[0].GetParameters()[0].ParameterType;
        Assembly game = characterType.Assembly;
        Type limbType = game.GetType("Barotrauma.Limb", true)!;
        Type spriteType = game.GetType("Barotrauma.WearableSprite", true)!;
        Type wearableType = game.GetType("Barotrauma.WearableType", true)!;
        object character = Bare(characterType);
        object limb = Bare(limbType);
        object equipment = Bare(spriteType);
        Set(limb, "character", character);
        Set(limb, "type", Enum.Parse(game.GetType("Barotrauma.LimbType", true)!, "Head"));
        Set(equipment, "Type", Enum.Parse(wearableType, "Item"));
        Set(equipment, "HideLimb", true);
        Set(equipment, "CanBeHiddenByOtherWearables", true);
        IList hides = (IList)Get(equipment, "HideWearablesOfType")!;
        object hair = Enum.Parse(wearableType, "Hair");
        hides.Add(hair);
        IList wearing = (IList)Get(limb, "WearingItems")!;
        wearing.Add(equipment);
        Call(limb, "UpdateWearableTypesToHide");
        object cache = Get(limb, "wearableTypesToHide")!;
        Check((bool)Call(cache, "Contains", hair)!, "native mask cache was not seeded");

        object session = Activator.CreateInstance(sessionType, character)!;
        object owner = Activator.CreateInstance(transactionType, limb)!;
        Check((bool)Call(session, "TryEnterDraw", limb, owner)!, "outer draw was not admitted");
        Call(owner, "Begin", session);
        Check(!(bool)Get(equipment, "HideLimb")! &&
              !(bool)Get(equipment, "CanBeHiddenByOtherWearables")! &&
              !(bool)Call(cache, "Contains", hair)!, "draw did not clear live masks/native cache");

        object nested = Activator.CreateInstance(transactionType, limb)!;
        Check(!(bool)Call(session, "TryEnterDraw", limb, nested)!, "same-limb reentry acquired ownership");
        CallStatic(visual, "EndLimbDraw", limb, nested, null);
        Check(!(bool)Call(session, "TryEnterDraw", limb, nested)!, "nested cleanup released the outer draw");
        var original = new InvalidOperationException("synthetic other-mod draw exception");
        Check(ReferenceEquals(CallStatic(visual, "EndLimbDraw", limb, owner, original), original),
            "finalizer swallowed or replaced the original draw exception");
        Check((bool)Get(equipment, "HideLimb")! &&
              (bool)Get(equipment, "CanBeHiddenByOtherWearables")! &&
              ReferenceEquals(Get(equipment, "HideWearablesOfType"), hides) &&
              (bool)Call(cache, "Contains", hair)! && wearing.Count == 1 && ReferenceEquals(wearing[0], equipment),
            "draw cleanup failed to restore live equipment and native cache");
        Check((bool)Call(session, "TryEnterDraw", limb, owner)!, "completed draw retained ownership");
        Call(session, "ExitDraw", limb);

        object staged = Call(session, "BeginPendingCapture")!;
        Call(session, "AbortPendingCapture");
        Check(!(bool)Get(session, "HasPendingCapture")! && (bool)Get(staged, "disposed")!,
            "aborted capture retained its child resources");
        Call(session, "Dispose");
        Call(session, "Dispose");
        Check(((IDictionary)Get(session, "FashionSpritesByLimb")!).Count == 0,
            "disposed session retained limb descriptors");

        Type policy = mod.GetType("BaroWardrobeSwitcher.FashionEffectPolicy", true)!;
        object effect = Bare(game.GetType("Barotrauma.StatusEffect", true)!);
        Check(!(bool)CallStatic(policy, "IsStateDependentStatusEffect", effect)!,
            "unconditional effect was classified as an alarm");
        Set(effect, "OnlyOutside", true);
        Check((bool)CallStatic(policy, "IsStateDependentStatusEffect", effect)!,
            "conditional gameplay effect was eligible for cosmetic replay");
        Set(effect, "OnlyOutside", false);
        Set(effect, "playSoundOnRequiredItemFailure", true);
        Check((bool)CallStatic(policy, "IsStateDependentStatusEffect", effect)!,
            "required-item failure alarm was eligible for cosmetic replay");
    }

    private static object Bare(Type type)
    {
        object value = RuntimeHelpers.GetUninitializedObject(type);
        for (Type? current = type; current != null; current = current.BaseType)
        {
            foreach (FieldInfo field in current.GetFields(Members | BindingFlags.DeclaredOnly))
            {
                if (field.IsStatic || !field.FieldType.IsGenericType) { continue; }
                Type generic = field.FieldType.GetGenericTypeDefinition();
                if (generic == typeof(List<>) || generic == typeof(HashSet<>) || generic == typeof(Dictionary<,>))
                {
                    field.SetValue(value, Activator.CreateInstance(field.FieldType));
                }
            }
        }
        return value;
    }

    private static object? Get(object value, string name) =>
        value.GetType().GetField(name, Members)?.GetValue(value) ??
        value.GetType().GetProperty(name, Members)?.GetValue(value);

    private static void Set(object value, string name, object? fieldValue)
    {
        FieldInfo? field = value.GetType().GetField(name, Members);
        if (field != null) { field.SetValue(value, fieldValue); }
        else { value.GetType().GetProperty(name, Members)!.SetValue(value, fieldValue); }
    }

    private static object? Call(object value, string name, params object?[] args) =>
        value.GetType().GetMethod(name, Members)!.Invoke(value, args);

    private static object? CallStatic(Type type, string name, params object?[] args) =>
        type.GetMethod(name, Members)!.Invoke(null, args);

    private static void Check(bool condition, string message)
    {
        if (!condition) { throw new InvalidOperationException(message); }
    }
}
