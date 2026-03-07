-- Lucky's Grab-bag: Cooking profession utility buttons
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Cooking = {}

local COOKING_SKILL_LINE_ID = 185
local CHEFS_HAT_ITEM_ID     = 134020
local CHEFS_HAT_SPELL_ID    = 67556
local CAMPFIRE_SPELL_ID     = 818

local db
local campfireButton
local campfireCooldown
local chefsHatButton
local chefsHatGlow

local PREFIX = "|cff00cc00Lucky:|r"
local DEV    = "|cffaaaaaa[Cooking]|r"

local function DevLog(msg)
    if db.devMode then
        print(PREFIX .. " " .. DEV .. " " .. msg)
    end
end

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
            chefsHatButton:SetAttribute("type", "cancelaura")
            chefsHatButton:SetAttribute("spell", aura and aura.name)
            chefsHatButton:SetAttribute("*toy1", nil)
        end
        DevLog("Chef's Hat buff active — button set to cancel")
    else
        if chefsHatGlow then chefsHatGlow:Hide() end
        if not InCombatLockdown() then
            chefsHatButton:SetAttribute("type", "toy")
            chefsHatButton:SetAttribute("*toy1", CHEFS_HAT_ITEM_ID)
            chefsHatButton:SetAttribute("spell", nil)
        end
        DevLog("Chef's Hat buff inactive — button set to use toy")
    end
end

local function ShowButtons()
    if campfireButton then
        campfireButton:Show()
        chefsHatButton:Show()
        UpdateChefsHatButton()
        UpdateCampfireCooldown()
        DevLog("Buttons shown")
    end
end

local function HideButtons()
    if campfireButton then
        campfireButton:Hide()
        chefsHatButton:Hide()
        DevLog("Buttons hidden")
    end
end

local function CreateButtons()
    if campfireButton then return end

    local frame = _G["ProfessionsFrame"] ---@diagnostic disable-line: undefined-global
    DevLog("CreateButtons — ProfessionsFrame=" .. tostring(frame))
    if not frame then return end

    -- Shared parent anchored next to the Professions frame.
    -- Plain Frame parented to UIParent keeps the secure frame hierarchy clean.
    local parent = CreateFrame("Frame", "LGB_CookingButtonsParent", UIParent) ---@diagnostic disable-line: undefined-global
    parent:SetFrameStrata("MEDIUM")
    parent:SetSize(42, 89) -- two 42px buttons + 5px gap
    parent:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
    parent:EnableMouse(false)

    -- Campfire button
    -- type="spell" with spell attribute avoids the ADDON_ACTION_FORBIDDEN restriction on CastSpellByID.
    campfireButton = CreateFrame("Button", "LGB_CampfireButton", parent, "SecureActionButtonTemplate")
    campfireButton:SetSize(42, 42)
    campfireButton:SetPoint("TOP", parent, "TOP", 0, 0)
    campfireButton:RegisterForClicks("AnyDown", "AnyUp")
    campfireButton:SetAttribute("type", "spell")
    campfireButton:SetAttribute("spell", CAMPFIRE_SPELL_ID)
    campfireButton:SetNormalTexture(C_Spell.GetSpellTexture(CAMPFIRE_SPELL_ID))
    campfireButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    campfireButton:GetHighlightTexture():SetBlendMode("ADD") ---@diagnostic disable-line: param-type-mismatch
    campfireButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(CAMPFIRE_SPELL_ID)
        GameTooltip:Show()
    end)
    campfireButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Campfire cooldown overlay
    campfireCooldown = CreateFrame("Cooldown", nil, campfireButton, "CooldownFrameTemplate")
    campfireCooldown:SetAllPoints(campfireButton)
    campfireCooldown:SetHideCountdownNumbers(false)

    -- Chef's Hat button
    -- type="toy" with "*toy1" (modified attribute for left-click) is required in TWW.
    -- RegisterForClicks must include "AnyDown" for the secure action to fire.
    chefsHatButton = CreateFrame("Button", "LGB_ChefsHatButton", parent, "SecureActionButtonTemplate")
    chefsHatButton:SetSize(42, 42)
    chefsHatButton:SetPoint("TOP", campfireButton, "BOTTOM", 0, -5)
    chefsHatButton:RegisterForClicks("AnyDown", "AnyUp")
    chefsHatButton:SetAttribute("type", "toy")
    chefsHatButton:SetAttribute("*toy1", CHEFS_HAT_ITEM_ID)

    local hatIcon = C_Item.GetItemIconByID(CHEFS_HAT_ITEM_ID) or C_Spell.GetSpellTexture(CHEFS_HAT_SPELL_ID)
    chefsHatButton:SetNormalTexture(hatIcon)
    chefsHatButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    chefsHatButton:GetHighlightTexture():SetBlendMode("ADD") ---@diagnostic disable-line: param-type-mismatch
    chefsHatButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetToyByItemID(CHEFS_HAT_ITEM_ID)
        GameTooltip:Show()
    end)
    chefsHatButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chefsHatButton:SetScript("PostClick", function()
        DevLog("Chef's Hat clicked")
    end)

    -- Active-buff glow: a bright border overlay shown when the buff is up.
    -- Drawn in OVERLAY so it sits above the icon but below tooltips.
    chefsHatGlow = chefsHatButton:CreateTexture(nil, "OVERLAY")
    chefsHatGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    chefsHatGlow:SetBlendMode("ADD")
    chefsHatGlow:SetAllPoints(chefsHatButton)
    chefsHatGlow:Hide()

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
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            local info = C_TradeSkillUI.GetBaseProfessionInfo()
            local professionID = info and info.professionID
            DevLog("TRADE_SKILL_DATA_SOURCE_CHANGED professionID=" .. tostring(professionID) .. " (want " .. COOKING_SKILL_LINE_ID .. ") showCookingButtons=" .. tostring(db.showCookingButtons))
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
        end
    end)
end
