-- Lucky's Grab-bag: Transmog NPC — keep active tab on slot change
-- Works with stock Blizzard and BetterWardrobeAndTransmog.
-- Both call WardrobeCollection:UpdateSlot on slot click, which resets
-- to the Items tab via SetToItemsTab(). We poll TabHeaders.selectedTabID
-- between frames to remember the user's last tab, then restore it
-- after TransmogFrame:SelectSlot runs.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Transmog = {}

local db
local hooked  = false
local userTab = nil
local watcher = nil

local function DevLog(msg)
    LuckyGrabbag.DevLog("Transmog", msg)
end

local function GetWardrobeCollection()
    return TransmogFrame and TransmogFrame.WardrobeCollection
end

local function InstallHooks()
    if hooked then return end
    local wc = GetWardrobeCollection()
    if not wc or not wc.TabHeaders or not wc.itemsTabID then return end
    if not TransmogFrame or type(TransmogFrame.SelectSlot) ~= "function" then return end
    if type(wc.SetTab) ~= "function" then return end

    local th = wc.TabHeaders

    -- Poll between frames so we always have the most recent tab
    -- before any in-frame reset clobbers it.
    watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function()
        local id = th.selectedTabID
        if id then
            userTab = id
        end
    end)

    hooksecurefunc(TransmogFrame, "SelectSlot", function()
        if not db or not db.keepTransmogTab then return end
        if not userTab then return end
        if th.selectedTabID == userTab then return end
        DevLog("Restoring tab to " .. tostring(userTab))
        wc:SetTab(userTab)
    end)

    hooked = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
eventFrame:RegisterEvent("TRANSMOGRIFY_CLOSE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "TRANSMOGRIFY_OPEN" then
        userTab = nil
        if watcher then watcher:Show() end
        C_Timer.After(0.1, InstallHooks)
    elseif event == "TRANSMOGRIFY_CLOSE" then
        userTab = nil
        if watcher then watcher:Hide() end
    end
end)

function LuckyGrabbag.Transmog:Init(database)
    db = database
end
