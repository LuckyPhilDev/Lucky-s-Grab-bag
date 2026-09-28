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

local PING_TARGET_CVAR = "pingTarget"
local PING_TARGET_COUNT = 3

local function GetPingTarget()
    return tonumber(C_CVar.GetCVar(PING_TARGET_CVAR)) or Enum.PingTargetOption.All
end

local PING_TARGET_ICONS = { [0] = "radar", [1] = "map-pin", [2] = "crosshair" }

-- Without a boss mod the break falls back to a Blizzard countdown, and no pull runs this long.
local PULL_MAX_SECONDS = 60

local IsSecret = issecretvalue or function() return false end

local Rich = LuckySettings.Rich
local R = Rich.Theme
local TILE, ICON, GAP, PAD = 36, 16, 4, 5
local LOCK_TAB, LOCK_ICON = 18, 12

local function Faded(color, alpha)
    return { color[1], color[2], color[3], alpha }
end

local FRAME_EDGE = Faded(R.accent, 0.35)
local ICON_HOVER = { 1, 0.85, 0.45 }
local STYLES = {
    normal  = { bg = R.bg3, edge = R.border2, tint = R.accentLight, hoverEdge = R.accentLight, hoverTint = ICON_HOVER },
    primary = { bg = Faded(R.accent, 0.22), edge = Faded(R.accent, 0.6), tint = R.accentLight,
                hoverEdge = R.accentLight, hoverTint = ICON_HOVER },
    cancel  = { bg = Faded(R.warn, 0.2), edge = Faded(R.warn, 0.6), tint = R.warn,
                hoverEdge = R.warn, hoverTint = { 1, 0.55, 0.55 } },
}

local pullEndsAt

local function IsPullCounting()
    return (pullEndsAt or 0) > GetTime()
end

-- Boss mods save a running break so they can resume it after a reload, and
-- they track breaks other people start too. Epoch seconds, from time().
local function BreakEndsAt()
    if BigWigsLoader and SlashCmdList["break"] then
        local saved = BigWigs3DB and BigWigs3DB.breakTime
        return saved and saved[1] + saved[2]
    end
    if DBM and DBM.CreateBreakTimer then
        local saved = DBM.Options and DBM.Options.RestoreSettingBreakTimer
        local seconds, startedAt = (saved or ""):match("^([%d%.]+)/(%d+)")
        return seconds and tonumber(startedAt) + tonumber(seconds)
    end
    return db.combatPrepBreakEndsAt
end

local function IsBreakCounting()
    return (BreakEndsAt() or 0) > time()
end

local function IconPath(name)
    return "Interface\\AddOns\\Luckys_Grab_Bag\\media\\icons\\" .. name .. ".tga"
end

local function SavePosition()
    if not prepFrame then return end
    local point, _, relPoint, x, y = prepFrame:GetPoint()
    db.combatPrepPos = { point = point, relPoint = relPoint, x = x, y = y }
    DevLog("Saved position: " .. point .. " " .. relPoint .. " " .. math.floor(x) .. "," .. math.floor(y))
end

local function StartMove()
    if not db.combatPrepLocked then prepFrame:StartMoving() end
end

local function StopMove()
    prepFrame:StopMovingOrSizing()
    SavePosition()
end

local function RestorePosition(f)
    local pos = db.combatPrepPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -300)
    end
end

local function PaintTile(tile)
    local style = tile.style
    local edge = tile.hovered and style.hoverEdge or style.edge
    local tint = tile.hovered and style.hoverTint or style.tint
    tile.bg:SetColorTexture(style.bg[1], style.bg[2], style.bg[3], style.bg[4] or 1)
    for _, rule in ipairs(tile.edges) do
        rule:SetColorTexture(edge[1], edge[2], edge[3], edge[4] or 1)
    end
    tile.icon:SetVertexColor(tint[1], tint[2], tint[3])
end

local function ShowTooltip(tile)
    GameTooltip:SetOwner(tile, "ANCHOR_BOTTOM")
    tile.tooltip(GameTooltip)
    if not db.combatPrepLocked then
        GameTooltip:AddLine(LuckyGrabbag.Strings.combatPrep.moveHint, R.textDim[1], R.textDim[2], R.textDim[3])
    end
    GameTooltip:Show()
end

local function UpdateLockTab()
    local tab = prepFrame.lockTab
    tab:SetShown(prepFrame:IsMouseOver() or tab:IsMouseOver())
end

local function PaintLockTab(tab)
    local tint = tab.hovered and ICON_HOVER or (db.combatPrepLocked and R.accentLight or R.textDim)
    tab.icon:SetTexture(IconPath(db.combatPrepLocked and "lock" or "lock-open"))
    tab.icon:SetVertexColor(tint[1], tint[2], tint[3])
end

local function RefreshTimerTile(tile, counting, caption)
    local changed = tile.counting ~= counting
    tile.counting = counting
    tile.style = counting and STYLES.cancel or tile.baseStyle
    tile:SetIcon(counting and LuckyIcon("x") or tile.baseIcon)
    tile.caption:SetText(counting and LuckyGrabbag.Strings.combatPrep.cancelCaption or caption)
    PaintTile(tile)
    return changed
end

local function RefreshTiles()
    if not prepFrame then return end
    local S = LuckyGrabbag.Strings.combatPrep
    local changed = RefreshTimerTile(prepFrame.pullTimerBtn, IsPullCounting(),
        string.format(S.pullTimerValue, GetActivePullTimer()))
    changed = RefreshTimerTile(prepFrame.breakBtn, IsBreakCounting(),
        string.format(S.breakTimerValue, db.combatPrepBreakTimer or 5)) or changed

    local pingTarget = GetPingTarget()
    changed = changed or prepFrame.pingTargetBtn.pingTarget ~= pingTarget
    prepFrame.pingTargetBtn.pingTarget = pingTarget
    prepFrame.pingTargetBtn.caption:SetText(S.pingTargets[pingTarget] or "")
    prepFrame.pingTargetBtn:SetIcon(IconPath(PING_TARGET_ICONS[pingTarget] or PING_TARGET_ICONS[0]))

    local owner = GameTooltip:GetOwner()
    if changed and owner and owner.hovered and owner:GetParent() == prepFrame then ShowTooltip(owner) end
end

-- The Assign Tanks button is secure, which locks the whole window in combat.
local function UpdateVisibility()
    if not prepFrame or InCombatLockdown() then return end
    RefreshTiles()
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
    if not prepFrame or InCombatLockdown() then return end
    prepFrame.readyCheckBtn:SetShown(db.combatPrepReadyCheck)
    prepFrame.pingTargetBtn:SetShown(db.combatPrepPingTarget)
    prepFrame.assignTanksBtn:SetShown(db.combatPrepAssignTanks and IsInRaid())
    RefreshTiles()

    local divider = prepFrame.divider
    divider:Hide()
    local x = PAD
    for _, group in ipairs(prepFrame.tileGroups) do
        local groupStarted = false
        for _, tile in ipairs(group) do
            if tile:IsShown() then
                if not groupStarted and x > PAD then
                    divider:ClearAllPoints()
                    divider:SetPoint("LEFT", prepFrame, "LEFT", x, 0)
                    divider:Show()
                    x = x + 1 + GAP
                end
                groupStarted = true
                tile:ClearAllPoints()
                tile:SetPoint("LEFT", prepFrame, "LEFT", x, 0)
                x = x + TILE + GAP
            end
        end
    end
    prepFrame:SetSize(x - GAP + PAD, TILE + PAD * 2)
end

-- opts: icon, caption, tooltip(GameTooltip), primary, template.
local function CreateTile(parent, opts)
    local tile = CreateFrame("Button", nil, parent, opts.template)
    tile:SetSize(TILE, TILE)
    tile.tooltip = opts.tooltip
    tile.baseStyle = opts.primary and STYLES.primary or STYLES.normal
    tile.baseIcon = IconPath(opts.icon)
    tile.style = tile.baseStyle

    tile.bg = Rich.FillBg(tile, tile.style.bg)
    tile.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        tile.edges[#tile.edges + 1] = Rich.EdgeRule(tile, side, tile.style.edge)
    end

    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetSize(ICON, ICON)
    tile.icon:SetPoint("TOP", 0, -5)
    function tile:SetIcon(path) self.icon:SetTexture(path) end
    tile:SetIcon(tile.baseIcon)

    tile.caption = tile:CreateFontString(nil, "OVERLAY")
    tile.caption:SetFont(Rich.Font, 9, "")
    tile.caption:SetShadowOffset(1, -1)
    tile.caption:SetPoint("BOTTOM", 0, 4)
    tile.caption:SetTextColor(R.text[1], R.text[2], R.text[3])
    tile.caption:SetText(opts.caption)
    PaintTile(tile)

    tile:SetScript("OnEnter", function(self)
        self.hovered = true
        PaintTile(self)
        ShowTooltip(self)
        UpdateLockTab()
    end)
    tile:SetScript("OnLeave", function(self)
        self.hovered = false
        PaintTile(self)
        GameTooltip_Hide()
        UpdateLockTab()
    end)
    tile:SetScript("OnMouseDown", function(self) self.icon:SetPoint("TOP", 0, -6) end)
    tile:SetScript("OnMouseUp", function(self) self.icon:SetPoint("TOP", 0, -5) end)

    tile:RegisterForDrag("RightButton")
    tile:SetScript("OnDragStart", StartMove)
    tile:SetScript("OnDragStop", StopMove)
    return tile
end

local function AddTitle(tooltip, text)
    tooltip:SetText(text, R.accentLight[1], R.accentLight[2], R.accentLight[3])
end

local function AddBody(tooltip, text)
    tooltip:AddLine(text, R.text[1], R.text[2], R.text[3], true)
end

local function CreatePrepFrame()
    if prepFrame then return end
    local S = LuckyGrabbag.Strings.combatPrep

    local f = CreateFrame("Frame", "LuckyGrabbagCombatPrepFrame", UIParent)
    RestorePosition(f)
    Rich.FillBg(f, Faded(R.bg, 0.94))
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        Rich.EdgeRule(f, side, FRAME_EDGE)
    end
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("RightButton")
    f:SetScript("OnDragStart", StartMove)
    f:SetScript("OnDragStop", StopMove)
    f:SetScript("OnEnter", UpdateLockTab)
    f:SetScript("OnLeave", UpdateLockTab)
    f:SetClampedToScreen(true)
    f:SetClampRectInsets(0, 0, LOCK_TAB, 0)
    f:SetFrameStrata("LOW")
    f:Hide()
    -- Boss mods change their break state without an event, and countdowns expire on their own.
    f:SetScript("OnShow", function(self) self.ticker = C_Timer.NewTicker(1, RefreshTiles) end)
    f:SetScript("OnHide", function(self)
        if self.ticker then self.ticker:Cancel() end
        self.lockTab:Hide()
    end)

    local tab = CreateFrame("Button", nil, f)
    tab:SetSize(LOCK_TAB, LOCK_TAB)
    tab:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT")
    tab:Hide()
    Rich.FillBg(tab, Faded(R.bg, 0.94))
    for _, side in ipairs({ "TOP", "LEFT", "RIGHT" }) do
        Rich.EdgeRule(tab, side, FRAME_EDGE)
    end
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(LOCK_ICON, LOCK_ICON)
    tab.icon:SetPoint("CENTER")
    PaintLockTab(tab)
    tab:SetScript("OnEnter", function(self)
        self.hovered = true
        PaintLockTab(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        AddTitle(GameTooltip, db.combatPrepLocked and S.unlock or S.lock)
        AddBody(GameTooltip, db.combatPrepLocked and S.unlockDesc or S.lockDesc)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function(self)
        self.hovered = false
        PaintLockTab(self)
        GameTooltip_Hide()
        UpdateLockTab()
    end)
    tab:SetScript("OnClick", function(self)
        db.combatPrepLocked = not db.combatPrepLocked
        DevLog("Position " .. (db.combatPrepLocked and "locked" or "unlocked"))
        self:GetScript("OnEnter")(self)
    end)
    f.lockTab = tab

    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetSize(1, TILE - 8)
    f.divider:SetColorTexture(R.border2[1], R.border2[2], R.border2[3], R.border2[4])

    f.readyCheckBtn = CreateTile(f, {
        icon    = "circle-check",
        caption = S.readyCheckCaption,
        tooltip = function(tooltip)
            AddTitle(tooltip, S.readyCheck)
            AddBody(tooltip, S.readyCheckDesc)
        end,
    })
    f.readyCheckBtn:SetScript("OnClick", function()
        DoReadyCheck()
        DevLog("Ready check initiated")
    end)

    f.pullTimerBtn = CreateTile(f, {
        icon    = "timer",
        primary = true,
        tooltip = function(tooltip)
            if IsPullCounting() then
                AddTitle(tooltip, S.cancelPull)
                AddBody(tooltip, S.cancelPullDesc)
            else
                AddTitle(tooltip, S.pullTimer)
                AddBody(tooltip, string.format(S.pullTimerDesc, GetActivePullTimer()))
            end
        end,
    })
    f.pullTimerBtn:SetScript("OnClick", function()
        local seconds = IsPullCounting() and 0 or GetActivePullTimer()
        C_PartyInfo.DoCountdown(seconds)
        DevLog("Pull timer set to " .. seconds .. "s")
    end)

    f.breakBtn = CreateTile(f, {
        icon    = "coffee",
        tooltip = function(tooltip)
            if IsBreakCounting() then
                AddTitle(tooltip, S.cancelBreak)
                AddBody(tooltip, S.cancelBreakDesc)
            else
                AddTitle(tooltip, S.breakTimer)
                AddBody(tooltip, string.format(S.breakTimerDesc, db.combatPrepBreakTimer or 5))
            end
        end,
    })
    f.breakBtn:SetScript("OnClick", function()
        local mins = IsBreakCounting() and 0 or (db.combatPrepBreakTimer or 5)
        local source = RouteBreakTimer(mins)
        DevLog("Break timer set to " .. mins .. "m via " .. source)
    end)

    f.pingTargetBtn = CreateTile(f, {
        icon    = PING_TARGET_ICONS[0],
        tooltip = function(tooltip)
            AddTitle(tooltip, string.format(S.pingTargetFmt, S.pingTargets[GetPingTarget()] or ""))
            AddBody(tooltip, S.pingTargetDesc)
        end,
    })
    f.pingTargetBtn:SetScript("OnClick", function()
        local nextTarget = (GetPingTarget() + 1) % PING_TARGET_COUNT
        C_CVar.SetCVar(PING_TARGET_CVAR, nextTarget)
        RefreshTiles()
        DevLog("Ping target set to " .. nextTarget)
    end)

    f.assignTanksBtn = CreateTile(f, {
        icon     = "shield-user",
        caption  = S.assignTanksCaption,
        template = "SecureActionButtonTemplate",
        tooltip  = function(tooltip)
            AddTitle(tooltip, S.assignTanks)
            AddBody(tooltip, S.assignTanksDesc)
        end,
    })
    f.assignTanksBtn:SetAttribute("type", "macro")
    f.assignTanksBtn:SetAttribute("useOnKeyDown", false)
    f.assignTanksBtn:RegisterForClicks("LeftButtonUp")
    f.assignTanksBtn:SetScript("PreClick", function(self)
        local names = LuckyGrabbag.AssignTanks.UnassignedTanks()
        self:SetAttribute("macrotext", LuckyGrabbag.AssignTanks.Macro(names))
        local T = LuckyGrabbag.Strings.assignTanks
        local msg = #names > 0 and string.format(T.assigned, table.concat(names, ", ")) or T.none
        print(LuckyGrabbag.PREFIX .. " " .. msg)
    end)

    f.tileGroups = {
        { f.readyCheckBtn, f.pullTimerBtn, f.breakBtn },
        { f.pingTargetBtn, f.assignTanksBtn },
    }

    prepFrame = f
    DevLog("Frame created")
end

-- Blizzard runs one countdown at a time, so a new one replaces whichever was running.
local function OnCountdownStarted(timeRemaining, totalTime)
    if IsSecret(timeRemaining) or IsSecret(totalTime) then return end
    local isBreak = totalTime > PULL_MAX_SECONDS
    pullEndsAt = not isBreak and GetTime() + timeRemaining or nil
    db.combatPrepBreakEndsAt = isBreak and time() + timeRemaining or nil
    RefreshTiles()
end

local function OnCountdownCancelled()
    pullEndsAt = nil
    db.combatPrepBreakEndsAt = nil
    RefreshTiles()
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
        if InCombatLockdown() then return end
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
    eventFrame:RegisterEvent("CVAR_UPDATE")
    eventFrame:RegisterEvent("START_PLAYER_COUNTDOWN")
    eventFrame:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CVAR_UPDATE" then
            if ... == PING_TARGET_CVAR then RefreshTiles() end
            return
        elseif event == "START_PLAYER_COUNTDOWN" then
            local _, timeRemaining, totalTime = ...
            OnCountdownStarted(timeRemaining, totalTime)
            return
        elseif event == "CANCEL_PLAYER_COUNTDOWN" then
            OnCountdownCancelled()
            return
        end
        DevLog("Event: %s", event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
        end
        UpdateLayout()
        UpdateVisibility()
    end)

    C_Timer.After(1, UpdateVisibility)
end
