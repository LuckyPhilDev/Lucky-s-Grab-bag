LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveMap = {}

-- One map item per season; the bag scan accepts any of them.
local BOUNTY_MAP_ITEM_IDS = {
    [252415] = true, -- Trovehunter's Bounty Map (Midnight Season 1)
    [274374] = true, -- Trovehunter's Bounty (Midnight Season 2)
}
local FLUTE_ITEM_IDS = {
    [275910] = true, -- Scalebound Herald's Flute (Midnight Season 2)
}
local BOUNTY_LOOTED_QUEST_ID = 86371
local DELVE_DIFFICULTY_ID = 208
local BUTTON_SIZE = 42

-- Widget IDs used by the scenario header to display the current delve tier.
-- C_GossipInfo.GetActiveDelveGossip and C_DelvesUI.GetCurrentDelveTier do not exist in 12.0.5+.
local DELVE_WIDGET_IDS = { 6183, 6184, 6185 }

local db
local button
local shownItemID = 274374
local reachedRespawnPoint = false

local DevLog = LuckyGrabbag.Logger("DelveMap")

-- Returns true + tier number if the player is in a delve, false otherwise.
-- Tier is read from the scenario header widget (the same source Blizzard uses on screen).
-- Returns 0 if the widget data is not yet available.
local function GetDelveInfo()
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= DELVE_DIFFICULTY_ID then
        return false, 0
    end

    if C_UIWidgetManager and C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo then
        for _, widgetID in ipairs(DELVE_WIDGET_IDS) do
            local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
            if info and info.shownState ~= 0 then
                local t = info.tierText
                if type(t) == "number" then t = tostring(t) end
                if type(t) == "string" then
                    t = t:gsub("^%s+", ""):gsub("%s+$", "")
                    local tier = tonumber(t)
                    if tier then
                        DevLog("Tier from widget " .. widgetID .. ": " .. tier)
                        return true, tier
                    end
                end
            end
        end
    end

    DevLog("In delve but tier unknown (widget not ready)")
    return true, 0
end

local function FindBagItem(itemIDs)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and itemIDs[info.itemID] then
                return info
            end
        end
    end
end

-- The map wins: it is usable anywhere, while the flute only matters until this week's map drops.
local function PickItem()
    local map = db.showDelveMap and FindBagItem(BOUNTY_MAP_ITEM_IDS)
    if map then return map end
    if db.showDelveFlute and reachedRespawnPoint
        and not C_QuestLog.IsQuestFlaggedCompleted(BOUNTY_LOOTED_QUEST_ID) then
        return FindBagItem(FLUTE_ITEM_IDS)
    end
end

local function CreateButton()
    local btn = LuckyGrabbag.CreateIconButton({
        parent   = UIParent,
        name     = "LGB_DelveMapButton",
        template = "SecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        tooltip  = function()
            GameTooltip:SetItemByID(shownItemID)
        end,
    })
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("type", "item")
    btn:SetFrameStrata("HIGH")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.delveMapPos = { point = point, relPoint = relPoint, x = x, y = y }
        DevLog("Saved position")
    end)
    btn:Hide()
    return btn
end

local function RestorePosition()
    local pos = db.delveMapPos
    if pos then
        button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

local function Refresh()
    -- Show and Hide are protected on a secure button; PLAYER_REGEN_ENABLED re-runs this.
    if InCombatLockdown() then return end

    local inDelve, tier = GetDelveInfo()
    local minLevel = db.delveMapMinLevel or 8
    local meetsLevel = (tier == 0) or (tier >= minLevel)
    local item = inDelve and meetsLevel and PickItem()

    DevLog("Refresh: inDelve=%s tier=%d minLevel=%d respawn=%s item=%s",
        tostring(inDelve), tier, minLevel, tostring(reachedRespawnPoint), tostring(item and item.itemID))

    if not item then
        button:Hide()
        return
    end
    shownItemID = item.itemID
    button:SetAttribute("item", item.itemName)
    if item.iconFileID then
        button:SetNormalTexture(item.iconFileID)
    end
    button:Show()
end

function LuckyGrabbag.DelveMap:ApplySetting()
    if button then
        Refresh()
    end
end

function LuckyGrabbag.DelveMap:Init(database)
    db = database

    button = CreateButton()
    RestorePosition()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("DISPLAY_EVENT_TOAST_LINK")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "DISPLAY_EVENT_TOAST_LINK" then
            -- ponytail: any toast inside a delve counts as the midway respawn point; match the link text if other toasts show up.
            if GetDelveInfo() then reachedRespawnPoint = true end
            Refresh()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            reachedRespawnPoint = false
        end
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            -- GetInstanceInfo() is often not ready yet when these fire during
            -- a loading screen. Refresh immediately (may catch it), then retry
            -- after a short delay to cover the late-availability case.
            Refresh()
            C_Timer.After(1, Refresh)
        else
            Refresh()
        end
    end)

    DevLog("Initialized")
end
