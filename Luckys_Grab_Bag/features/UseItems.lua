-- Lucky's Grab-bag: Pop-up buttons for consumable profession items
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.UseItems = {}

local ITEM_NAME_PATTERNS  = LuckyGrabbag.UseItemsData.itemNamePatterns   -- defined in UseItemsData.lua
local THALASSIAN_SUFFIXES = LuckyGrabbag.UseItemsData.thalassianSuffixes  -- defined in UseItemsData.lua
local TREATISE_PATTERN    = LuckyGrabbag.UseItemsData.treatisePattern     -- defined in UseItemsData.lua

local BUTTON_SIZE = 42
local BUTTON_SPACING = 4
local MAX_BUTTONS = 12

local db
local containerFrame
local buttons = {}
local inCombat = false

local function DevLog(msg)
    LuckyGrabbag.DevLog("UseItems", msg)
end

local function IsMatchingItem(itemName)
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

-- Scans all bags and returns a sorted array of { itemID, itemName, icon, count }
-- for items whose names match any of the target patterns.
-- Multiple stacks of the same item are consolidated into one entry.
local function ScanBags()
    local found = {}
    local totalSlots, totalItems = 0, 0
    for bag = 0, NUM_BAG_SLOTS do
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
                    DevLog("  Bag " .. bag .. " slot " .. slot .. ": itemID=" .. info.itemID .. " itemName was nil, C_Item fallback=" .. tostring(itemName))
                end
                if itemName and IsMatchingItem(itemName) then
                    -- Skip treatises the character can't use (wrong profession) or already used this week
                    if string.find(itemName, TREATISE_PATTERN, 1, true) and not LuckyGrabbag.Treatise:CanCharacterUse(info.itemID) then
                        DevLog("  SKIP (no matching profession): " .. itemName .. " (itemID=" .. info.itemID .. ")")
                    elseif string.find(itemName, TREATISE_PATTERN, 1, true) and LuckyGrabbag.Treatise:IsUsedThisWeek(info.itemID) then
                        DevLog("  SKIP (used this week): " .. itemName .. " (itemID=" .. info.itemID .. ")")
                    elseif not found[info.itemID] then
                        found[info.itemID] = {
                            itemID = info.itemID,
                            itemName = itemName,
                            icon = info.iconFileID,
                            count = info.stackCount or 1,
                        }
                    else
                        found[info.itemID].count = found[info.itemID].count + (info.stackCount or 1)
                    end
                end
            end
        end
    end
    DevLog("Scanned " .. totalSlots .. " slots, " .. totalItems .. " items occupied")
    local items = {}
    for _, item in pairs(found) do
        table.insert(items, item)
    end
    table.sort(items, function(a, b) return a.itemName < b.itemName end)
    return items
end

local function SavePosition()
    if not containerFrame then return end
    local point, _, relPoint, x, y = containerFrame:GetPoint()
    db.useItemsPos = { point = point, relPoint = relPoint, x = x, y = y }
    DevLog("Saved position: " .. point .. " " .. relPoint .. " " .. math.floor(x) .. "," .. math.floor(y))
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
    DevLog("UpdateButtons called — inCombat=" .. tostring(inCombat) .. " showUseItems=" .. tostring(db.showUseItems))
    if inCombat then
        DevLog("Skipping update (in combat)")
        return
    end
    if not db.showUseItems then
        DevLog("Feature disabled, hiding")
        if containerFrame then containerFrame:Hide() end
        return
    end
    if db.useItemsCityOnly and not IsResting() then
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

    local shown = math.min(#items, MAX_BUTTONS)
    for i = 1, shown do
        local btn = GetOrCreateButton(i)
        local item = items[i]
        btn.itemID = item.itemID
        btn.icon:SetTexture(item.icon)
        btn.count:SetText(item.count > 1 and item.count or "")
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", item.itemName)
        btn:SetPoint("LEFT", containerFrame, "LEFT", 8 + (i - 1) * (BUTTON_SIZE + BUTTON_SPACING), 0)
        btn:Show()
        DevLog("  " .. item.itemName .. " x" .. item.count)
    end

    for i = shown + 1, #buttons do
        buttons[i]:Hide()
    end

    local totalWidth = 8 + shown * BUTTON_SIZE + (shown - 1) * BUTTON_SPACING + 8
    containerFrame:SetSize(totalWidth, BUTTON_SIZE + 16)
    containerFrame:Show()

    UpdateCooldowns()
end

function LuckyGrabbag.UseItems:ApplySetting()
    UpdateButtons()
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
    eventFrame:SetScript("OnEvent", function(_, event)
        DevLog("Event fired: " .. event)
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
