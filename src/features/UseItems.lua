-- Lucky's Grab-bag: Pop-up buttons for consumable profession items
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.UseItems = {}

local ITEM_NAME_PATTERNS  = LuckyGrabbag.UseItemsData.itemNamePatterns   -- defined in UseItemsData.lua
local THALASSIAN_SUFFIXES = LuckyGrabbag.UseItemsData.thalassianSuffixes  -- defined in UseItemsData.lua
local TREATISE_PATTERN    = LuckyGrabbag.UseItemsData.treatisePattern     -- defined in UseItemsData.lua

local COMBINE_COUNT       = LuckyGrabbag.UseItemsData.combineCount       -- defined in UseItemsData.lua

-- itemID -> position in the data file's list, which is also its button position.
local COMBINABLE_ORDER = {}
for index, id in ipairs(LuckyGrabbag.UseItemsData.combinableItemIDs or {}) do
    COMBINABLE_ORDER[id] = index
end

local ITEM_ID_SET = {}
for _, id in ipairs(LuckyGrabbag.UseItemsData.itemIDs or {}) do
    ITEM_ID_SET[id] = true
end

local GARRISON_ITEM_SET = {}
for _, id in ipairs(LuckyGrabbag.UseItemsData.garrisonItemIDs) do
    GARRISON_ITEM_SET[id] = true
end

local DECOR_ENTRY = Enum.HousingCatalogEntryType.Decor

local BUTTON_SIZE = 42
local BUTTON_SPACING = 4
local PADDING = 8

-- corner: the edge that stays put while the bar grows away from it.
local GROW = {
    right = { corner = "TOPLEFT" },
    left  = { corner = "TOPRIGHT" },
    down  = { corner = "TOPLEFT", vertical = true },
    up    = { corner = "BOTTOMLEFT", vertical = true },
}

local db
local containerFrame
local buttons = {}
local showOutsideRestAreas = false
local inCombat = false

local DevLog = LuckyGrabbag.Logger("UseItems")

local decorByItemID = {}

local function IsDecor(itemID)
    if decorByItemID[itemID] == nil then
        local entry = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)
        decorByItemID[itemID] = entry ~= nil and entry.entryType == DECOR_ENTRY
    end
    return decorByItemID[itemID]
end

-- Every decor piece shares one button: it uses the first piece alphabetically, and the
-- next takes its place once that one is gone, however many different pieces you hold.
local function DecorSlot(decorByID)
    local slot
    local total = 0
    for _, decor in pairs(decorByID) do
        total = total + decor.count
        if not slot or decor.itemName < slot.itemName then slot = decor end
    end
    if not slot then return nil end
    return { itemID = slot.itemID, itemName = slot.itemName, icon = slot.icon, count = total }
end

local function IsMatchingItem(itemName, itemID)
    if itemID and (ITEM_ID_SET[itemID] or db.useItemsCustom[itemID]) then return true end
    if itemID and GARRISON_ITEM_SET[itemID] then
        -- ponytail: one hard-coded zone; make it a per-item zone table when a second zone-locked item appears
        return C_Garrison.IsPlayerInGarrison(Enum.GarrisonType.Type_6_0_Garrison)
    end
    if itemID and COMBINABLE_ORDER[itemID] then return db.useItemsShowCombinable end
    if not itemName then return false end
    for _, pattern in ipairs(ITEM_NAME_PATTERNS) do
        if string.find(itemName, pattern, 1, true) then
            return true
        end
    end
    -- Match "Thalassian <profession> Folio/Notebook/Journal"
    if string.find(itemName, "Thalassian", 1, true) then
        for _, suffix in ipairs(THALASSIAN_SUFFIXES) do
            if string.find(itemName, suffix, 1, true) then
                return true
            end
        end
    end
    return false
end

local function ScanBags()
    local found = {}
    local decorByID = {}
    local totalSlots, totalItems = 0, 0
    -- Includes the reagent bag, where finishing reagents and other profession
    -- consumables file themselves automatically.
    for _, bag in ipairs(LuckyGrabbag.GetPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        totalSlots = totalSlots + numSlots
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                totalItems = totalItems + 1
                local itemName = info.itemName
                if not itemName then
                    -- itemName can be nil if item data isn't cached yet
                    itemName = C_Item.GetItemNameByID(info.itemID)
                    DevLog("  Bag %d slot %d: itemID=%d itemName was nil, C_Item fallback=%s", bag, slot, info.itemID, tostring(itemName))
                end
                if itemName and db.useItemsShowDecor and IsDecor(info.itemID) then
                    local decor = decorByID[info.itemID]
                    if decor then
                        decor.count = decor.count + (info.stackCount or 1)
                    else
                        decorByID[info.itemID] = { itemID = info.itemID, itemName = itemName, icon = info.iconFileID, count = info.stackCount or 1 }
                    end
                elseif itemName and IsMatchingItem(itemName, info.itemID) then
                    -- Skip treatises the character can't use (wrong profession) or already used this week
                    if string.find(itemName, TREATISE_PATTERN, 1, true) and not LuckyGrabbag.Treatise:CanCharacterUse(info.itemID) then
                        DevLog("  SKIP (no matching profession): %s (itemID=%d)", itemName, info.itemID)
                    elseif string.find(itemName, TREATISE_PATTERN, 1, true) and LuckyGrabbag.Treatise:IsUsedThisWeek(info.itemID) then
                        DevLog("  SKIP (used this week): %s (itemID=%d)", itemName, info.itemID)
                    elseif not found[info.itemID] then
                        found[info.itemID] = {
                            itemID = info.itemID,
                            itemName = itemName,
                            icon = info.iconFileID,
                            count = info.stackCount or 1,
                            combinable = COMBINABLE_ORDER[info.itemID],
                            minCount = db.useItemsCustom[info.itemID]
                                or (COMBINABLE_ORDER[info.itemID] and COMBINE_COUNT),
                        }
                    else
                        found[info.itemID].count = found[info.itemID].count + (info.stackCount or 1)
                    end
                end
            end
        end
    end
    DevLog("Scanned %d slots, %d items occupied", totalSlots, totalItems)
    local items = {}
    for _, item in pairs(found) do
        -- A combine consumes a full set, so a smaller pile has nothing to offer yet.
        if item.minCount and item.count < item.minCount then
            DevLog("  SKIP (only " .. item.count .. " of " .. item.minCount .. "): " .. item.itemName)
        else
            table.insert(items, item)
        end
    end
    table.sort(items, function(a, b)
        if a.combinable and b.combinable then return a.combinable < b.combinable end
        if a.combinable or b.combinable then return b.combinable ~= nil end
        return a.itemName < b.itemName
    end)
    local decor = DecorSlot(decorByID)
    if decor then table.insert(items, decor) end
    return items
end

local function SavePosition()
    if not containerFrame then return end
    local point, _, relPoint, x, y = containerFrame:GetPoint()
    db.useItemsPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CornerOnScreen(f, corner)
    local left, bottom, width, height = f:GetRect()
    if not left then return nil end
    local scale = f:GetEffectiveScale()
    local x = corner:find("RIGHT") and left + width or left
    local y = corner:find("TOP") and bottom + height or bottom
    return x * scale, y * scale
end

-- Pins the grow corner where it sits on screen, so resizing or rescaling extends the
-- bar in the chosen direction instead of around whatever point it was dragged by.
local function ApplyLayout(shown)
    local grow = GROW[db.useItemsGrow] or GROW.right
    local screenX, screenY = CornerOnScreen(containerFrame, grow.corner)

    containerFrame:SetScale(db.useItemsScale / 100)
    local length = PADDING * 2 + shown * BUTTON_SIZE + (shown - 1) * BUTTON_SPACING
    local thickness = BUTTON_SIZE + PADDING * 2
    if grow.vertical then
        containerFrame:SetSize(thickness, length)
    else
        containerFrame:SetSize(length, thickness)
    end

    if screenX then
        local scale = containerFrame:GetEffectiveScale()
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint(grow.corner, UIParent, "BOTTOMLEFT", screenX / scale, screenY / scale)
        SavePosition()
    end

    local signX = grow.corner:find("RIGHT") and -1 or 1
    local signY = grow.corner:find("TOP") and -1 or 1
    for i = 1, shown do
        local along = PADDING + (i - 1) * (BUTTON_SIZE + BUTTON_SPACING)
        local btn = buttons[i]
        btn:ClearAllPoints()
        btn:SetPoint(grow.corner, containerFrame, grow.corner,
            signX * (grow.vertical and PADDING or along),
            signY * (grow.vertical and along or PADDING))
    end
end

local function RestorePosition(f)
    local pos = db.useItemsPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        DevLog("Restored position: " .. pos.point .. " " .. pos.relPoint .. " " .. math.floor(pos.x) .. "," .. math.floor(pos.y))
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end

local function CreateContainer()
    local f = CreateFrame("Frame", "LuckyGrabbagUseItemsFrame", UIParent, "BackdropTemplate")
    f:SetSize(100, BUTTON_SIZE + 16)
    RestorePosition(f)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.1, 0.07, 0.04, 0.9)
    f:SetBackdropBorderColor(0.79, 0.66, 0.3, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("RightButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:Hide()
    return f
end

local function GetOrCreateButton(index)
    if buttons[index] then return buttons[index] end

    local btn = CreateFrame("Button", "LuckyGrabbagUseItemBtn" .. index, containerFrame, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:RegisterForClicks("AnyDown", "AnyUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)
    btn.cooldown = cooldown

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    local countText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
    countText:SetPoint("BOTTOMRIGHT", -2, 2)
    countText:SetDrawLayer("OVERLAY", 7)
    btn.count = countText

    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", function() containerFrame:StartMoving() end)
    btn:SetScript("OnDragStop", function()
        containerFrame:StopMovingOrSizing()
        SavePosition()
    end)

    btn:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    btn:Hide()
    buttons[index] = btn
    return btn
end

local function UpdateCooldowns()
    for _, btn in ipairs(buttons) do
        if btn:IsShown() and btn.itemID then
            local start, duration, enable = C_Container.GetItemCooldown(btn.itemID)
            if start and duration and enable == 1 then
                btn.cooldown:SetCooldown(start, duration)
            else
                btn.cooldown:Clear()
            end
        end
    end
end

local function UpdateButtons()
    DevLog("UpdateButtons called, inCombat=%s showUseItems=%s", tostring(inCombat), tostring(db.showUseItems))
    if inCombat then
        DevLog("Skipping update (in combat)")
        return
    end
    if not db.showUseItems then
        DevLog("Feature disabled, hiding")
        if containerFrame then containerFrame:Hide() end
        return
    end
    if db.useItemsCityOnly and not IsResting() and not showOutsideRestAreas then
        DevLog("City-only mode active and not in a rest area, hiding")
        if containerFrame then containerFrame:Hide() end
        return
    end

    local items = ScanBags()
    DevLog("Found " .. #items .. " matching item type(s)")

    if not containerFrame then
        containerFrame = CreateContainer()
    end

    if #items == 0 then
        containerFrame:Hide()
        for _, btn in ipairs(buttons) do btn:Hide() end
        return
    end

    local shown = math.min(#items, db.useItemsMaxButtons)
    for i = 1, shown do
        local btn = GetOrCreateButton(i)
        local item = items[i]
        btn.itemID = item.itemID
        btn.icon:SetTexture(item.icon)
        btn.count:SetText(item.count > 1 and item.count or "")
        btn:SetAttribute("type", "item")
        -- Item name is ambiguous: several knowledge items share one name.
        btn:SetAttribute("item", "item:" .. item.itemID)
        btn:Show()
        DevLog("  " .. item.itemName .. " x" .. item.count)
    end

    for i = shown + 1, #buttons do
        buttons[i]:Hide()
    end

    ApplyLayout(shown)
    containerFrame:Show()

    UpdateCooldowns()
end

function LuckyGrabbag.UseItems:ApplySetting()
    UpdateButtons()
end

function LuckyGrabbag.UseItems:ToggleOutsideRestAreas()
    showOutsideRestAreas = not showOutsideRestAreas
    UpdateButtons()
    return showOutsideRestAreas
end

local function ItemLabel(itemID)
    return C_Item.GetItemNameByID(itemID) or ("item:" .. itemID)
end

-- Accepts an item link or ID, then an optional count: "add 12345 5" or "add [Link] 5".
-- The link is cut out first so digits in an item's name are never read as the count.
local function ParseItemArgs(args)
    local linkID = tonumber(args:match("item:(%d+)"))
    local numbers = {}
    for n in args:gsub("|c.-|r", ""):gmatch("%d+") do numbers[#numbers + 1] = tonumber(n) end
    if linkID then return linkID, numbers[1] end
    return numbers[1], numbers[2]
end

local customWindow
local RefreshCustomWindow

local function SetCustom(itemID, minCount)
    db.useItemsCustom[itemID] = minCount and math.max(minCount, 1) or nil
    RefreshCustomWindow()
    UpdateButtons()
end

local function PrintCustomList(S)
    if not next(db.useItemsCustom) then
        print(LuckyGrabbag.PREFIX .. " " .. S.customEmpty)
        return
    end
    print(LuckyGrabbag.PREFIX .. " " .. S.customHeader)
    for itemID, minCount in pairs(db.useItemsCustom) do
        print(S.customEntry:format(ItemLabel(itemID), itemID, minCount))
    end
end

-- Returns false when the subcommand is not one of add, remove or list.
function LuckyGrabbag.UseItems:HandleCustomCommand(subcommand, args)
    local S = LuckyGrabbag.Strings.useItems
    if subcommand == "list" then
        PrintCustomList(S)
        return true
    end
    if subcommand ~= "add" and subcommand ~= "remove" then return false end

    local itemID, minCount = ParseItemArgs(args)
    if not itemID then
        print(LuckyGrabbag.PREFIX .. " " .. S.customUsage)
    elseif subcommand == "add" then
        SetCustom(itemID, minCount or 1)
        print(LuckyGrabbag.PREFIX .. " " .. S.customAdded:format(ItemLabel(itemID), db.useItemsCustom[itemID]))
    elseif db.useItemsCustom[itemID] then
        SetCustom(itemID, nil)
        print(LuckyGrabbag.PREFIX .. " " .. S.customRemoved:format(ItemLabel(itemID)))
    else
        print(LuckyGrabbag.PREFIX .. " " .. S.customNotListed:format(ItemLabel(itemID)))
    end
    return true
end

local C = LuckyUI.C
local FONT = LuckyUI.BODY_FONT
local ROW_HEIGHT = 28

local function CountBoxValue()
    return tonumber(customWindow.countEdit:GetText()) or 1
end

local function AddFromCursor()
    local infoType, itemID = GetCursorInfo()
    if infoType ~= "item" or not itemID then return end
    ClearCursor()
    SetCustom(itemID, CountBoxValue())
end

local function AcceptDrops(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnReceiveDrag", AddFromCursor)
    frame:SetScript("OnMouseDown", AddFromCursor)
end

local function CreateLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, 12, "")
    fs:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    fs:SetText(text)
    return fs
end

local function BuildCustomRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(400, ROW_HEIGHT - 2)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 10, 0)
    row.label = CreateLabel(row, "")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.label:SetWidth(280)
    row.label:SetJustifyH("LEFT")
    row.count = CreateLabel(row, "")
    row.count:SetPoint("RIGHT", -10, 0)
    row:EnableMouse(true)
    row:SetScript("OnReceiveDrag", AddFromCursor)
    row:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            SetCustom(self.itemID, nil)
        else
            AddFromCursor()
        end
    end)
    return row
end

RefreshCustomWindow = function()
    if not customWindow or not customWindow:IsShown() then return end
    local S = LuckyGrabbag.Strings.useItems

    local ids = {}
    for itemID in pairs(db.useItemsCustom) do ids[#ids + 1] = itemID end
    table.sort(ids, function(a, b) return ItemLabel(a) < ItemLabel(b) end)

    local rows = customWindow.rows
    for i, itemID in ipairs(ids) do
        rows[i] = rows[i] or BuildCustomRow(customWindow.itemParent)
        local row = rows[i]
        local _, link = C_Item.GetItemInfo(itemID)
        row.itemID = itemID
        row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
        row.label:SetText(link or ItemLabel(itemID))
        row.count:SetText(S.customRowCount:format(db.useItemsCustom[itemID]))
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()
    end
    for i = #ids + 1, #rows do rows[i]:Hide() end
    customWindow.empty:SetShown(#ids == 0)
    customWindow.itemParent:SetHeight(math.max(#ids * ROW_HEIGHT, 1))
end

local function BuildCustomWindow()
    local S = LuckyGrabbag.Strings.useItems
    local f, titleBar = LuckyUI.CreateWindow("LuckyGrabbagUseItemsCustomWindow", 460, 420, S.customTitle,
        { db = db, key = "useItemsCustomWindowPos" })

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    AcceptDrops(body)

    local hint = CreateLabel(body, S.customHint)
    hint:SetPoint("TOPLEFT", 14, -14)
    hint:SetPoint("TOPRIGHT", -14, -14)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(3)
    hint:SetWordWrap(true)
    hint:SetHeight(48)

    local itemLabel = CreateLabel(body, S.customItemLabel)
    itemLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)

    local itemEdit = LuckyUI.CreateInput(body, { width = 150, height = 22 })
    itemEdit:SetPoint("LEFT", itemLabel, "RIGHT", 8, 0)

    local countLabel = CreateLabel(body, S.customCountLabel)
    countLabel:SetPoint("LEFT", itemEdit, "RIGHT", 12, 0)

    local countEdit = LuckyUI.CreateInput(body, { width = 44, height = 22, maxLetters = 4 })
    countEdit:SetPoint("LEFT", countLabel, "RIGHT", 8, 0)
    countEdit:SetNumeric(true)
    countEdit:SetText("1")
    f.countEdit = countEdit

    local function AddTyped()
        local itemID = ParseItemArgs(itemEdit:GetText())
        if not itemID then return end
        SetCustom(itemID, CountBoxValue())
        itemEdit:SetText("")
        itemEdit:ClearFocus()
    end
    local addBtn = LuckyUI.CreateButton(body, S.customAddButton, 70, 22, "primary")
    addBtn:SetPoint("LEFT", countEdit, "RIGHT", 8, 0)
    addBtn:SetScript("OnClick", AddTyped)
    itemEdit:SetScript("OnEnterPressed", AddTyped)

    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", -14, -16)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    AcceptDrops(scroll)

    local itemParent = CreateFrame("Frame", nil, scroll)
    itemParent:SetSize(400, 1)
    scroll:SetScrollChild(itemParent)
    AcceptDrops(itemParent)
    f.itemParent = itemParent
    f.rows = {}

    f.empty = CreateLabel(scroll, S.customWindowEmpty)
    f.empty:SetPoint("TOP", 0, -20)

    f:HookScript("OnShow", RefreshCustomWindow)
    return f
end

function LuckyGrabbag.UseItems:OpenCustomWindow()
    customWindow = customWindow or BuildCustomWindow()
    customWindow:Show()
end

function LuckyGrabbag.UseItems:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            UpdateButtons()
        elseif event == "BAG_UPDATE_COOLDOWN" then
            UpdateCooldowns()
        else
            UpdateButtons()
        end
    end)

    DevLog("Init complete, scheduling initial scan in 1s")
    C_Timer.After(1, UpdateButtons)
end
