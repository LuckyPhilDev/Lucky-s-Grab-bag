LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveBar = {}

local BUTTON_SIZE = 42
local SPACING = 4

local bar
local buttons = {}

local function SavePosition()
    local point, _, relPoint, x, y = bar:GetPoint()
    LuckyGrabbag.db.delveBarPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function GetBar()
    if bar then return bar end
    bar = CreateFrame("Frame", "LGB_DelveBar", UIParent)
    bar:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    bar:SetFrameStrata("HIGH")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    -- Falls back to where the lone map button used to sit.
    local pos = LuckyGrabbag.db.delveBarPos or LuckyGrabbag.db.delveMapPos
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    return bar
end

function LuckyGrabbag.DelveBar:Add(btn)
    btn:SetParent(GetBar())
    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", function() bar:StartMoving() end)
    btn:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition()
    end)
    btn:Hide()
    buttons[#buttons + 1] = btn
end

-- Anchoring secure buttons is protected, so only call this out of combat.
function LuckyGrabbag.DelveBar:Layout()
    local x = 0
    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", bar, "LEFT", x, 0)
            x = x + btn:GetWidth() + SPACING
        end
    end
    bar:SetWidth(math.max(BUTTON_SIZE, x - SPACING))
end
