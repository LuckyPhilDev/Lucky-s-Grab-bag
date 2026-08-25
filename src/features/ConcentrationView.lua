-- Lucky's Grab-bag: Concentration View
--
-- Shows a Concentration bar just above each primary profession's skill bar on
-- the Profession Book frame, so you can see your Concentration for both
-- professions at a glance without opening each crafting window.
--
-- Concentration is a currency. C_CurrencyInfo.GetCurrencyInfo(currencyID)
-- returns the live amount, max, and recharge timing without the crafting
-- window. The currency ID is per-expansion, so it must be mapped from the
-- profession's active skill-line-variant ID (the table below). Add a few rows
-- each expansion.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ConcentrationView = {}

local ConcentrationView = LuckyGrabbag.ConcentrationView
local C = LuckyUI.C  -- shared style guide colors
local db

-- Active-expansion skill-line-variant ID -> concentration currency ID.
-- Gathering professions have no concentration and are simply omitted.
local CONCENTRATION_CURRENCY = {
    -- Midnight
    [2906] = 3161, -- Alchemy
    [2907] = 3162, -- Blacksmithing
    [2909] = 3163, -- Enchanting
    [2910] = 3164, -- Engineering
    [2913] = 3165, -- Inscription
    [2914] = 3166, -- Jewelcrafting
    [2915] = 3167, -- Leatherworking
    [2918] = 3168, -- Tailoring
    -- The War Within
    [2871] = 3045, -- Alchemy
    [2872] = 3040, -- Blacksmithing
    [2874] = 3046, -- Enchanting
    [2875] = 3044, -- Engineering
    [2878] = 3043, -- Inscription
    [2879] = 3013, -- Jewelcrafting
    [2880] = 3042, -- Leatherworking
    [2883] = 3041, -- Tailoring
}

local bars            = {}    -- [1] / [2] -> bar frame (or false if none)
local hooked          = false
local listening       = false
local ticker

local DevLog = LuckyGrabbag.Logger("ConcentrationView")

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------

-- Resolve a book slot (1 or 2) to its active-expansion skill-line-variant ID
-- and profession name. Ported from the standard GetProfessions/GetProfessionInfo
-- approach used across profession addons.
local function GetSlotProfessionID(index)
    local prof = select(index, GetProfessions())
    if not prof then return end

    local subcategoryName = select(11, GetProfessionInfo(prof))
    if not subcategoryName or subcategoryName == "" then return end

    local skillLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    for _, skillLine in ipairs(skillLines) do
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
        if info and info.professionName == subcategoryName then
            return skillLine, info.professionName
        end
    end
end

-- Returns currencyInfo, professionName for a slot, or nil if the profession has
-- no concentration (gathering, or an expansion not in the table yet).
local function GetConcentrationForSlot(index)
    local skillLineVariantID, professionName = GetSlotProfessionID(index)
    if not skillLineVariantID then return end

    local currencyID = CONCENTRATION_CURRENCY[skillLineVariantID]
    if not currencyID then return end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info or not info.maxQuantity or info.maxQuantity == 0 then return end

    return info, professionName
end

-- Estimate the live amount, accounting for passive recharge since the server
-- last updated the currency, plus the seconds remaining until full.
local function EstimateConcentration(info)
    local quantity = info.quantity or 0
    local maxQuantity = info.maxQuantity or 0
    local cycleMS = info.rechargingCycleDurationMS or 0

    if quantity >= maxQuantity or cycleMS <= 0 then
        return math.min(quantity, maxQuantity), 0
    end

    local cycleSeconds = cycleMS / 1000
    local elapsed = GetServerTime() - (info.lastUpdated or GetServerTime())
    local recharged = elapsed / cycleSeconds
    local estimated = math.min(quantity + recharged, maxQuantity)
    local secondsToFull = math.max(0, (maxQuantity - estimated) * cycleSeconds)

    return estimated, secondsToFull
end

local function FormatETA(seconds)
    seconds = math.floor(seconds)
    if seconds <= 0 then return nil end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm", m)
    end
    return "<1m"
end

-- ---------------------------------------------------------------------------
-- Bar widget
-- ---------------------------------------------------------------------------

local function BarOnEnter(self)
    if not self.currencyInfo then return end
    local S = LuckyGrabbag.Strings.concentrationView
    local estimated, secondsToFull = EstimateConcentration(self.currencyInfo)

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.currencyInfo.name, 1, 1, 1)
    GameTooltip:AddLine(
        string.format(S.tooltipCurrent, math.floor(estimated), self.currencyInfo.maxQuantity),
        C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3]
    )
    local eta = FormatETA(secondsToFull)
    if eta then
        GameTooltip:AddLine(string.format(S.tooltipRecharge, eta), C.textLight[1], C.textLight[2], C.textLight[3])
    else
        GameTooltip:AddLine(S.tooltipFull, C.success[1], C.success[2], C.success[3])
    end
    GameTooltip:Show()
end

local function BarOnLeave()
    GameTooltip:Hide()
end

-- The rank/skill bar under a primary profession. Prefer the named global, but
-- fall back to the slot frame's status bar in case the naming changes.
local function GetSkillBar(index)
    local bar = _G["PrimaryProfession" .. index .. "StatusBar"]
    if bar then return bar end

    local slot = _G["PrimaryProfession" .. index]
    if slot then
        if slot.statusBar then return slot.statusBar end
        if slot.StatusBar then return slot.StatusBar end
        for _, child in ipairs({ slot:GetChildren() }) do
            if child.IsObjectType and child:IsObjectType("StatusBar") then
                return child
            end
        end
    end
    return nil
end

-- Gold tint applied to the frame's end caps so the rounded ends match the fill.
local CAP_GOLD = { 1.0, 0.85, 0.10 }

-- Clone the skill bar's frame/trough art (the rounded border + end caps, a
-- separate texture file from the flat fill) onto our bar so it reads as native.
-- We copy every BACKGROUND texture region except the StatusBar's own fill,
-- preserving each region's texture, tex coords, blend, size and anchors. Anchors
-- that referenced the skill bar are remapped to our bar so the caps stick out
-- past our edges exactly like they do on the original.
--
-- The native bar is built from three texture layers:
--   BACKGROUND - the wide recessed channel plus two narrow recessed end caps
--   ARTWORK    - the flat fill, which spans only the channel (handled elsewhere)
--   OVERLAY    - two narrow rim caps that draw the finished, rounded ends
-- The rounded ends are entirely the caps; the fill itself is flat. The recessed
-- BACKGROUND caps render dark even when tinted, so the bright rounded ends come
-- from the OVERLAY rim caps. We therefore clone the BACKGROUND trough/caps AND
-- the OVERLAY rim caps, tinting every narrow cap gold to match the fill, and skip
-- any wide OVERLAY region (the glossy full-length sheen).
--
-- Every clone is positioned explicitly by its native horizontal offset from the
-- skill bar's left edge, at our bar's height. Native anchors point at sibling
-- regions and don't survive a naive remap onto our bar: copying them produced
-- 128px-tall dark bands (the recessed caps) and a zero-width trough.
local CAP_MAX_WIDTH = 24

local function CloneBorder(skillBar, bar)
    local fillTex = skillBar:GetStatusBarTexture()
    local skillLeft = skillBar:GetLeft()
    local skillBottom = skillBar:GetBottom()
    bar.borderRegions = {}

    for _, region in ipairs({ skillBar:GetRegions() }) do
        local isTexture = region.IsObjectType and region:IsObjectType("Texture")
        -- Capture geometry in a plain block: `local a, b = cond and f()` keeps only
        -- f()'s first return value, which silently dropped every height to nil.
        local layer, sublevel, atlas, file, w, h
        if isTexture then
            layer, sublevel = region:GetDrawLayer()
            atlas = region.GetAtlas and region:GetAtlas()
            file = region:GetTexture()
            w, h = region:GetSize()
        end
        local isCap = w and w > 0 and w <= CAP_MAX_WIDTH
        local isRimCap = layer == "OVERLAY" and isCap

        -- Clone BACKGROUND art and the narrow OVERLAY rim caps. Skip the fill, any
        -- wide OVERLAY sheen, and regions with no actual texture (cloning a nil
        -- texture renders WoW's red "forbidden" placeholder).
        local accept = isTexture
            and region ~= fillTex
            and region:IsShown()
            and (atlas or file)
            and (layer == "BACKGROUND" or isRimCap)

        if accept then
            local clone = bar:CreateTexture(nil, layer, nil, sublevel)

            if atlas then
                clone:SetAtlas(atlas)
            else
                clone:SetTexture(file)
                clone:SetTexCoord(region:GetTexCoord())
            end
            if region.GetBlendMode then clone:SetBlendMode(region:GetBlendMode()) end

            -- Reproduce the region's exact geometry relative to the skill bar's
            -- bottom-left, which is also our gold fill's baseline (the fill is
            -- pinned to the bar's bottom-left). Each clone keeps its native size
            -- and offset, so caps overhang and sit at the right height exactly as
            -- on the native bar, instead of being stretched or vertically centred.
            local relLeft = (region:GetLeft() or skillLeft or 0) - (skillLeft or 0)
            local relBottom = (region:GetBottom() or skillBottom or 0) - (skillBottom or 0)
            clone:SetSize(w, h)
            clone:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", relLeft, relBottom)

            -- The wide trough keeps its native metallic look as the empty channel.
            -- The narrow caps are recorded so the fill logic can tint them gold or
            -- restore their native (dark, hollow) look depending on whether the
            -- fill actually reaches that end. Remember each cap's side and native
            -- colour for that toggle.
            if isCap then
                local nr, ng, nb, na = region:GetVertexColor()
                bar.caps = bar.caps or {}
                table.insert(bar.caps, {
                    tex = clone,
                    isRight = relLeft > 0,
                    isRim = isRimCap,
                    nr = nr, ng = ng, nb = nb, na = na,
                })
            else
                clone:SetVertexColor(region:GetVertexColor())
            end

            table.insert(bar.borderRegions, clone)
        end
    end
end

local function CreateBar(index, professionName)
    local skillBar = GetSkillBar(index)
    if not skillBar then
        DevLog("Skill bar missing for slot " .. index)
        return nil
    end

    local bar = CreateFrame("Frame", nil, ProfessionsBookFrame)
    -- Match the skill bar's exact width (anchor both edges) and height, sitting
    -- just above it, clearing the expansion/rank text line.
    bar:SetPoint("BOTTOMLEFT", skillBar, "TOPLEFT", 0, 16)
    bar:SetPoint("BOTTOMRIGHT", skillBar, "TOPRIGHT", 0, 16)
    bar:SetHeight(skillBar:GetHeight())
    bar:SetFrameLevel(skillBar:GetFrameLevel() + 1)

    bar.skillBar = skillBar

    -- Clone the skill bar's rounded frame/cap art so the empty bar reads as a
    -- native trough, with caps extending past our edges exactly like the original.
    CloneBorder(skillBar, bar)

    -- Gold fill: reuse the skill bar's flat fill texture (desaturated so our tint
    -- takes) and crop it to the fraction. It sits at ARTWORK, above the cloned
    -- BACKGROUND frame, matching the native layering. The rounded look comes from
    -- the cloned frame around it, not the fill itself.
    local fillTex = skillBar:GetStatusBarTexture():GetTexture()
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(fillTex)
    if fill.SetDesaturated then fill:SetDesaturated(true) end
    fill:SetVertexColor(1.0, 0.85, 0.10, 1)
    bar.fill = fill

    -- Line the label's left edge up with the subcategory text below the bar.
    function bar:AlignLabel()
        if not self.subcat then return end
        local subLeft = self.subcat:GetLeft()
        local barLeft = self:GetLeft()
        if subLeft and barLeft then
            self.label:ClearAllPoints()
            self.label:SetPoint("BOTTOMLEFT", self, "TOPLEFT", subLeft - barLeft, 2)
        end
    end

    -- Tint each cap only when the fill reaches it: the left end is filled whenever
    -- there's any concentration, the right end only when it's full. For an empty
    -- end we hide the bright rim cap (the green/gold rounded top) and leave just
    -- the dark recessed groove cap, so the bar ends in a hollow rounded socket
    -- instead of a stray filled one.
    function bar:UpdateCaps()
        local frac = self.pendingFrac or 0
        for _, c in ipairs(self.caps or {}) do
            local filled = c.isRight and frac >= 1 or (not c.isRight and frac > 0)
            local t = c.tex
            if filled then
                t:Show()
                if t.SetDesaturated then t:SetDesaturated(true) end
                t:SetVertexColor(CAP_GOLD[1], CAP_GOLD[2], CAP_GOLD[3])
            elseif c.isRim then
                t:Hide()
            else
                t:Show()
                if t.SetDesaturated then t:SetDesaturated(false) end
                t:SetVertexColor(c.nr, c.ng, c.nb, c.na)
            end
        end
    end

    function bar:ApplyFill()
        local frac = self.pendingFrac or 0
        self:UpdateCaps()
        if frac <= 0 then
            self.fill:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        -- The bar can report no geometry before the first layout pass. If so,
        -- retry on the next frame instead of silently hiding the fill.
        local w = self.skillBar and self.skillBar:GetWidth() or 0
        if not w or w == 0 then
            self:SetScript("OnUpdate", function(s) s:ApplyFill() end)
            return
        end
        self:SetScript("OnUpdate", nil)
        self:AlignLabel()
        self.fill:ClearAllPoints()
        self.fill:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        self.fill:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
        self.fill:SetWidth(frac * w)
        self.fill:SetTexCoord(0, frac, 0, 1)
        self.fill:Show()
    end

    function bar:SetFraction(frac)
        self.pendingFrac = math.max(0, math.min(1, frac or 0))
        self:ApplyFill()
    end

    -- White "Concentration" label, left-aligned above the bar. The profession
    -- name is already the heading right above it, so we keep this short. Match
    -- the font of the profession's subcategory line so it inherits whatever font
    -- the player uses (default or a font-replacement addon).
    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    label:SetTextColor(1, 1, 1)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 0.8)
    bar.label = label

    -- Match the font and left edge of the profession's subcategory line below the
    -- bar, so the label reads as part of the same column. Set the font before any
    -- SetText call (a FontString with no font throws).
    local slot = _G["PrimaryProfession" .. index]
    local subcat
    local fontPath, fontSize, fontFlags
    if slot then
        for _, region in ipairs({ slot:GetRegions() }) do
            if region:IsObjectType("FontString") and region:GetText() == professionName then
                subcat = region
                fontPath, fontSize, fontFlags = region:GetFont()
                break
            end
        end
    end
    if fontPath then
        label:SetFont(fontPath, fontSize, fontFlags)
    else
        label:SetFont(LuckyUI.BODY_FONT, 10)
    end

    -- AlignLabel lines the label's left edge up with the subcategory text once
    -- the geometry is resolved; this is just a sensible default until then.
    bar.subcat = subcat
    label:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
    label:SetText(LuckyGrabbag.Strings.concentrationView.barLabel)

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(LuckyUI.BODY_FONT, 10, "OUTLINE")
    text:SetPoint("CENTER", bar, "CENTER", 0, 2)
    text:SetTextColor(1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 0.8)
    bar.text = text

    bar:EnableMouse(true)
    bar:SetScript("OnEnter", BarOnEnter)
    bar:SetScript("OnLeave", BarOnLeave)

    return bar
end

local function RefreshSlot(index)
    local info, professionName = GetConcentrationForSlot(index)

    if not info then
        DevLog("Slot " .. index .. ": no concentration")
        if bars[index] then bars[index]:Hide() end
        return
    end

    DevLog(string.format("Slot %d (%s): %d/%d", index, professionName or "?",
        info.quantity or 0, info.maxQuantity or 0))

    local bar = bars[index]
    if not bar then
        bar = CreateBar(index, professionName)
        bars[index] = bar
        if not bar then return end
    end

    local estimated = EstimateConcentration(info)
    bar.currencyInfo = info
    bar.professionName = professionName
    bar:SetFraction(info.maxQuantity > 0 and (estimated / info.maxQuantity) or 0)
    bar.text:SetText(string.format("%d / %d", math.floor(estimated), info.maxQuantity))
    bar:Show()
end

local function Refresh()
    if not db.showConcentration then return end
    if not ProfessionsBookFrame or not ProfessionsBookFrame:IsShown() then return end
    for i = 1, 2 do
        RefreshSlot(i)
    end
end

local function HideAll()
    for _, bar in pairs(bars) do
        if bar then bar:Hide() end
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "CURRENCY_DISPLAY_UPDATE" then
        Refresh()
    end
end)

local function StartListening()
    if listening then return end
    listening = true
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    -- Keep the passive-recharge estimate fresh while the book is open.
    ticker = C_Timer.NewTicker(30, Refresh)
end

local function StopListening()
    if not listening then return end
    listening = false
    eventFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function HookBookFrame()
    if hooked then return end
    if not ProfessionsBookFrame then return end
    hooked = true

    ProfessionsBookFrame:HookScript("OnShow", function()
        if not db.showConcentration then return end
        StartListening()
        Refresh()
    end)

    ProfessionsBookFrame:HookScript("OnHide", function()
        StopListening()
    end)

    DevLog("Hooked ProfessionsBookFrame")

    -- The book may already be open (loaded on demand by opening it).
    if db.showConcentration and ProfessionsBookFrame:IsShown() then
        StartListening()
        Refresh()
    end
end

-- ---------------------------------------------------------------------------
-- Module API
-- ---------------------------------------------------------------------------

function ConcentrationView:ApplySetting()
    if db.showConcentration then
        if ProfessionsBookFrame and ProfessionsBookFrame:IsShown() then
            StartListening()
            Refresh()
        end
    else
        StopListening()
        HideAll()
    end
end

function ConcentrationView:Init(database)
    db = database
    DevLog("Init called")

    -- The profession book is load-on-demand. Hook it however it loads:
    -- if it already exists, hook now; otherwise wait for its ADDON_LOADED.
    if ProfessionsBookFrame then
        HookBookFrame()
    else
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, _, addon)
            if addon == "Blizzard_ProfessionsBook" then
                self:UnregisterEvent("ADDON_LOADED")
                HookBookFrame()
            end
        end)
    end

    -- Belt and suspenders for clients that still expose the loader stub.
    if ProfessionsBook_LoadUI then
        hooksecurefunc("ProfessionsBook_LoadUI", HookBookFrame)
    end
end
