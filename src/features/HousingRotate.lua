-- Lucky's Grab-bag: exact-degree rotation buttons for the House Editor
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.HousingRotate = {}

local db
local panel
local trackedDeg = 0
local selGUID
local rotLocked = false
local rotDir

local function DevLog(msg)
    LuckyGrabbag.DevLog("HousingRotate", msg)
end

local function safe(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

local function IsExpertMode()
    local mode = safe(C_HouseEditor and C_HouseEditor.GetActiveHouseEditorMode)
    local expertType = Enum and Enum.HouseEditorMode and Enum.HouseEditorMode.ExpertDecor
    return mode ~= nil and expertType ~= nil and mode == expertType
end

local function IsExpertSelected()
    return safe(C_HousingExpertMode and C_HousingExpertMode.IsDecorSelected) == true
end

-- Housing only exposes rotation as a hold-to-increment pulse, never an
-- absolute setter or getter. Rate confirmed against two independent decor
-- addons: 45 degrees per second while held.
local DEGREES_PER_SECOND = 45.0

-- Entering the Rotate submode always resets the axis cursor to X, and
-- SelectNextRotationAxis only moves forward, so re-selecting Translate then
-- Rotate before every pulse guarantees a known starting point. Two advances
-- from X lands on Z, WoW's vertical axis, the one that spins a floor decor
-- item in place to face a different wall.
local function EnsureRotateZAxis()
    local submode = Enum and Enum.HousingPrecisionSubmode
    if not submode then return end
    safe(C_HousingExpertMode.SetPrecisionSubmode, submode.Translate)
    safe(C_HousingExpertMode.SetPrecisionSubmode, submode.Rotate)
    safe(C_HousingExpertMode.SelectNextRotationAxis)
    safe(C_HousingExpertMode.SelectNextRotationAxis)
end

local function UpdateReadout()
    if panel and panel.readout then
        panel.readout:SetText(string.format(LuckyGrabbag.Strings.housingRotate.degreeFmt, trackedDeg))
    end
end

local function CancelPulse()
    if not rotLocked then return end
    if rotDir then
        safe(C_HousingExpertMode.SetPrecisionIncrementingActive, rotDir, false)
    end
    rotLocked = false
    DevLog("Cancelled in-progress pulse")
end

local function RotatePulse(degrees)
    if not IsExpertMode() or not IsExpertSelected() then
        rotLocked = false
        return
    end

    local incType = Enum and Enum.HousingIncrementType
    if not incType then
        rotLocked = false
        return
    end

    rotDir = degrees > 0 and incType.RotateRight or incType.RotateLeft
    local holdSecs = math.abs(degrees) / DEGREES_PER_SECOND
    local startTime = GetTime()

    safe(C_HousingExpertMode.SetPrecisionIncrementingActive, rotDir, true)

    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(self)
        if GetTime() - startTime < holdSecs then return end
        self:SetScript("OnUpdate", nil)
        safe(C_HousingExpertMode.SetPrecisionIncrementingActive, rotDir, false)
        rotLocked = false
        trackedDeg = (trackedDeg + degrees) % 360
        UpdateReadout()
        DevLog(string.format("Pulsed %+d deg, tracked now %d", degrees, trackedDeg))
    end)
end

-- Locks immediately (not just once the pulse starts) so a second click fired
-- during the settle delay below is dropped instead of racing the first.
local function DoRotate(degrees)
    if rotLocked or not degrees or degrees == 0 then return end
    if not IsExpertMode() or not IsExpertSelected() then return end
    rotLocked = true
    EnsureRotateZAxis()
    C_Timer.After(0.08, function() RotatePulse(degrees) end)
end

local function ResetRotation()
    if rotLocked then return end
    if not IsExpertMode() or not IsExpertSelected() then return end
    EnsureRotateZAxis()
    safe(C_HousingExpertMode.ResetPrecisionChanges, true)
    trackedDeg = 0
    UpdateReadout()
    DevLog("Reset rotation to 0")
end

local C = LuckyUI.C

-- Same styled-button convention used across Grab-bag's floating panels (see
-- CombatPrep.lua); each feature file keeps its own copy rather than sharing one.
local function CreateStyledButton(parent, opts)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(opts.width or 100, opts.height or 28)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local isPrimary = (opts.variant ~= "secondary")

    local function SetNormalColors()
        if isPrimary then
            btn:SetBackdropColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3], 1)
            btn:SetBackdropBorderColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3], 1)
        else
            btn:SetBackdropColor(0.05, 0.04, 0.02, 1)
            btn:SetBackdropBorderColor(0.23, 0.18, 0.10, 1)
        end
    end
    SetNormalColors()

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    label:SetPoint("CENTER", 0, 0)
    if isPrimary then
        label:SetTextColor(C.bgDark[1], C.bgDark[2], C.bgDark[3])
    else
        label:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    end
    btn.label = label

    btn:SetScript("OnEnter", function()
        if isPrimary then
            btn:SetBackdropColor(
                math.min(C.goldAccent[1] + 0.1, 1),
                math.min(C.goldAccent[2] + 0.1, 1),
                math.min(C.goldAccent[3] + 0.1, 1),
                1
            )
        else
            btn:SetBackdropColor(0.10, 0.08, 0.05, 1)
            btn:SetBackdropBorderColor(C.goldMuted[1], C.goldMuted[2], C.goldMuted[3], 1)
        end
    end)
    btn:SetScript("OnLeave", SetNormalColors)

    btn:SetScript("OnMouseDown", function()
        if isPrimary then
            btn:SetBackdropColor(C.goldMuted[1], C.goldMuted[2], C.goldMuted[3], 1)
        else
            btn:SetBackdropColor(0.03, 0.02, 0.01, 1)
        end
        label:SetPoint("CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function()
        SetNormalColors()
        label:SetPoint("CENTER", 0, 0)
    end)

    function btn:SetText(text)
        self.label:SetText(text)
    end

    return btn
end

local function SavePosition()
    if not panel then return end
    local point, _, relPoint, x, y = panel:GetPoint()
    db.housingRotatePos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition(f)
    local pos = db.housingRotatePos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -240)
    end
end

local LEFT_STEPS  = { -90, -15, -5 }
local RIGHT_STEPS = { 5, 15, 90 }
local BTN_W, BTN_H, GAP, READOUT_W = 34, 28, 4, 54

local function GetExpertFrame()
    return HouseEditorFrame and HouseEditorFrame.ExpertDecorModeFrame
end

-- The panel must be a child of the House Editor's expert-mode frame, not
-- UIParent: while the editor is active a plain UIParent frame renders behind
-- the editor's own UI. This is why it has to be built lazily, that frame does
-- not exist until the editor loads.
local function CreatePanel()
    if panel then return end

    local expertFrame = GetExpertFrame()
    if not expertFrame then return end

    local S = LuckyGrabbag.Strings.housingRotate

    local f = CreateFrame("Frame", "LuckyGrabbagHousingRotateFrame", expertFrame, "BackdropTemplate")
    RestorePosition(f)
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
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(50)
    f:Hide()

    local x, rowY = 10, -10

    for _, degrees in ipairs(LEFT_STEPS) do
        local btn = CreateStyledButton(f, { width = BTN_W, height = BTN_H, variant = "secondary" })
        btn:SetText(string.format(S.degreeBtnFmt, degrees))
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, rowY)
        btn:SetScript("OnClick", function() DoRotate(degrees) end)
        x = x + BTN_W + GAP
    end

    local readout = f:CreateFontString(nil, "OVERLAY")
    readout:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    readout:SetTextColor(C.textGold[1], C.textGold[2], C.textGold[3])
    readout:SetSize(READOUT_W, BTN_H)
    readout:SetJustifyH("CENTER")
    readout:SetJustifyV("MIDDLE")
    readout:SetPoint("TOPLEFT", f, "TOPLEFT", x, rowY)
    readout:SetText(string.format(S.degreeFmt, 0))
    f.readout = readout
    x = x + READOUT_W + GAP

    for _, degrees in ipairs(RIGHT_STEPS) do
        local btn = CreateStyledButton(f, { width = BTN_W, height = BTN_H, variant = "secondary" })
        btn:SetText(string.format(S.degreeBtnFmt, degrees))
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, rowY)
        btn:SetScript("OnClick", function() DoRotate(degrees) end)
        x = x + BTN_W + GAP
    end

    local width = x - GAP + 10
    f:SetSize(width, 76)

    local resetBtn = CreateStyledButton(f, { width = width - 20, height = 24, variant = "primary" })
    resetBtn:SetText(S.resetLabel)
    resetBtn:SetPoint("TOP", f, "TOP", 0, -42)
    resetBtn:SetScript("OnClick", ResetRotation)

    panel = f
    DevLog("Panel created")
end

local function UpdateVisibility()
    if not db.showHousingRotate or not IsExpertMode() then
        CancelPulse()
        if panel then panel:Hide() end
        return
    end

    CreatePanel()
    if not panel then return end

    -- Reset the running total whenever a different item is picked. With nothing
    -- selected the buttons simply no-op until the user clicks a piece of decor.
    local info = safe(C_HousingExpertMode.GetSelectedDecorInfo)
    local guid = info and info.decorGUID
    if guid ~= selGUID then
        selGUID = guid
        trackedDeg = 0
        UpdateReadout()
        DevLog("Selection changed, tracked degrees reset")
    end

    panel:Show()
end

function LuckyGrabbag.HousingRotate:ApplySetting()
    UpdateVisibility()
end

function LuckyGrabbag.HousingRotate:Init(database)
    db = database
    DevLog("Init called")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("HOUSE_EDITOR_MODE_CHANGED")
    eventFrame:RegisterEvent("HOUSING_EXPERT_MODE_SELECTED_TARGET_CHANGED")
    eventFrame:SetScript("OnEvent", function() UpdateVisibility() end)

    -- The editor frames don't exist at load. Hook the expert-mode subframe
    -- (parent of our panel) so entering and leaving Expert Mode drives the
    -- panel; leaving it also stops any pulse in progress.
    local wiredExpert = false
    local function WireExpertFrame()
        if wiredExpert then return end
        local expertFrame = GetExpertFrame()
        if not expertFrame then return end
        wiredExpert = true
        expertFrame:HookScript("OnShow", function() C_Timer.After(0.1, UpdateVisibility) end)
        expertFrame:HookScript("OnHide", function()
            CancelPulse()
            if panel then panel:Hide() end
        end)
    end

    -- Poll for HouseEditorFrame; once it exists, wire the expert subframe and
    -- react to the editor opening.
    local waitFrame = CreateFrame("Frame")
    waitFrame:SetScript("OnUpdate", function(self)
        if not HouseEditorFrame then return end
        self:SetScript("OnUpdate", nil)
        WireExpertFrame()
        HouseEditorFrame:HookScript("OnShow", function()
            WireExpertFrame()
            C_Timer.After(0.1, UpdateVisibility)
        end)
        if HouseEditorFrame:IsShown() then
            WireExpertFrame()
            UpdateVisibility()
        end
    end)
end
