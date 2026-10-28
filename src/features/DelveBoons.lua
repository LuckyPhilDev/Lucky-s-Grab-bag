LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveBoons = {}

local BOONS_SPELL_ID = 1280098
local DELVE_DIFFICULTY_ID = 208
local PAD = 8
local WIDTH = 190
local STALE_ALPHA = 0.5

local C = LuckyUI.C

local db
local panel, body

local DevLog = LuckyGrabbag.Logger("DelveBoons")

local function InDelve()
    local _, _, difficultyID = GetInstanceInfo()
    return difficultyID == DELVE_DIFFICULTY_ID
end

local function ReadBoons()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(BOONS_SPELL_ID)
    if not aura then return end
    local data = C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", aura.auraInstanceID)
    if not data then return end
    local lines = {}
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if text and text ~= "" then
            lines[#lines + 1] = text:gsub("%.$", "")
        end
    end
    return table.concat(lines, "\n")
end

local function SavePosition()
    local point, _, relPoint, x, y = panel:GetPoint()
    db.delveBoonsPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CreatePanel()
    local f = CreateFrame("Frame", "LuckyGrabbagDelveBoonsFrame", UIParent, "BackdropTemplate")
    f:SetWidth(WIDTH)
    local pos = db.delveBoonsPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("RIGHT", UIParent, "RIGHT", -260, 100)
    end
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.92)
    f:SetBackdropBorderColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3], 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("RightButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("LOW")
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(LuckyUI.TITLE_FONT, 11, "")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetTextColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
    title:SetText(LuckyGrabbag.Strings.delveBoons.title)

    body = f:CreateFontString(nil, "OVERLAY")
    body:SetFont(LuckyUI.BODY_FONT, 11, "")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    body:SetWidth(WIDTH - PAD * 2)
    body:SetJustifyH("LEFT")
    body:SetSpacing(2)
    body:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])

    panel = f
end

-- Aura data is secret in combat, so the panel keeps the last reading, dimmed, until combat ends.
local function Refresh()
    if not db.showDelveBoons or not InDelve() then
        panel:Hide()
        return
    end
    if InCombatLockdown() then
        panel:SetAlpha(STALE_ALPHA)
        return
    end
    local text = ReadBoons()
    DevLog("Refresh: %s", tostring(text and true))
    panel:SetAlpha(1)
    if not text or text == "" then
        panel:Hide()
        return
    end
    body:SetText(text)
    panel:SetHeight(PAD * 2 + 15 + body:GetStringHeight())
    panel:Show()
end

function LuckyGrabbag.DelveBoons:ApplySetting()
    if panel then Refresh() end
end

function LuckyGrabbag.DelveBoons:Init(database)
    db = database
    CreatePanel()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:SetScript("OnEvent", function(_, event)
        Refresh()
        -- GetInstanceInfo() can lag the loading screen.
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            C_Timer.After(1, Refresh)
        end
    end)
end
