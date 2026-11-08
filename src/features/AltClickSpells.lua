-- luacheck: globals GetCVarBool IsPlayerSpell IsAltKeyDown GetBindingKey GetBindingText

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AltClickSpells = {}

local COMPREHEND_SCROLL_SPELL_ID = 1296017
local DISENCHANT_SPELL_ID = 13262

local BINDING = "CLICK LGB_AltClickSpellButton:RightButton"
local DISENCHANT_PURPLE = { 0.8, 0.6, 1 }

local PROC_LOOP = {
    atlas    = "UI-HUD-ActionBar-Proc-Loop-Flipbook",
    rows     = 6,
    columns  = 5,
    frames   = 30,
    duration = 1.0,
    scale    = 1.4,
}

local db
local overlay
local hovered

function LuckyGrabbag.AltClickSpells:IsScroll(lines, skillName)
    if not lines or not skillName or skillName == "" then return false end
    for _, line in ipairs(lines) do
        if line.leftText and line.leftText:find(skillName, 1, true) then return true end
    end
    return false
end

local SPELLS = {
    {
        spellID = COMPREHEND_SCROLL_SPELL_ID,
        enabled = function() return db.comprehendScroll end,
        matches = function(data)
            return LuckyGrabbag.AltClickSpells:IsScroll(data.lines, C_Spell.GetSpellSubtext(COMPREHEND_SCROLL_SPELL_ID))
        end,
    },
    {
        spellID = DISENCHANT_SPELL_ID,
        color   = DISENCHANT_PURPLE,
        enabled = function() return db.altClickDisenchant end,
        matches = function(_, bag, slot)
            return LuckyGrabbag.MassDisenchant:IsCandidate(C_Container.GetContainerItemInfo(bag, slot), true)
        end,
    },
}

function LuckyGrabbag.AltClickSpells:Macro(spellID, bag, slot)
    return ("/cast %s\n/use %d %d"):format(C_Spell.GetSpellName(spellID), bag, slot)
end

local function HideOverlay()
    if InCombatLockdown() or not overlay:IsShown() then return end
    overlay:Hide()
    overlay:ClearAllPoints()
end

-- The key binding clicks the overlay even while it is hidden, so it always targets the hovered item or nothing.
local function SetTarget(target)
    if InCombatLockdown() then return end
    hovered = target
    local macro = target and LuckyGrabbag.AltClickSpells:Macro(target.spellID, target.bag, target.slot) or ""
    overlay:SetAttribute("*macrotext2", macro)
end

-- A secure button only takes the click while Alt is held, so ordinary bag clicks still reach the slot.
local function ShowOverlay()
    if InCombatLockdown() or not hovered or not IsAltKeyDown() then return end
    if not hovered.owner:IsMouseOver() then return end
    overlay:ClearAllPoints()
    overlay:SetAllPoints(hovered.owner)
    overlay:SetFrameStrata("TOOLTIP")
    local width, height = hovered.owner:GetSize()
    overlay.swirl:SetSize(width * PROC_LOOP.scale, height * PROC_LOOP.scale)
    local color = hovered.color
    overlay.swirl:SetDesaturated(color ~= nil)
    if color then
        overlay.swirl:SetVertexColor(color[1], color[2], color[3])
    else
        overlay.swirl:SetVertexColor(1, 1, 1)
    end
    overlay:Show()
end

local function OnItemTooltip(tooltip, data)
    if tooltip ~= GameTooltip or not data then return end
    SetTarget(nil)
    local owner = tooltip:GetOwner()
    if not (owner and owner.GetBagID and owner ~= overlay) then return end
    local bag, slot = owner:GetBagID(), owner:GetID()
    if not bag then return end
    for _, spell in ipairs(SPELLS) do
        if spell.enabled() and IsPlayerSpell(spell.spellID) and spell.matches(data, bag, slot) then
            local strings = LuckyGrabbag.Strings.altClickSpells
            local spellName = C_Spell.GetSpellName(spell.spellID)
            local key = GetBindingKey(BINDING)
            local hint = key and strings.tooltipHintBound:format(GetBindingText(key), spellName)
                or strings.tooltipHint:format(spellName)
            tooltip:AddLine(hint, 0.1, 1, 0.1)
            SetTarget({ owner = owner, bag = bag, slot = slot, spellID = spell.spellID, color = spell.color })
            ShowOverlay()
            return
        end
    end
end

local function BuildOverlay()
    overlay = CreateFrame("Button", "LGB_AltClickSpellButton", UIParent, "SecureActionButtonTemplate")
    overlay:Hide()
    local trigger = GetCVarBool("ActionButtonUseKeyDown") and "RightButtonDown" or "RightButtonUp"
    overlay:RegisterForClicks(trigger)
    overlay:SetAttribute("*type2", "macro")

    local swirl = overlay:CreateTexture(nil, "OVERLAY")
    swirl:SetAtlas(PROC_LOOP.atlas)
    swirl:SetBlendMode("ADD")
    swirl:SetPoint("CENTER")
    overlay.swirl = swirl

    local spin = overlay:CreateAnimationGroup()
    spin:SetLooping("REPEAT")
    local flip = spin:CreateAnimation("FlipBook")
    flip:SetTarget(swirl)
    flip:SetDuration(PROC_LOOP.duration)
    flip:SetFlipBookRows(PROC_LOOP.rows)
    flip:SetFlipBookColumns(PROC_LOOP.columns)
    flip:SetFlipBookFrames(PROC_LOOP.frames)
    overlay:SetScript("OnShow", function() spin:Play() end)
    overlay:SetScript("OnHide", function() spin:Stop() end)

    -- The overlay steals the mouse from the slot, whose OnLeave hides the tooltip, so replay the slot's OnEnter.
    overlay:SetScript("OnEnter", function()
        local onEnter = hovered and hovered.owner:GetScript("OnEnter")
        if onEnter then onEnter(hovered.owner) end
    end)
    overlay:SetScript("OnLeave", function()
        if hovered and GameTooltip:IsOwned(hovered.owner) then GameTooltip:Hide() end
        HideOverlay()
        SetTarget(nil)
    end)
    overlay:SetScript("PostClick", HideOverlay)
end

function LuckyGrabbag.AltClickSpells:Init(database)
    db = database
    BuildOverlay()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    GameTooltip:HookScript("OnHide", function()
        if not overlay:IsShown() then SetTarget(nil) end
    end)

    local strings = LuckyGrabbag.Strings.altClickSpells
    _G.BINDING_HEADER_LUCKYGRABBAG = strings.bindingHeader
    _G["BINDING_NAME_" .. BINDING] = strings.bindingName

    local events = CreateFrame("Frame")
    events:RegisterEvent("MODIFIER_STATE_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "MODIFIER_STATE_CHANGED" and IsAltKeyDown() then
            ShowOverlay()
            return
        end
        HideOverlay()
        if event == "PLAYER_REGEN_DISABLED" then SetTarget(nil) end
    end)
end
