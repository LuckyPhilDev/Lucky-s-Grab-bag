-- Lucky's Grab-bag: Cooking profession utility buttons
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Cooking = {}

local COOKING_SKILL_LINE_ID = LuckyGrabbag.CookingData.cookingSkillLineID  -- defined in CookingData.lua
local CHEFS_HAT_ITEM_ID     = LuckyGrabbag.CookingData.chefsHatItemID
local CHEFS_HAT_SPELL_ID    = LuckyGrabbag.CookingData.chefsHatSpellID
local CAMPFIRE_SPELL_ID     = LuckyGrabbag.CookingData.campfireSpellID
local PIERRE_SPECIES_ID     = LuckyGrabbag.CookingData.pierreSpeciesID

local db
local parentFrame
local campfireButton
local campfireCooldown
local chefsHatButton
local chefsHatGlow
local pierreButton
local pierreGlow

local DevLog = LuckyGrabbag.Logger("Cooking")

local function UpdateCampfireCooldown()
    if not campfireCooldown then return end
    local info = C_Spell.GetSpellCooldown(CAMPFIRE_SPELL_ID)
    if info and info.duration and info.duration > 0 then
        campfireCooldown:SetCooldown(info.startTime, info.duration)
    else
        campfireCooldown:Clear()
    end
end

local chefsHatBuffActive = nil

local function UpdateChefsHatButton()
    if not chefsHatButton then return end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(CHEFS_HAT_SPELL_ID)
    local active = aura ~= nil
    if active == chefsHatBuffActive then return end
    chefsHatBuffActive = active
    if active then
        if chefsHatGlow then chefsHatGlow:Show() end
        if not InCombatLockdown() then
            chefsHatButton:SetAttribute("type1", "cancelaura")
            chefsHatButton:SetAttribute("spell", aura and aura.name)
            chefsHatButton:SetAttribute("*toy1", nil)
        end
        DevLog("Chef's Hat buff active — button set to cancel")
    else
        if chefsHatGlow then chefsHatGlow:Hide() end
        if not InCombatLockdown() then
            chefsHatButton:SetAttribute("type1", "toy")
            chefsHatButton:SetAttribute("*toy1", CHEFS_HAT_ITEM_ID)
            chefsHatButton:SetAttribute("spell", nil)
        end
        DevLog("Chef's Hat buff inactive — button set to use toy")
    end
end

-- Looked up by the name the client gives the species, so it works in any language.
local function PierreGUID()
    local name = C_PetJournal.GetPetInfoBySpeciesID(PIERRE_SPECIES_ID)
    return name and select(2, C_PetJournal.FindPetIDByName(name))
end

local function UpdatePierreButton()
    if not pierreButton then return end
    local guid = PierreGUID()
    pierreButton.petGUID = guid
    pierreButton:SetShown(guid ~= nil)
    pierreGlow:SetShown(guid ~= nil and C_PetJournal.GetSummonedPetGUID() == guid)
end

local function ShowButtons()
    if parentFrame then
        parentFrame:RestorePosition()
        campfireButton:Show()
        chefsHatButton:Show()
        UpdateChefsHatButton()
        UpdateCampfireCooldown()
        UpdatePierreButton()
        DevLog("Buttons shown")
    end
end

local function HideButtons()
    if campfireButton then
        campfireButton:Hide()
        chefsHatButton:Hide()
        pierreButton:Hide()
        DevLog("Buttons hidden")
    end
end

local function CreateActiveGlow(button)
    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(button)
    glow:Hide()
    return glow
end

local function CreateButtons()
    if campfireButton then return end

    local frame = _G["ProfessionsFrame"] ---@diagnostic disable-line: undefined-global
    DevLog("CreateButtons — ProfessionsFrame=" .. tostring(frame))
    if not frame then return end

    -- Shared parent anchored next to the Professions frame.
    parentFrame = CreateFrame("Frame", "LGB_CookingButtonsParent", UIParent) ---@diagnostic disable-line: undefined-global
    parentFrame:SetFrameStrata("MEDIUM")
    parentFrame:SetSize(1, 1)
    parentFrame:EnableMouse(false)
    LuckyGrabbag.EnableGroupDrag(parentFrame, frame, "cookingButtonPos", 5, 0)

    -- Campfire button
    -- type1="spell" fires only on left-click; right-click is free for dragging.
    campfireButton = LuckyGrabbag.CreateIconButton({
        name     = "LGB_CampfireButton",
        parent   = parentFrame,
        template = "SecureActionButtonTemplate",
        texture  = C_Spell.GetSpellTexture(CAMPFIRE_SPELL_ID),
        tooltip  = function() GameTooltip:SetSpellByID(CAMPFIRE_SPELL_ID) end,
    })
    campfireButton:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0)
    campfireButton:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    campfireButton:SetAttribute("type1", "spell")
    campfireButton:SetAttribute("spell", CAMPFIRE_SPELL_ID)
    -- unit1="player" makes this ground-targeted spell auto-place at the player's
    -- feet instead of dropping the placement cursor for a manual click.
    campfireButton:SetAttribute("unit1", "player")
    parentFrame:RegisterDraggable(campfireButton)

    -- Campfire cooldown overlay
    campfireCooldown = CreateFrame("Cooldown", nil, campfireButton, "CooldownFrameTemplate")
    campfireCooldown:SetAllPoints(campfireButton)
    campfireCooldown:SetHideCountdownNumbers(false)

    -- Chef's Hat button
    -- type1="toy" fires only on left-click; right-click is free for dragging.
    chefsHatButton = LuckyGrabbag.CreateIconButton({
        name     = "LGB_ChefsHatButton",
        parent   = parentFrame,
        template = "SecureActionButtonTemplate",
        texture  = C_Item.GetItemIconByID(CHEFS_HAT_ITEM_ID) or C_Spell.GetSpellTexture(CHEFS_HAT_SPELL_ID),
        tooltip  = function() GameTooltip:SetToyByItemID(CHEFS_HAT_ITEM_ID) end,
    })
    chefsHatButton:SetPoint("TOPLEFT", campfireButton, "BOTTOMLEFT", 0, -5)
    chefsHatButton:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    chefsHatButton:SetAttribute("type1", "toy")
    chefsHatButton:SetAttribute("*toy1", CHEFS_HAT_ITEM_ID)
    chefsHatButton:SetScript("PostClick", function()
        DevLog("Chef's Hat clicked")
    end)
    parentFrame:RegisterDraggable(chefsHatButton)

    chefsHatGlow = CreateActiveGlow(chefsHatButton)

    -- Summoning a pet needs no secure button, only the click's hardware event.
    local pierreName, pierreIcon, _, _, _, pierreDesc = C_PetJournal.GetPetInfoBySpeciesID(PIERRE_SPECIES_ID)
    pierreButton = LuckyGrabbag.CreateIconButton({
        name     = "LGB_PierreButton",
        parent   = parentFrame,
        texture  = pierreIcon,
        tooltip  = function()
            GameTooltip:AddLine(pierreName)
            GameTooltip:AddLine(pierreDesc, 0.91, 0.86, 0.78, true)
        end,
    })
    pierreButton:SetPoint("TOPLEFT", chefsHatButton, "BOTTOMLEFT", 0, -5)
    pierreButton:SetScript("OnClick", function(self)
        -- Summoning Pierre while he is out dismisses him.
        if self.petGUID then C_PetJournal.SummonPetByGUID(self.petGUID) end
    end)
    parentFrame:RegisterDraggable(pierreButton)
    pierreGlow = CreateActiveGlow(pierreButton)

    DevLog("Buttons created")
end

function LuckyGrabbag.Cooking:Init(database)
    db = database
    DevLog("Init called")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
    eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("COMPANION_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            local info = C_TradeSkillUI.GetBaseProfessionInfo()
            local professionID = info and info.professionID
            DevLog("TRADE_SKILL_DATA_SOURCE_CHANGED professionID=%s (want %d) showCookingButtons=%s",
                tostring(professionID), COOKING_SKILL_LINE_ID, tostring(db.showCookingButtons))
            if professionID == COOKING_SKILL_LINE_ID and db.showCookingButtons then
                CreateButtons()
                ShowButtons()
            else
                HideButtons()
            end
        elseif event == "TRADE_SKILL_CLOSE" then
            HideButtons()
        elseif event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" and campfireButton and campfireButton:IsShown() then
                UpdateChefsHatButton()
            end
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            if campfireButton and campfireButton:IsShown() then
                UpdateCampfireCooldown()
            end
        elseif event == "COMPANION_UPDATE" then
            if campfireButton and campfireButton:IsShown() then
                UpdatePierreButton()
            end
        end
    end)
end
