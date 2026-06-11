-- Lucky's Grab-bag: Power Infusion target picker for priests
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.PowerInfusion = {}

local POWER_INFUSION_SPELL_ID = 10060
local MACRO_NAME = "PI"
local MACRO_ICON = "INV_Misc_QuestionMark"
local CHECK_MARKUP = "|A:common-icon-checkmark:12:12|a"
local STAR_MARKUP = "|A:auctionhouse-icon-favorite:12:12|a"

local ROWS_PER_COLUMN = 10
local ROW_WIDTH       = 140
local ROW_HEIGHT      = 20
local COL_GAP         = 4
local PAD             = 10
local HEADER_HEIGHT   = 34  -- title + current-target line, below the top padding

-- Tank/healer picks are unusual, so mark them with a role icon; DPS rows stay clean.
local ROLE_ICON = {
    TANK   = INLINE_TANK_ICON and (INLINE_TANK_ICON .. " ") or "",
    HEALER = INLINE_HEALER_ICON and (INLINE_HEALER_ICON .. " ") or "",
}

local ROLE_ORDER = { DAMAGER = 1, NONE = 2, HEALER = 3, TANK = 4 }

local db
local charDB
local pickerFrame
local rowPool = {}
local inCombat = false
local mockCandidates  -- dev tool: fake roster from /pipicker mock
local dismissed = false  -- X button; resets on new boss or new M+ key
local Refresh

local C = LuckyUI.C
local PIData = LuckyGrabbag.PowerInfusionData

-- Spec inspection: one pending request at a time, throttled, only while the
-- picker is visible and out of combat. Results are cached by GUID.
local specCache = {}      -- guid -> specID
local inspectQueue = {}   -- guids awaiting inspection
local inspectGuid         -- guid of our in-flight NotifyInspect, if any
local inspectTimer        -- timeout timer for the in-flight request
local lastInspect = 0
local pumpScheduled = false
local INSPECT_INTERVAL = 1.5

local function DevLog(msg)
    LuckyGrabbag.DevLog("PowerInfusion", msg)
end

local function KnowsPowerInfusion()
    return IsPlayerSpell(POWER_INFUSION_SPELL_ID)
end

local function SortCandidates(list)
    table.sort(list, function(a, b)
        local ga, gb = a.rating or 0, b.rating or 0
        if ga ~= gb then return ga > gb end
        local ra, rb = ROLE_ORDER[a.role] or 5, ROLE_ORDER[b.role] or 5
        if ra ~= rb then return ra < rb end
        return a.display < b.display
    end)
end

-- Group members eligible for Power Infusion. Excludes the player; raids are
-- filtered to damage dealers (plus unassigned roles, common in manual groups).
local function GetCandidates()
    if mockCandidates then return mockCandidates end
    local list = {}
    local isRaid = IsInRaid()
    local count = isRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i = 1, count do
        local unit = (isRaid and "raid" or "party") .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local role = UnitGroupRolesAssigned(unit)
            if not isRaid or role == "DAMAGER" or role == "NONE" then
                local name, realm = UnitFullName(unit)
                if name then
                    local _, class = UnitClass(unit)
                    local guid = UnitGUID(unit)
                    local specID = guid and specCache[guid]
                    table.insert(list, {
                        display = name,
                        full    = (realm and realm ~= "") and (name .. "-" .. realm) or name,
                        class   = class,
                        role    = role,
                        guid    = guid,
                        specID  = specID,
                        rating  = specID and PIData.RATING[specID] or 0,
                    })
                end
            end
        end
    end
    SortCandidates(list)
    return list
end

local function UnitForGuid(guid)
    local isRaid = IsInRaid()
    local count = isRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
    local prefix = isRaid and "raid" or "party"
    for i = 1, count do
        local unit = prefix .. i
        if UnitGUID(unit) == guid then return unit end
    end
end

-- Works through the inspect queue one request at a time. The server only
-- honors one NotifyInspect at once, so each request waits for INSPECT_READY
-- (or a 4s timeout) before the next is sent.
local function PumpInspect()
    pumpScheduled = false
    if inspectGuid then return end
    if inCombat then return end
    if not pickerFrame or not pickerFrame:IsShown() then return end
    local now = GetTime()
    local wait = (lastInspect + INSPECT_INTERVAL) - now
    if wait > 0 then
        if not pumpScheduled then
            pumpScheduled = true
            C_Timer.After(wait, PumpInspect)
        end
        return
    end
    while #inspectQueue > 0 do
        local guid = table.remove(inspectQueue, 1)
        if not specCache[guid] then
            local unit = UnitForGuid(guid)
            if unit and CanInspect(unit) then
                inspectGuid = guid
                lastInspect = now
                NotifyInspect(unit)
                inspectTimer = C_Timer.NewTimer(4, function()
                    inspectTimer = nil
                    inspectGuid = nil
                    PumpInspect()
                end)
                return
            end
        end
    end
end

local function QueueInspects(list)
    if mockCandidates or inCombat then return end
    wipe(inspectQueue)
    local needed = false
    for _, c in ipairs(list) do
        if c.guid and not specCache[c.guid] then
            table.insert(inspectQueue, c.guid)
            needed = true
        end
    end
    if needed then PumpInspect() end
end

local function HandleInspectReady(guid)
    if not guid then return end
    local unit = UnitForGuid(guid)
    if unit then
        local specID = GetInspectSpecialization(unit)
        if specID and specID > 0 then specCache[guid] = specID end
    end
    if guid == inspectGuid then
        if inspectTimer then inspectTimer:Cancel(); inspectTimer = nil end
        inspectGuid = nil
        ClearInspectPlayer()
        if pickerFrame and pickerFrame:IsShown() then
            Refresh()
            C_Timer.After(1, PumpInspect)
        end
    elseif unit and pickerFrame and pickerFrame:IsShown() then
        -- Another addon's inspect; take the free data.
        Refresh()
    end
end

-- Dev tool: fake roster so the picker can be tested outside a group.
-- Toggle with "/pipicker mock"; "/pipicker mock 25" sets the roster size.
local MOCK_CLASSES = {
    "MAGE", "HUNTER", "ROGUE", "WARLOCK", "DRUID", "SHAMAN", "WARRIOR",
    "PALADIN", "DEATHKNIGHT", "DEMONHUNTER", "EVOKER", "MONK", "PRIEST",
}
local MOCK_NAMES = {
    "Sparklefist", "Grimjaw", "Moonpetal", "Vexalia", "Thornbark",
    "Ashenvale", "Quickdraw", "Nightbloom", "Stormcaller", "Emberlyn",
    "Frostwhisper", "Ironbelly", "Suntouched", "Voidstep", "Brambleroot",
}
-- One spec per mock class, spread across the rating tiers so the star,
-- tooltip, and sort order all get exercised.
local MOCK_SPECS = {
    MAGE = 63, HUNTER = 254, ROGUE = 261, WARLOCK = 265, DRUID = 102,
    SHAMAN = 262, WARRIOR = 71, PALADIN = 70, DEATHKNIGHT = 251,
    DEMONHUNTER = 1480, EVOKER = 1467, MONK = 269, PRIEST = 258,
}

local function BuildMockCandidates(count)
    local list = {}
    for i = 1, count do
        local name = MOCK_NAMES[((i - 1) % #MOCK_NAMES) + 1]
        if i > #MOCK_NAMES then
            name = name .. math.floor((i - 1) / #MOCK_NAMES + 1)
        end
        -- First three get off-meta roles to exercise the icons and sort order.
        local role = "DAMAGER"
        if i == 1 then role = "TANK"
        elseif i == 2 then role = "HEALER"
        elseif i == 3 then role = "NONE" end
        local class = MOCK_CLASSES[((i - 1) % #MOCK_CLASSES) + 1]
        local specID = MOCK_SPECS[class]
        table.insert(list, {
            display = name,
            full    = name,
            class   = class,
            role    = role,
            specID  = specID,
            rating  = specID and PIData.RATING[specID] or 0,
        })
    end
    SortCandidates(list)
    return list
end

-- Writes the PI macro to cast on the given Name or Name-Realm. Creates the
-- per-character macro on first use and puts it on the cursor for bar placement.
local function WriteMacro(targetFull)
    local S = LuckyGrabbag.Strings
    local prefix = S.addon.prefix

    if InCombatLockdown() then
        print(prefix .. " " .. S.powerInfusion.inCombat)
        return false
    end

    local spellName = C_Spell.GetSpellName(POWER_INFUSION_SPELL_ID)
    if not spellName then
        DevLog("Spell name unavailable for spell ID " .. POWER_INFUSION_SPELL_ID)
        return false
    end

    local body = "#showtooltip " .. spellName .. "\n/cast [@" .. targetFull .. "] " .. spellName

    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, body)
        return true
    end

    idx = CreateMacro(MACRO_NAME, MACRO_ICON, body, true)
    if not idx or idx == 0 then
        print(prefix .. " " .. S.powerInfusion.slotsFull)
        return false
    end
    PickupMacro(MACRO_NAME)
    print(prefix .. " " .. S.powerInfusion.macroCreated)
    return true
end

local function SetTarget(candidate)
    local S = LuckyGrabbag.Strings
    if WriteMacro(candidate.full) then
        charDB.piTarget = candidate.full
        print(S.addon.prefix .. " " .. string.format(S.powerInfusion.targetSet, candidate.display))
        DevLog("Macro now targets " .. candidate.full)
    end
    Refresh()
end

local function SavePosition()
    if not pickerFrame then return end
    local point, _, relPoint, x, y = pickerFrame:GetPoint()
    db.piPickerPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition(f)
    local pos = db.piPickerPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
    end
end

local function AcquireRow(i)
    if rowPool[i] then return rowPool[i] end

    local row = CreateFrame("Button", nil, pickerFrame)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])

    local text = row:CreateFontString(nil, "OVERLAY")
    text:SetFont(LuckyUI.BODY_FONT, 12, "")
    text:SetPoint("LEFT", 6, 0)
    text:SetPoint("RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text

    row:SetScript("OnClick", function(self)
        if self.candidate then SetTarget(self.candidate) end
    end)

    row:SetScript("OnEnter", function(self)
        local c = self.candidate
        if not c or not c.rating or c.rating == 0 then return end
        local S = LuckyGrabbag.Strings.powerInfusion
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local _, specName = GetSpecializationInfoByID(c.specID)
        GameTooltip:SetText(specName or "", 1, 1, 1)
        if c.rating == PIData.STRONG then
            GameTooltip:AddLine(S.recStrong, 0.1, 1, 0.1)
        else
            GameTooltip:AddLine(S.recGood, 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rowPool[i] = row
    return row
end

function Refresh()
    if not pickerFrame then return end
    local S = LuckyGrabbag.Strings.powerInfusion
    local list = GetCandidates()
    local target = charDB.piTarget

    if not mockCandidates then QueueInspects(list) end

    -- Current-target line: class colored while they're in the group, muted otherwise.
    local targetText
    if target then
        local display = target:match("^([^%-]+)") or target
        local colored = LuckyUI.WC.textMuted .. display .. LuckyUI.WC.reset
        for _, candidate in ipairs(list) do
            if candidate.full == target then
                local cc = RAID_CLASS_COLORS[candidate.class]
                if cc then colored = "|c" .. cc.colorStr .. display .. "|r" end
                break
            end
        end
        targetText = string.format(S.currentFmt, colored)
    else
        targetText = string.format(S.currentFmt, LuckyUI.WC.textMuted .. S.noTarget .. LuckyUI.WC.reset)
    end
    pickerFrame.currentLine:SetText(targetText)

    for _, row in ipairs(rowPool) do row:Hide() end

    local n = #list
    if n == 0 then
        pickerFrame.emptyLabel:Show()
        pickerFrame:SetSize(PAD * 2 + 220, PAD + HEADER_HEIGHT + 16 + PAD)
        return
    end
    pickerFrame.emptyLabel:Hide()

    for i, candidate in ipairs(list) do
        local row = AcquireRow(i)
        local col = math.floor((i - 1) / ROWS_PER_COLUMN)
        local rowInCol = (i - 1) % ROWS_PER_COLUMN
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT",
            PAD + col * (ROW_WIDTH + COL_GAP),
            -(PAD + HEADER_HEIGHT + rowInCol * ROW_HEIGHT))

        local selected = (candidate.full == target)
        local icon = ROLE_ICON[candidate.role] or ""
        local star = (candidate.rating == PIData.STRONG) and (" " .. STAR_MARKUP) or ""
        row.text:SetText(icon .. candidate.display .. star .. (selected and (" " .. CHECK_MARKUP) or ""))
        local cc = RAID_CLASS_COLORS[candidate.class]
        if cc then
            row.text:SetTextColor(cc.r, cc.g, cc.b)
        else
            row.text:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
        end
        row.candidate = candidate
        row:Show()
    end

    local cols = math.ceil(n / ROWS_PER_COLUMN)
    local rowsPerCol = math.min(n, ROWS_PER_COLUMN)
    pickerFrame:SetSize(
        PAD * 2 + cols * ROW_WIDTH + (cols - 1) * COL_GAP,
        PAD + HEADER_HEIGHT + rowsPerCol * ROW_HEIGHT + PAD)
end

local function UpdateVisibility()
    if not pickerFrame then return end
    if not db.showPIPicker then
        pickerFrame:Hide()
        DevLog("Hidden (feature disabled)")
        return
    end
    if inCombat then
        pickerFrame:Hide()
        DevLog("Hidden (in combat)")
        return
    end
    if dismissed then
        pickerFrame:Hide()
        DevLog("Hidden (dismissed)")
        return
    end
    if not mockCandidates and not IsInGroup() then
        pickerFrame:Hide()
        DevLog("Hidden (not in a group)")
        return
    end
    if not mockCandidates and not KnowsPowerInfusion() then
        pickerFrame:Hide()
        DevLog("Hidden (Power Infusion not known)")
        return
    end
    Refresh()
    pickerFrame:Show()
    PumpInspect()  -- Refresh ran before Show, so its queueing was gated off
    DevLog("Shown")
end

local function CreatePicker()
    if pickerFrame then return end

    local f = CreateFrame("Frame", "LuckyGrabbagPIPickerFrame", UIParent, "BackdropTemplate")
    f:SetSize(PAD * 2 + ROW_WIDTH, 100)
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

    local S = LuckyGrabbag.Strings.powerInfusion

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(LuckyUI.TITLE_FONT, 11, "")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetTextColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
    title:SetText(S.title)

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    local closeBtnHl = closeBtn:CreateTexture(nil, "HIGHLIGHT")
    closeBtnHl:SetAllPoints()
    closeBtnHl:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])
    local closeBtnText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeBtnText:SetFont(LuckyUI.BODY_FONT, 13, "")
    closeBtnText:SetAllPoints()
    closeBtnText:SetJustifyH("CENTER")
    closeBtnText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    closeBtnText:SetText("x")
    closeBtn:SetScript("OnClick", function()
        dismissed = true
        pickerFrame:Hide()
    end)
    closeBtn:SetScript("OnEnter", function()
        closeBtnText:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    end)
    closeBtn:SetScript("OnLeave", function()
        closeBtnText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    end)

    local current = f:CreateFontString(nil, "OVERLAY")
    current:SetFont(LuckyUI.BODY_FONT, 11, "")
    current:SetPoint("TOPLEFT", PAD, -(PAD + 16))
    current:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    f.currentLine = current

    local empty = f:CreateFontString(nil, "OVERLAY")
    empty:SetFont(LuckyUI.BODY_FONT, 11, "")
    empty:SetPoint("TOPLEFT", PAD, -(PAD + HEADER_HEIGHT))
    empty:SetWidth(220)
    empty:SetJustifyH("LEFT")
    empty:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    empty:SetText(S.notInGroup)
    empty:Hide()
    f.emptyLabel = empty

    pickerFrame = f
    DevLog("Frame created")
end

function LuckyGrabbag.PowerInfusion:ApplySetting()
    UpdateVisibility()
end

function LuckyGrabbag.PowerInfusion:Init(database, characterDB)
    db = database
    charDB = characterDB

    local _, class = UnitClass("player")
    if class ~= "PRIEST" then return end

    DevLog("Init called")
    CreatePicker()
    inCombat = InCombatLockdown()

    SLASH_LGBPIPICKER1 = "/pipicker"
    SLASH_LGBPIPICKER2 = "/pitarget"
    SlashCmdList["LGBPIPICKER"] = function(msg)
        local prefix = LuckyGrabbag.Strings.addon.prefix
        local arg, countArg = (msg or ""):lower():match("^%s*(%a*)%s*(%d*)")
        if arg == "mock" then
            if mockCandidates and countArg == "" then
                mockCandidates = nil
                print(prefix .. " PI picker mock roster off.")
            else
                local count = math.min(math.max(tonumber(countArg) or 14, 1), 40)
                mockCandidates = BuildMockCandidates(count)
                dismissed = false
                print(prefix .. " PI picker mock roster on (" .. count .. " players). '/pipicker mock' again turns it off.")
            end
            UpdateVisibility()
            return
        end
        Refresh()
        pickerFrame:Show()
        PumpInspect()
        DevLog("Force-shown via slash command")
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "INSPECT_READY" then
            HandleInspectReady(arg1)
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
        elseif event == "ENCOUNTER_START" or event == "CHALLENGE_MODE_START" then
            dismissed = false
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            -- Group members respeccing need a fresh inspect.
            if arg1 and arg1 ~= "player" and UnitExists(arg1) then
                local guid = UnitGUID(arg1)
                if guid then specCache[guid] = nil end
            end
        end
        UpdateVisibility()
    end)

    C_Timer.After(1, UpdateVisibility)
end
