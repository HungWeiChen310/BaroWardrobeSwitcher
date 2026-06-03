local MOD_NAME = "Baro Wardrobe Switcher"

if SERVER then return end

local Vector2 = LuaUserData.CreateStatic("Microsoft.Xna.Framework.Vector2", true)
local Color = LuaUserData.CreateStatic("Microsoft.Xna.Framework.Color", true)
local ChatBox = nil
pcall(function()
    ChatBox = LuaUserData.CreateStatic("Barotrauma.ChatBox", true)
end)
local GameMain = nil
pcall(function()
    GameMain = LuaUserData.CreateStatic("Barotrauma.GameMain", true)
end)
local PlayerConnectionChangeType = nil
pcall(function()
    PlayerConnectionChangeType = LuaUserData.CreateEnumTable("Barotrauma.Networking.PlayerConnectionChangeType")
end)
local CharacterInventory = nil
pcall(function()
    CharacterInventory = LuaUserData.CreateStatic("Barotrauma.CharacterInventory", true)
end)
local VisualOverride = nil
local visualOverrideFailure = nil
local visualOverrideDiagnostics = nil

local slots = {
    { key = "Head", label = "Head", slot = InvSlotType.Head },
    { key = "Headset", label = "Headset", slot = InvSlotType.Headset },
    { key = "InnerClothes", label = "Inner", slot = InvSlotType.InnerClothes },
    { key = "OuterClothes", label = "Outer", slot = InvSlotType.OuterClothes },
    { key = "Bag", label = "Bag", slot = InvSlotType.Bag },
    { key = "HealthInterface", label = "Health", slot = InvSlotType.HealthInterface }
}

local visualCarrierPriority = {
    InnerClothes = 1,
    OuterClothes = 2,
    Head = 3,
    Bag = 4,
    Headset = 5,
    HealthInterface = 6
}

local presets = {
    fashion = {}
}

local statusText = "Ready. Capture fashion A, equip combat B, then apply look."
local window = nil
local overlayRoot = nil
local lastCharacter = nil
local buildWindow
local toggleWindow
local fullPanelOpen = false
local unequipItem
local isInSlot
local roundStartNoticeSent = false

local function log(message)
    local line = "[" .. MOD_NAME .. "] " .. tostring(message)
    statusText = tostring(message)
    if LuaCsLogger ~= nil and LuaCsLogger.Log ~= nil then
        LuaCsLogger.Log(line)
    else
        print(line)
    end
end

local function addChatLine(text)
    local chatType = ChatMessageType.ServerMessageBoxInGame or ChatMessageType.MessageBox
    local changeType = PlayerConnectionChangeType ~= nil and PlayerConnectionChangeType.None or nil
    if GameMain ~= nil and GameMain.Client ~= nil then
        local ok = pcall(function()
            GameMain.Client.AddChatMessage(tostring(text), chatType, MOD_NAME, nil, nil, changeType, Color.Cyan)
        end)
        if ok then return true end
    end

    local ok, sent = pcall(function()
        if ChatBox == nil then return false end
        local chatBox = ChatBox.GetChatBox()
        if chatBox == nil then return false end
        local message = ChatMessage.Create(MOD_NAME, tostring(text), chatType, nil, nil, changeType, Color.Cyan)
        chatBox.AddMessage(message)
        return true
    end)
    if ok and sent == true then return true end

    log(text)
    return false
end

local function sendRoundStartNotice()
    if roundStartNoticeSent then return end
    roundStartNoticeSent = true
    addChatLine("時裝控制面板可以在按下 F8 後開啟。")
    addChatLine("Wardrobe control panel can be opened by pressing F8.")
end

local function ensureVisualOverride()
    if VisualOverride ~= nil then return VisualOverride end

    visualOverrideFailure = nil
    local diagnostics = {}

    local function diag(message)
        diagnostics[#diagnostics + 1] = tostring(message)
    end

    if PluginPackageManager ~= nil and PluginPackageManager.LuaTryRegisterPackageTypes ~= nil then
        pcall(function()
            diag("AssembliesLoaded=" .. tostring(PluginPackageManager.AssembliesLoaded))
            diag("PluginsLoaded=" .. tostring(PluginPackageManager.PluginsLoaded))
        end)
        local okRegisterDisplay, registerDisplay = pcall(function()
            return PluginPackageManager.LuaTryRegisterPackageTypes("Baro Wardrobe Switcher", false)
        end)
        diag("RegisterDisplay=" .. tostring(okRegisterDisplay and registerDisplay))
        local okRegisterAssembly, registerAssembly = pcall(function()
            return PluginPackageManager.LuaTryRegisterPackageTypes("BaroWardrobeSwitcher", false)
        end)
        diag("RegisterAssembly=" .. tostring(okRegisterAssembly and registerAssembly))
    else
        diag("PluginPackageManager unavailable")
    end

    local okRegisterType, registerTypeError = pcall(function()
        LuaUserData.RegisterType("BaroWardrobeSwitcher.VisualOverride")
    end)
    diag("RegisterType=" .. tostring(okRegisterType))
    if not okRegisterType then
        diag("RegisterTypeError=" .. tostring(registerTypeError))
    end

    local ok, result = pcall(function()
        VisualOverride = LuaUserData.CreateStatic("BaroWardrobeSwitcher.VisualOverride", true)
    end)
    if not ok then
        VisualOverride = nil
        visualOverrideFailure = tostring(result)
    end

    visualOverrideDiagnostics = table.concat(diagnostics, " ")
    return VisualOverride
end

local function visualOverrideStatus()
    local override = ensureVisualOverride()
    if override == nil then
        local message = "C# visual override unavailable; check LuaCs C# compile/load log and reload."
        if CSActive ~= nil then
            message = message .. " CSActive=" .. tostring(CSActive) .. "."
        end
        if visualOverrideFailure ~= nil then
            message = message .. " Lua error: " .. visualOverrideFailure
        end
        if visualOverrideDiagnostics ~= nil then
            message = message .. " Diagnostics: " .. visualOverrideDiagnostics
        end
        return message
    end

    local ok, ready = pcall(function()
        return override.IsReady()
    end)
    if not ok or ready ~= true then
        return "C# visual override loaded unexpectedly but did not report ready."
    end
    return nil
end

local function controlled()
    return Character.Controlled
end

local function ensureOverlayRoot()
    if overlayRoot ~= nil then return overlayRoot end

    local ok, root = pcall(function()
        return GUI.Frame(GUI.RectTransform(Vector2(1.0, 1.0)), nil)
    end)
    if not ok then
        log("Overlay root failed to build: " .. tostring(root))
        return nil
    end

    overlayRoot = root
    pcall(function() overlayRoot.CanBeFocused = false end)
    return overlayRoot
end

local function overlayParent()
    local root = ensureOverlayRoot()
    if root == nil then return nil end
    return root.RectTransform
end

local function drawOverlay()
    if overlayRoot == nil then return end
    pcall(function() overlayRoot.AddToGUIUpdateList() end)
end

local function resetOverlay()
    if overlayRoot ~= nil then
        pcall(function() overlayRoot.Remove() end)
    end
    overlayRoot = nil
    window = nil
end

local function itemName(item)
    if item == nil then return "-" end
    if type(item) == "table" then
        if item.name ~= nil then return tostring(item.name) end
        if item.identifier ~= nil then return tostring(item.identifier) end
    end
    local prefab = item.Prefab
    if prefab == nil then return tostring(item) end
    if prefab.Name ~= nil then return tostring(prefab.Name) end
    if prefab.Identifier ~= nil then return tostring(prefab.Identifier) end
    return tostring(item)
end

local function itemIdentifier(item)
    if item == nil or item.Prefab == nil or item.Prefab.Identifier == nil then return nil end
    return tostring(item.Prefab.Identifier)
end

local function getSlotItem(character, slot)
    if character == nil or character.Inventory == nil then return nil end
    local ok, result = pcall(function()
        return character.Inventory.GetItemInLimbSlot(slot)
    end)
    if ok then return result end

    local slotIndex = nil
    pcall(function()
        slotIndex = character.Inventory.FindLimbSlot(slot)
    end)
    if slotIndex == nil or slotIndex < 0 then return nil end

    ok, result = pcall(function()
        return character.Inventory.GetItemAtSlot(slotIndex)
    end)
    if ok then return result end

    ok, result = pcall(function()
        return character.Inventory.GetItemAt(slotIndex)
    end)
    if ok then return result end

    return nil
end

unequipItem = function(character, item)
    if character == nil or item == nil then return true end

    local function moveToAnySlot()
        if character.Inventory == nil or CharacterInventory == nil then return false end
        local ok, result = pcall(function()
            return character.Inventory.TryPutItem(item, character, CharacterInventory.AnySlot, true, true)
        end)
        return ok and result
    end

    if moveToAnySlot() then return true end

    pcall(function()
        item.Unequip(character)
    end)
    if moveToAnySlot() then return true end

    local ok, result = pcall(function()
        return item.Drop(character)
    end)
    if ok then return result ~= false end

    return false
end

isInSlot = function(character, item, slot)
    if character == nil or character.Inventory == nil or item == nil then return false end
    local ok, result = pcall(function()
        return character.Inventory.IsInLimbSlot(item, slot)
    end)
    if ok then return result == true end
    return getSlotItem(character, slot) == item
end

local function snapshot(character)
    local data = {}
    for _, entry in ipairs(slots) do
        data[entry.key] = getSlotItem(character, entry.slot)
    end
    return data
end

local function clearVisualOverride(character)
    if ensureVisualOverride() == nil then return end
    pcall(function()
        VisualOverride.ClearCharacter(character)
    end)
end

local function clearAllVisualOverrides()
    if ensureVisualOverride() == nil then return end
    pcall(function()
        VisualOverride.ClearAll()
    end)
end

local function restoreItemVisuals()
    if ensureVisualOverride() == nil then return end
    pcall(function()
        VisualOverride.RestoreItemVisuals()
    end)
end

local function captureVisualOverride(character, item)
    if ensureVisualOverride() == nil or character == nil or item == nil then return 0 end
    local ok, count = pcall(function()
        return VisualOverride.CaptureFashionItem(character, item)
    end)
    if ok and count ~= nil then return count end
    return 0
end

local function applyVisualOverrideToItem(character, item, carrier)
    if ensureVisualOverride() == nil or character == nil or item == nil then return false end
    local ok, result = pcall(function()
        return VisualOverride.ApplyFashionItemVisual(character, item, carrier == true)
    end)
    return ok and result == true
end

local function visualSnapshot(character)
    local data = {}
    for _, entry in ipairs(slots) do
        local item = getSlotItem(character, entry.slot)
        if item ~= nil then
            data[entry.key] = {
                identifier = itemIdentifier(item),
                name = itemName(item),
                slot = entry.key
            }
        else
            data[entry.key] = nil
        end
    end
    return data
end

local function saveFashionAndUnequip()
    local character = controlled()
    if character == nil then
        log("No controlled character.")
        return
    end

    presets.fashion = visualSnapshot(character)
    clearVisualOverride(character)
    local capturedSprites = 0
    local removedItems = 0
    local failedSlots = {}
    for _, entry in ipairs(slots) do
        local item = getSlotItem(character, entry.slot)
        if item ~= nil then
            capturedSprites = capturedSprites + captureVisualOverride(character, item)
            unequipItem(character, item)
            if isInSlot(character, item, entry.slot) then
                table.insert(failedSlots, entry.label .. ":" .. itemName(item))
            else
                removedItems = removedItems + 1
            end
        end
    end

    lastCharacter = character
    local visualStatus = visualOverrideStatus()
    local message = "Captured fashion A, saved " ..
        tostring(capturedSprites) ..
        " wearable sprites, and removed " ..
        tostring(removedItems) ..
        " worn A items."
    if #failedSlots > 0 then
        message = message .. " Still equipped: " .. table.concat(failedSlots, ", ") .. "."
    end
    if visualStatus ~= nil then
        message = message .. " " .. visualStatus
    end
    log(message)
end

local function applyFashionToCurrentEquipment()
    local character = controlled()
    if character == nil then
        log("No controlled character.")
        return
    end

    restoreItemVisuals()

    local current = snapshot(character)
    local equippedItems = {}
    for _, entry in ipairs(slots) do
        local equipped = current[entry.key]
        if equipped ~= nil then
            equippedItems[#equippedItems + 1] = {
                item = equipped,
                priority = visualCarrierPriority[entry.key] or 99
            }
        end
    end

    table.sort(equippedItems, function(a, b)
        return a.priority < b.priority
    end)

    local visualItems = 0
    for index, entry in ipairs(equippedItems) do
        if applyVisualOverrideToItem(character, entry.item, index == 1) then
            visualItems = visualItems + 1
        end
    end

    lastCharacter = character
    local visualStatus = visualOverrideStatus()
    local message = "Activated fashion A draw override for current equipment."
    if visualItems > 0 then
        message = message .. " Checked " .. tostring(visualItems) .. " worn items."
    end
    if visualStatus ~= nil then
        message = message .. " " .. visualStatus
    end
    log(message)
end

local function clearWindow()
    if window ~= nil then
        pcall(function() window.Remove() end)
        window = nil
    end
    fullPanelOpen = false
    resetOverlay()
end

local function addText(parent, text)
    local block = GUI.TextBlock(GUI.RectTransform(Vector2(1.0, 0.0), parent.RectTransform), text)
    block.TextColor = Color.White
    return block
end

local function addButton(parent, text, action, refresh)
    local button = GUI.Button(GUI.RectTransform(Vector2(1.0, 0.08), parent.RectTransform), text)
    button.OnClicked = function()
        action()
        if refresh ~= false then
            clearWindow()
            buildWindow()
        end
        return true
    end
    return button
end

buildWindow = function()
    if window ~= nil then
        pcall(function() window.Remove() end)
        window = nil
    end

    local parent = overlayParent()
    if parent == nil then
        log("Overlay root is not ready.")
        return
    end

    local frame = GUI.Frame(GUI.RectTransform(Vector2(0.42, 0.58), parent, GUI.Anchor.Center), "GUIFrame")
    window = frame
    fullPanelOpen = true

    local list = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.94, 0.94), frame.RectTransform, GUI.Anchor.Center), false)
    list.Stretch = true
    list.RelativeSpacing = 0.03

    addText(list, "Wardrobe Switcher")
    addText(list, "Flow: wear A -> capture A, wear B, then apply look.")
    addText(list, "Status: " .. statusText)

    addButton(list, "1 Capture A (fashion)", function() saveFashionAndUnequip() end)
    addButton(list, "2 Apply Look", function() applyFashionToCurrentEquipment() end)
    addButton(list, "Close", function() fullPanelOpen = false; resetOverlay() end, false)

    for _, entry in ipairs(slots) do
        local currentItem = "-"
        local character = controlled()
        if character ~= nil then
            currentItem = itemName(getSlotItem(character, entry.slot))
        end
        addText(
            list,
            entry.label .. " | worn: " .. currentItem .. " | fashion: " .. itemName(presets.fashion[entry.key])
        )
    end
end

toggleWindow = function()
    if fullPanelOpen then
        fullPanelOpen = false
        resetOverlay()
    else
        fullPanelOpen = true
        resetOverlay()
        buildWindow()
    end
end

local function f8Hit()
    local ok, result = pcall(function()
        return PlayerInput.KeyHit(Keys.F8)
    end)
    return ok and result == true
end

Hook.Add("think", "barowardrobeswitcher.panel", function()
    if f8Hit() then
        toggleWindow()
    end

    local character = controlled()
    if character == nil then
        lastCharacter = nil
        if fullPanelOpen and window == nil then
            buildWindow()
        end
        if fullPanelOpen then
            drawOverlay()
        end
        return
    end

    sendRoundStartNotice()

    if character ~= lastCharacter then
        lastCharacter = character
    end

    if fullPanelOpen and window == nil then
        buildWindow()
    end
    if fullPanelOpen then
        drawOverlay()
    end

end)

Hook.Add("roundStart", "barowardrobeswitcher.notice", function()
    sendRoundStartNotice()
end)

Hook.Add("roundEnd", "barowardrobeswitcher.cleanup", function()
    fullPanelOpen = false
    resetOverlay()
    presets.fashion = {}
    clearAllVisualOverrides()
    lastCharacter = nil
    roundStartNoticeSent = false
end)

log("Loaded. Press F8 to open the wardrobe panel.")
