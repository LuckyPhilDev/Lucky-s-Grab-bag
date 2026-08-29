-- Lucky's Grab-bag: Combat Prep window for raids and Mythic+
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.CombatPrep = {}

local db
local prepFrame
local inCombat = false

local DevLog = LuckyGrabbag.Logger("CombatPrep")

-- Instance type as well as group, so a raid group parked in the open world and
-- a solo transmog run both miss out. Dungeons come back as "party" because
-- IsChallengeModeActive() only turns true once the key starts, which would miss
-- pre-key M+ and plain mythic. Scenarios are out because a solo delve still
-- counts as a group once Brann is along. In a raid the buttons only work for
-- the leader and assists, so everyone else is spared a window of dead buttons.
local function IsInQualifyingContent()
    local instanceType = LuckyGrabbag.GroupInstanceType()
    if instanceType == "raid" then
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    end
    return instanceType == "party" and IsInGroup()
end

-- Picks the appropriate pull timer for current content. Raids use the raid
-- slider; dungeons (M+) use the mythic slider. Falls back to mythic when the
-- frame is forced visible outside qualifying content.
local function GetActivePullTimer()
    if LuckyGrabbag.GroupInstanceType() == "raid" then
        return db.combatPrepTimerRaid or 12
    end
    return db.combatPrepTimerMythic or 10
end

-- Routes the break timer through DBM or BigWigs when either is loaded so the
-- whole group sees a proper break bar (the two boss mods broadcast breaks to
-- each other). Falls back to the Blizzard countdown when neither is present.
-- BigWigs owns the /break slash when both are loaded, so it takes priority.
-- A value of 0 cancels an in-progress break: all three backends treat it as a
-- cancel. Returns the backend used, for logging.
local function RouteBreakTimer(minutes)
    if BigWigsLoader and SlashCmdList["break"] then
        SlashCmdList["break"](tostring(minutes))
        return "BigWigs"
    end
    if DBM and DBM.CreateBreakTimer then
        DBM:CreateBreakTimer(minutes)
        return "DBM"
    end
    C_PartyInfo.DoCountdown(minutes * 60)
    return "Blizzard"
end

local function SavePosition()
    if not prepFrame then return end
    local point, _, relPoint, x, y = prepFrame:GetPoint()
    db.combatPrepPos = { point = point, relPoint = relPoint, x = x, y = y }
    DevLog("Saved position: " .. point .. " " .. relPoint .. " " .. math.floor(x) .. "," .. math.floor(y))
end

local function RestorePosition(f)
    local pos = db.combatPrepPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -300)
    end
end

local function UpdateButtonTexts()
    if not prepFrame then return end
    local S = LuckyGrabbag.Strings.combatPrep
    if prepFrame.pullTimerBtn then
        prepFrame.pullTimerBtn:SetText(string.format(S.pullTimerFmt, GetActivePullTimer()))
    end
    if prepFrame.breakBtn then
        local mins = db.combatPrepBreakTimer or 5
        prepFrame.breakBtn:SetText(string.format(S.breakTimerFmt, mins))
    end
end

local function UpdateVisibility()
    if not prepFrame then return end
    UpdateButtonTexts()
    if not db.showCombatPrep then
        prepFrame:Hide()
        DevLog("Hidden (feature disabled)")
        return
    end
    if inCombat then
        prepFrame:Hide()
        DevLog("Hidden (in combat)")
        return
    end
    if IsInQualifyingContent() then
        prepFrame:Show()
        DevLog("Shown (in qualifying content)")
    else
        prepFrame:Hide()
        DevLog("Hidden (not grouped in a dungeon, or not raid leader or assist)")
    end
end

local function UpdateLayout()
    if not prepFrame then return end
    local showRC = db.combatPrepReadyCheck
    prepFrame.readyCheckBtn:SetShown(showRC)
    UpdateButtonTexts()

    -- Anchor chain: ready check (optional) → pull timer + cancel → break + cancel
    prepFrame.pullTimerBtn:ClearAllPoints()
    prepFrame.cancelPullBtn:ClearAllPoints()
    if showRC then
        prepFrame.pullTimerBtn:SetPoint("TOPLEFT", prepFrame.readyCheckBtn, "BOTTOMLEFT", 0, -4)
    else
        prepFrame.pullTimerBtn:SetPoint("TOPLEFT", prepFrame, "TOPLEFT", 10, -10)
    end
    prepFrame.cancelPullBtn:SetPoint("LEFT", prepFrame.pullTimerBtn, "RIGHT", 4, 0)
    prepFrame.breakBtn:ClearAllPoints()
    prepFrame.breakBtn:SetPoint("TOPLEFT", prepFrame.pullTimerBtn, "BOTTOMLEFT", 0, -4)
    prepFrame.cancelBreakBtn:ClearAllPoints()
    prepFrame.cancelBreakBtn:SetPoint("LEFT", prepFrame.breakBtn, "RIGHT", 4, 0)

    -- Resize frame to fit visible buttons
    local btnCount = showRC and 3 or 2
    local height = 10 + (btnCount * 28) + ((btnCount - 1) * 4) + 10
    prepFrame:SetSize(120, height)
end

local C = LuckyUI.C  -- shared style guide colors

-- Creates a styled button matching the style guide.
-- variant: "primary" (gold gradient) or "secondary" (dark input).
local function CreateStyledButton(parent, opts)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(opts.width or 100, opts.height or 28)

    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local isPrimary = (opts.variant ~= "secondary")

    -- Normal state colors
    local function SetNormalColors()
        if isPrimary then
            btn:SetBackdropColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3], 1)
            btn:SetBackdropBorderColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3], 1)
        else
            btn:SetBackdropColor(0.05, 0.04, 0.02, 1)  -- bg-input
            btn:SetBackdropBorderColor(0.23, 0.18, 0.10, 1)  -- #3a2e1a
        end
    end

    SetNormalColors()

    -- Label
    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(LuckyUI.BODY_FONT, 12, "")
    label:SetPoint("CENTER", 0, 0)
    if isPrimary then
        label:SetTextColor(C.bgDark[1], C.bgDark[2], C.bgDark[3])
    else
        label:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    end
    btn.label = label

    -- Hover highlight
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
    btn:SetScript("OnLeave", function()
        SetNormalColors()
    end)

    -- Press feedback
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

    -- Convenience wrapper to match UIPanelButtonTemplate API
    function btn:SetText(text)
        self.label:SetText(text)
    end

    return btn
end

-- Small danger-styled "X" button that sits beside a timer button to cancel it.
local function CreateCancelButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(23, 28)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.3, 0.1, 0.1, 1)
    btn:SetBackdropBorderColor(C.danger[1], C.danger[2], C.danger[3], 0.6)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(LuckyUI.BODY_FONT, 12, "")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(LuckyGrabbag.Strings.combatPrep.cancelLabel)
    label:SetTextColor(C.danger[1], C.danger[2], C.danger[3])

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(C.danger[1], C.danger[2], C.danger[3], 0.4)
        btn:SetBackdropBorderColor(C.danger[1], C.danger[2], C.danger[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.3, 0.1, 0.1, 1)
        btn:SetBackdropBorderColor(C.danger[1], C.danger[2], C.danger[3], 0.6)
    end)
    btn:SetScript("OnMouseDown", function()
        btn:SetBackdropColor(0.2, 0.05, 0.05, 1)
        label:SetPoint("CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function()
        btn:SetBackdropColor(0.3, 0.1, 0.1, 1)
        label:SetPoint("CENTER", 0, 0)
    end)

    return btn
end

local function CreatePrepFrame()
    if prepFrame then return end

    local f = CreateFrame("Frame", "LuckyGrabbagCombatPrepFrame", UIParent, "BackdropTemplate")
    f:SetSize(120, 76)
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
    f:SetFrameStrata("LOW")
    f:Hide()

    -- Ready Check button (secondary style)
    local rcBtn = CreateStyledButton(f, { width = 100, height = 28, variant = "secondary" })
    rcBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    rcBtn:SetText(LuckyGrabbag.Strings.combatPrep.readyCheck)
    rcBtn:SetScript("OnClick", function()
        DoReadyCheck()
        DevLog("Ready check initiated")
    end)
    f.readyCheckBtn = rcBtn

    -- Pull Timer button (primary gold style)
    local ptBtn = CreateStyledButton(f, { width = 73, height = 28, variant = "primary" })
    ptBtn:SetText(string.format(LuckyGrabbag.Strings.combatPrep.pullTimerFmt, GetActivePullTimer()))
    ptBtn:SetScript("OnClick", function()
        local seconds = GetActivePullTimer()
        C_PartyInfo.DoCountdown(seconds)
        DevLog("Started pull timer for " .. seconds .. "s")
    end)
    f.pullTimerBtn = ptBtn

    -- Cancel Pull button (danger style)
    local cancelBtn = CreateCancelButton(f)
    cancelBtn:SetScript("OnClick", function()
        C_PartyInfo.DoCountdown(0)
        DevLog("Cancelled pull timer")
    end)
    f.cancelPullBtn = cancelBtn

    -- Long Break button (secondary style)
    local breakMins = db.combatPrepBreakTimer or 5
    local brBtn = CreateStyledButton(f, { width = 73, height = 28, variant = "secondary" })
    brBtn:SetText(string.format(LuckyGrabbag.Strings.combatPrep.breakTimerFmt, breakMins))
    brBtn:SetScript("OnClick", function()
        local mins = db.combatPrepBreakTimer or 5
        local source = RouteBreakTimer(mins)
        DevLog("Started break timer for " .. mins .. "m via " .. source)
    end)
    f.breakBtn = brBtn

    -- Cancel Break button (danger style)
    local cancelBreakBtn = CreateCancelButton(f)
    cancelBreakBtn:SetScript("OnClick", function()
        local source = RouteBreakTimer(0)
        DevLog("Cancelled break timer via " .. source)
    end)
    f.cancelBreakBtn = cancelBreakBtn

    prepFrame = f
    DevLog("Frame created")
end

function LuckyGrabbag.CombatPrep:ApplySetting()
    if not prepFrame then
        if db.showCombatPrep then
            CreatePrepFrame()
            UpdateLayout()
        end
    else
        UpdateLayout()
    end
    UpdateVisibility()
end

-- Every gate UpdateVisibility applies, for /gbdiag.
function LuckyGrabbag.CombatPrep:GetDiagState()
    return {
        shown      = prepFrame and prepFrame:IsShown() or false,
        enabled    = db and db.showCombatPrep or false,
        inCombat   = inCombat,
        qualifying = IsInQualifyingContent(),
    }
end

function LuckyGrabbag.CombatPrep:Init(database)
    db = database
    DevLog("Init called")

    CreatePrepFrame()
    UpdateLayout()

    SLASH_LGBCOMBATPREP1 = "/combatprep"
    SlashCmdList["LGBCOMBATPREP"] = function()
        if not prepFrame then
            CreatePrepFrame()
            UpdateLayout()
        end
        prepFrame:Show()
        DevLog("Force-shown via /combatprep")
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:SetScript("OnEvent", function(_, event)
        DevLog("Event: " .. event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
        end
        UpdateVisibility()
    end)

    C_Timer.After(1, UpdateVisibility)
end
