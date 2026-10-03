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
local mapButton, fluteButton
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
    for _, bag in ipairs(LuckyGrabbag.GetPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and itemIDs[info.itemID] then
                return info
            end
        end
    end
end

local function CreateButton(name)
    local btn
    btn = LuckyGrabbag.CreateIconButton({
        parent   = UIParent,
        name     = name,
        template = "SecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        tooltip  = function()
            GameTooltip:SetItemByID(btn.itemID)
        end,
    })
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("type", "item")
    LuckyGrabbag.DelveBar:Add(btn)
    return btn
end

local function ShowItem(btn, item)
    if not item then
        btn:Hide()
        return
    end
    btn.itemID = item.itemID
    btn:SetAttribute("item", item.itemName)
    if item.iconFileID then
        btn:SetNormalTexture(item.iconFileID)
    end
    btn:Show()
end

local function Refresh()
    -- Show, Hide and anchoring are protected on secure buttons; PLAYER_REGEN_ENABLED re-runs this.
    if InCombatLockdown() then return end

    local inDelve, tier = GetDelveInfo()
    local minLevel = db.delveMapMinLevel or 8
    local active = inDelve and ((tier == 0) or (tier >= minLevel))
    local flutePending = reachedRespawnPoint
        and not C_QuestLog.IsQuestFlaggedCompleted(BOUNTY_LOOTED_QUEST_ID)

    local map = active and db.showDelveMap and FindBagItem(BOUNTY_MAP_ITEM_IDS)
    local flute = active and db.showDelveFlute and flutePending and FindBagItem(FLUTE_ITEM_IDS)

    DevLog("Refresh: active=%s tier=%d minLevel=%d respawn=%s map=%s flute=%s",
        tostring(active), tier, minLevel, tostring(reachedRespawnPoint), tostring(map and true), tostring(flute and true))

    ShowItem(mapButton, map)
    ShowItem(fluteButton, flute)
    LuckyGrabbag.DelveBar:Layout()
end

function LuckyGrabbag.DelveMap:ApplySetting()
    if mapButton then
        Refresh()
    end
end

function LuckyGrabbag.DelveMap:Init(database)
    db = database

    mapButton = CreateButton("LGB_DelveMapButton")
    fluteButton = CreateButton("LGB_DelveFluteButton")

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
