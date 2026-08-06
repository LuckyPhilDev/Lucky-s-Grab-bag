-- Lucky's Grab-bag: Instance Diagnostic Overlay
-- Shows raw M+/Delve/raid API data to verify tier, level, and difficulty
-- detection. Only visible when devMode is enabled.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.InstanceDiag = {}
local ID = LuckyGrabbag.InstanceDiag

local db
local diagFrame

local DELVE_DIFFICULTY_IDS = {
    [208] = true, [215] = true, [216] = true, [217] = true,
    [218] = true, [219] = true, [220] = true,
}

-- Widget IDs used by the scenario header to display the current delve tier.
-- C_GossipInfo.GetActiveDelveGossip was removed in 12.0.5; this is the replacement.
local DELVE_WIDGET_IDS = { 6183, 6184, 6185 }

local function GetDelveWidgetTier()
    if not (C_UIWidgetManager and C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo) then
        return nil
    end
    for _, widgetID in ipairs(DELVE_WIDGET_IDS) do
        local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
        if info and info.shownState ~= 0 then
            local t = info.tierText
            if type(t) == "number" then t = tostring(t) end
            if type(t) == "string" then
                t = t:gsub("^%s+", ""):gsub("%s+$", "")
                if t ~= "" then return t end
            end
        end
    end
    return nil
end

local function GatherInfo()
    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()

    local mpLevel, mpMapID
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local ok, level, mapID = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if ok and type(level) == "number" then mpLevel = level end
        if ok and type(mapID)  == "number" then mpMapID = mapID  end
    end

    -- CVar written by the difficulty picker; persists across sessions.
    local delveTierCVar = GetCVarNumber and GetCVarNumber("lastSelectedDelvesTier") or nil

    -- Widget-based tier: reads the scenario header widget, works inside an active delve.
    -- C_GossipInfo.GetActiveDelveGossip was removed in patch 12.0.5.
    local delveWidgetTier = GetDelveWidgetTier()

    -- Difficulty display flags, the same signals BonusRoll uses to classify a
    -- raid difficulty that isn't in its explicit ID table.
    local diffIsHeroic, diffDisplayHeroic, diffDisplayMythic
    if difficultyID and difficultyID > 0 then
        local _, _, isHeroic, _, displayHeroic, displayMythic = GetDifficultyInfo(difficultyID)
        diffIsHeroic, diffDisplayHeroic, diffDisplayMythic = isHeroic, displayHeroic, displayMythic
    end

    return {
        name           = name,
        instanceType   = instanceType,
        difficultyID   = difficultyID,
        difficultyName = difficultyName,
        mpLevel        = mpLevel,
        mpMapID        = mpMapID,
        delveTierCVar  = delveTierCVar,
        delveWidgetTier = delveWidgetTier,
        diffIsHeroic      = diffIsHeroic,
        diffDisplayHeroic = diffDisplayHeroic,
        diffDisplayMythic = diffDisplayMythic,
    }
end

local function IsRelevantInstance(info)
    if info.instanceType == "raid" then return true end
    if info.difficultyID == 8 then return true end
    if info.mpLevel and info.mpLevel > 0 then return true end
    if DELVE_DIFFICULTY_IDS[info.difficultyID] then return true end
    return false
end

-- Small floating popup with an auto-focused EditBox. Hides on focus loss or Escape.
local copyPopup, copyEdit
local function BuildCopyPopup()
    local p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    p:SetSize(280, 28)
    p:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    p:SetFrameStrata("DIALOG")
    p:Hide()

    local e = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    e:SetSize(260, 18)
    e:SetPoint("CENTER")
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed",  function() p:Hide() end)
    e:SetScript("OnEditFocusLost",  function() p:Hide() end)

    copyPopup = p
    copyEdit  = e
end

local function ShowCopyPopup(text, anchor)
    local captured = text or ""
    copyPopup:ClearAllPoints()
    copyPopup:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    copyPopup:Show()
    C_Timer.After(0, function()
        copyEdit:SetText(captured)
        copyEdit:SetFocus()
        copyEdit:HighlightText()
    end)
end

local function Refresh()
    if not db or not db.devMode then
        diagFrame:Hide()
        return
    end

    local info = GatherInfo()
    if not IsRelevantInstance(info) then
        diagFrame:Hide()
        return
    end

    local G = "|cffffcc00"
    local M = "|cff44aaff"
    local D = "|cff44ffaa"
    local R = "|r"

    local lines      = { G .. "Instance Diag" .. R }
    local plainParts = { "Instance Diag" }

    local function add(label, value)
        local v = tostring(value)
        lines[#lines+1]           = label .. v
        plainParts[#plainParts+1] = label .. v
    end
    local function addC(colour, label, value)
        local v = tostring(value)
        lines[#lines+1]           = colour .. label .. R .. v
        plainParts[#plainParts+1] = label .. v
    end

    add("Type:     ", info.instanceType)
    add("DiffID:   ", info.difficultyID)
    add("DiffName: ", info.difficultyName)

    if info.mpLevel then addC(M, "M+ Level: ", info.mpLevel) end
    if info.mpMapID then addC(M, "M+ MapID: ", info.mpMapID) end
    if info.instanceType == "raid" then
        addC(M, "Mythic flag:  ", info.diffDisplayMythic and true or false)
        addC(M, "Heroic flag:  ", (info.diffIsHeroic or info.diffDisplayHeroic) and true or false)
    end
    addC(D, "Delve CVar:   ", info.delveTierCVar   ~= nil and info.delveTierCVar   or "n/a")
    addC(D, "Delve Widget: ", info.delveWidgetTier  ~= nil and info.delveWidgetTier or "n/a")

    diagFrame.plainText = table.concat(plainParts, " | ")
    diagFrame.text:SetText(table.concat(lines, "\n"))

    local textH = diagFrame.text:GetStringHeight()
    diagFrame:SetHeight(textH + 30)

    diagFrame:Show()
end

local function BuildFrame()
    local f = CreateFrame("Frame", "LGB_InstanceDiag", UIParent, "BackdropTemplate")
    f:SetWidth(220)
    f:SetHeight(140)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -200)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 8, edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -6)
    text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    f.text = text

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(60, 18)
    btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    btn:SetText("Copy")
    btn:SetScript("OnClick", function(self)
        ShowCopyPopup(f.plainText or "", self)
    end)

    f:Hide()
    return f
end

local DIAG_FEATURES = { "PowerInfusion", "CombatPrep" }

local function StateLine(state)
    local parts = {}
    for key, value in pairs(state) do
        parts[#parts + 1] = key .. "=" .. tostring(value)
    end
    table.sort(parts)
    return table.concat(parts, " ")
end

-- Prints where you are and what each visibility gate makes of it. Run it in
-- the content that is misbehaving, then again after "/gbdiag recheck", which
-- re-runs the gates: if a window disappears only on the recheck, the feature
-- is missing an event for that content rather than misreading it.
local function PrintDiag(recheck)
    local name, instanceType, difficultyID, difficultyName, maxPlayers,
        _, _, instanceMapID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
    local inInstance, inInstanceType = IsInInstance()

    print(LuckyGrabbag.PREFIX .. " diag" .. (recheck and " (after recheck)" or ""))
    print(("  instance: name=%s type=%s diffID=%s diffName=%s mapID=%s maxPlayers=%s groupSize=%s lfgID=%s")
        :format(tostring(name), tostring(instanceType), tostring(difficultyID), tostring(difficultyName),
            tostring(instanceMapID), tostring(maxPlayers), tostring(instanceGroupSize), tostring(lfgDungeonID)))
    print(("  IsInInstance: %s / %s | zone=%s / %s | uiMapID=%s")
        :format(tostring(inInstance), tostring(inInstanceType), tostring(GetRealZoneText()),
            tostring(GetSubZoneText()), tostring(C_Map.GetBestMapForUnit("player"))))
    print(("  group: inGroup=%s inRaid=%s party=%d raid=%d")
        :format(tostring(IsInGroup()), tostring(IsInRaid()), GetNumSubgroupMembers(), GetNumGroupMembers()))

    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local scenario = C_ScenarioInfo.GetScenarioInfo()
        if scenario then
            print(("  scenario: name=%s id=%s type=%s")
                :format(tostring(scenario.name), tostring(scenario.scenarioID), tostring(scenario.type)))
        end
    end

    for _, feature in ipairs(DIAG_FEATURES) do
        local module = LuckyGrabbag[feature]
        if module and module.GetDiagState then
            print("  " .. feature .. ": " .. StateLine(module:GetDiagState()))
        end
    end
end

function ID:Init(database)
    db = database

    SLASH_LGBDIAG1 = "/gbdiag"
    SlashCmdList["LGBDIAG"] = function(msg)
        if (msg or ""):lower():match("recheck") then
            for _, feature in ipairs(DIAG_FEATURES) do
                local module = LuckyGrabbag[feature]
                if module and module.ApplySetting then module:ApplySetting() end
            end
            PrintDiag(true)
            return
        end
        PrintDiag(false)
    end

    BuildCopyPopup()
    diagFrame = BuildFrame()

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("CHALLENGE_MODE_START")
    events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    events:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE")
    events:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    events:SetScript("OnEvent", function(_, event)
        Refresh()
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            C_Timer.After(1, Refresh)
        end
    end)
end

function ID:Refresh()
    Refresh()
end
