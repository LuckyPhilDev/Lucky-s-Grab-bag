-- Lucky's Grab-bag: Transmog NPC — keep active tab on slot change
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Transmog = {}

local db

local FRAME_CANDIDATES = {
    "TransmogFrame",        -- confirmed Midnight name
    "WardrobeFrame",
    "TransmogrifyFrame",
    "WardrobeCollectionFrame",
}

local transmogFrameName = nil
local currentTab        = nil
local tabsHooked        = false
local selectSlotHooked  = false

local function FindTransmogFrame()
    if transmogFrameName then
        local f = _G[transmogFrameName]
        if f and f:IsShown() then return f end
    end
    for _, name in ipairs(FRAME_CANDIDATES) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then
            transmogFrameName = name
            return f
        end
    end
    return nil
end

local function FindTabByText(frame, targetText, depth)
    depth = depth or 0
    if depth > 2 or not frame then return nil end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetText and child:GetText() == targetText then
            return child
        end
        local found = FindTabByText(child, targetText, depth + 1)
        if found then return found end
    end
    return nil
end

local function SwitchToTab(tabName)
    local frame = FindTransmogFrame()
    if not frame then return end
    local tab = FindTabByText(frame, tabName)
    if tab then tab:Click() end
end

local function TrackTabChanges(frame)
    if tabsHooked then return end
    local tabNames = { "Items", "Sets", "Custom Sets", "Situations" }
    for _, name in ipairs(tabNames) do
        local btn = FindTabByText(frame, name)
        if btn then
            local captured = name
            btn:HookScript("OnClick", function()
                currentTab = captured
            end)
        end
    end
    tabsHooked = true
end

local function HookSelectSlot()
    if selectSlotHooked or not TransmogFrame then return end
    if type(TransmogFrame.SelectSlot) ~= "function" then return end
    hooksecurefunc(TransmogFrame, "SelectSlot", function()
        if db.keepTransmogTab and currentTab and currentTab ~= "Items" then
            C_Timer.After(0, function() SwitchToTab(currentTab) end)
        end
    end)
    selectSlotHooked = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
eventFrame:SetScript("OnEvent", function(_, event)
    if event ~= "TRANSMOGRIFY_OPEN" then return end
    if not db or not db.keepTransmogTab then return end
    C_Timer.After(0.1, function()
        local frame = FindTransmogFrame()
        if frame then TrackTabChanges(frame) end
        HookSelectSlot()
    end)
end)

function LuckyGrabbag.Transmog:Init(database)
    db = database
end
