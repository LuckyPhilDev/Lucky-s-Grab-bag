LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveBoons = {}

local BOONS_SPELL_ID = 1280098
-- Two-minute buffs from the Loa-Spirit conduits in the Labyrinth of Kindo'jan.
local CONDUIT_SPELL_IDS = {
    1314332, -- Spiritual Wind Conduit
    1314346, -- Spiritual Earth Conduit
    1314350, -- Spiritual Fire Conduit
    1314353, -- Spiritual Mist Conduit
}
-- Positions of the stats in the Boons tooltip, which always lists all eight in this order.
local STAT_COUNT = 8
local STAT_INDEX = { health = 1, speed = 2, primary = 3, damageReduction = 8 }
-- Boons are items consumed on pickup. Their loot message stays readable in combat when the aura doesn't.
-- The random and highest/lowest secondary boons are left for the reading after combat.
local BOON_GAINS = {
    [260879] = { primary = 2 },
    [267237] = { primary = 4 },
    [267243] = { health = 1 },
    [260910] = { health = 3 },
    [267235] = { health = 6 },
    [267242] = { speed = 1 },
    [264668] = { speed = 5 },
    [267236] = { speed = 10 },
    [260911] = { damageReduction = 2 },
    [267240] = { damageReduction = 4 },
    [267647] = { health = 2, speed = 2 },
    [267649] = { health = 3, speed = 5 },
    [267648] = { health = 6, speed = 10 },
}
local DELVE_DIFFICULTY_ID = 208
local PAD = 8
local WIDTH = 190
local STALE_ALPHA = 0.5
local TITLE_HEIGHT = 15
local ROW_HEIGHT = 15
local ROW_WIDTH = WIDTH - PAD * 2
local SHIMMER_WIDTH = 48
local SHIMMER_SECONDS = 0.7
local SHIMMER_PEAK = CreateColor(1, 0.85, 0.4, 0.55)
local SHIMMER_CLEAR = CreateColor(1, 0.85, 0.4, 0)
local TIMER_INTERVAL = 0.25
local SETTINGS_LINK = "addon:LuckyGrabbag:delveBoons"

local C = LuckyUI.C

local db
local panel
local rows = {}
local stats = {}
local conduits = {}
-- Nil until the first reading in a delve, so entering one or reloading doesn't shimmer every stat.
local lastAmounts

local DevLog = LuckyGrabbag.Logger("DelveBoons")

local function S()
    return LuckyGrabbag.Strings.delveBoons
end

local function InDelve()
    local _, _, difficultyID = GetInstanceInfo()
    return difficultyID == DELVE_DIFFICULTY_ID
end

local function ReadBoons()
    local result = {}
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(BOONS_SPELL_ID)
    if not aura then return result end
    local data = C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", aura.auraInstanceID)
    if not data then return result end
    for i = 2, #data.lines do
        -- The stats arrive as one tooltip line joined by newlines.
        for line in (data.lines[i].leftText or ""):gmatch("[^\r\n]+") do
            local text = line:gsub("%.?%s*$", "")
            local label, amount = text:match("^(.-):%s*([%d%.]+)%%$")
            result[#result + 1] = { text = text, label = label, amount = tonumber(amount) }
        end
    end
    return result
end

local function ReadConduits()
    local result = {}
    for _, spellID in ipairs(CONDUIT_SPELL_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura and aura.expirationTime > 0 then
            result[#result + 1] = { name = aura.name, expires = aura.expirationTime }
        end
    end
    return result
end

local function SavePosition()
    local point, _, relPoint, x, y = panel:GetPoint()
    db.delveBoonsPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function OpenSettings()
    LuckyGrabbag.Settings:OpenTo(LuckyGrabbag.Settings.delvesGroup, LuckyGrabbag.Strings.settings.delveBoons.label)
end

local function TurnOff()
    db.showDelveBoons = false
    panel:Hide()
    local link = "|cff71d5ff|H" .. SETTINGS_LINK .. "|h[" .. S().settingsLink .. "]|h|r"
    print(LuckyGrabbag.PREFIX .. " " .. string.format(S().turnedOff, link))
end

local function CreateCloseButton(f)
    local btn = CreateFrame("Button", nil, f)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPRIGHT", -4, -4)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])
    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(LuckyUI.BODY_FONT, 13, "")
    label:SetAllPoints()
    label:SetJustifyH("CENTER")
    label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    label:SetText("x")
    btn:SetScript("OnClick", TurnOff)
    btn:SetScript("OnEnter", function()
        label:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    end)
    btn:SetScript("OnLeave", function()
        label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    end)
end

local function CreateShimmerHalf(shimmer, point, fromColor, toColor)
    local half = shimmer:CreateTexture(nil, "ARTWORK")
    half:SetTexture("Interface\\Buttons\\WHITE8X8")
    half:SetBlendMode("ADD")
    half:SetGradient("HORIZONTAL", fromColor, toColor)
    half:SetPoint("TOP" .. point)
    half:SetPoint("BOTTOM" .. point)
    half:SetWidth(SHIMMER_WIDTH / 2)
end

-- A band of light that sweeps left to right; the row clips it, so it rests unseen off the left edge.
local function CreateShimmer(row)
    local shimmer = CreateFrame("Frame", nil, row)
    shimmer:SetSize(SHIMMER_WIDTH, ROW_HEIGHT)
    shimmer:SetPoint("RIGHT", row, "LEFT")
    CreateShimmerHalf(shimmer, "LEFT", SHIMMER_CLEAR, SHIMMER_PEAK)
    CreateShimmerHalf(shimmer, "RIGHT", SHIMMER_PEAK, SHIMMER_CLEAR)

    local sweep = shimmer:CreateAnimationGroup()
    local move = sweep:CreateAnimation("Translation")
    move:SetOffset(ROW_WIDTH + SHIMMER_WIDTH, 0)
    move:SetDuration(SHIMMER_SECONDS)
    move:SetSmoothing("IN_OUT")
    return sweep
end

local function CreateRowText(row, justify)
    local text = row:CreateFontString(nil, "OVERLAY")
    text:SetFont(LuckyUI.BODY_FONT, 11, "")
    text:SetPoint(justify)
    text:SetJustifyH(justify)
    return text
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PAD, -(PAD + TITLE_HEIGHT + (i - 1) * ROW_HEIGHT))
    row:SetClipsChildren(true)
    row.text = CreateRowText(row, "LEFT")
    row.value = CreateRowText(row, "RIGHT")
    row.value:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    row.shimmer = CreateShimmer(row)
    rows[i] = row
    return row
end

local function SetRow(i, text, color)
    local row = GetRow(i)
    row.text:SetText(text)
    row.text:SetTextColor(color[1], color[2], color[3])
    row.value:SetText("")
    row:Show()
    return row
end

local function FormatRemaining(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function UpdateTimers()
    local now = GetTime()
    for i, conduit in ipairs(conduits) do
        rows[#stats + i].value:SetText(FormatRemaining(math.max(0, conduit.expires - now)))
    end
end

local function Layout()
    local now = GetTime()
    for i = #conduits, 1, -1 do
        if conduits[i].expires <= now then table.remove(conduits, i) end
    end

    local count = 0
    for _, stat in ipairs(stats) do
        if stat.amount ~= 0 then
            count = count + 1
            local row = SetRow(count, stat.text, C.textLight)
            if stat.upgraded then row.shimmer:Restart() end
        end
        stat.upgraded = nil
    end
    for _, conduit in ipairs(conduits) do
        count = count + 1
        SetRow(count, conduit.name, C.goldPrimary)
    end
    for i = count + 1, #rows do
        rows[i]:Hide()
    end

    UpdateTimers()
    panel:SetHeight(PAD * 2 + TITLE_HEIGHT + count * ROW_HEIGHT)
    panel:SetShown(count > 0)
end

local function MarkUpgrades()
    local amounts = {}
    for _, stat in ipairs(stats) do
        if stat.label then
            amounts[stat.label] = stat.amount
            stat.upgraded = lastAmounts and stat.amount > (lastAmounts[stat.label] or 0)
        end
    end
    lastAmounts = amounts
end

local function OnTimerTick(self, elapsed)
    self.sinceTick = (self.sinceTick or 0) + elapsed
    if self.sinceTick < TIMER_INTERVAL then return end
    self.sinceTick = 0
    local now = GetTime()
    for _, conduit in ipairs(conduits) do
        if conduit.expires <= now then return Layout() end
    end
    UpdateTimers()
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
    f:SetScript("OnUpdate", OnTimerTick)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("LOW")
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(LuckyUI.TITLE_FONT, 11, "")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetTextColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
    title:SetText(S().title)

    CreateCloseButton(f)

    panel = f
end

-- Aura data is secret in combat, so the panel keeps the last reading, dimmed, until combat ends.
-- Conduit timers keep counting down from the expiry read before the fight.
local function Refresh()
    if not db.showDelveBoons or not InDelve() then
        lastAmounts = nil
        panel:Hide()
        return
    end
    if InCombatLockdown() then
        panel:SetAlpha(STALE_ALPHA)
        return
    end
    stats = ReadBoons()
    conduits = ReadConduits()
    DevLog("Refresh: %d stats, %d conduits", #stats, #conduits)
    MarkUpgrades()
    panel:SetAlpha(1)
    Layout()
end

-- Before the first boon there is no aura to read labels from, so these stand in until combat ends.
local function PlaceholderStats()
    local result = {}
    for i, label in ipairs(S().stats) do
        result[i] = { label = label, amount = 0 }
    end
    return result
end

local function AddGain(stat, gain)
    stat.amount = stat.amount + gain
    stat.text = string.format("%s: %g%%", stat.label, stat.amount)
    stat.upgraded = true
    if lastAmounts then lastAmounts[stat.label] = stat.amount end
end

-- Out of combat UNIT_AURA brings the real reading, so only combat pickups are estimated.
local function OnLoot(text)
    if not db.showDelveBoons or not InCombatLockdown() or issecretvalue(text) or not InDelve() then return end
    local gains = BOON_GAINS[tonumber(text:match("|Hitem:(%d+)"))]
    if not gains then return end
    if #stats == 0 then stats = PlaceholderStats() end
    if #stats ~= STAT_COUNT then return end
    for kind, gain in pairs(gains) do
        AddGain(stats[STAT_INDEX[kind]], gain)
    end
    DevLog("Estimated a boon picked up in combat")
    Layout()
end

function LuckyGrabbag.DelveBoons:ApplySetting()
    if panel then Refresh() end
end

function LuckyGrabbag.DelveBoons:Init(database)
    db = database
    CreatePanel()
    EventRegistry:RegisterCallback("SetItemRef", function(_, link)
        if link == SETTINGS_LINK then OpenSettings() end
    end, LuckyGrabbag.DelveBoons)

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

    local lootFrame = CreateFrame("Frame")
    lootFrame:RegisterEvent("CHAT_MSG_LOOT")
    lootFrame:SetScript("OnEvent", function(_, _, text) OnLoot(text) end)
end
