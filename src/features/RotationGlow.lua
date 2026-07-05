-- Lucky's Grab-bag: Rotation Glow
--
-- Animates an overlay on the cooldown viewer icon matching Blizzard's
-- assisted-combat next-cast suggestion. Built on public APIs:
--   * C_AssistedCombat.GetRotationSpells()
--   * C_AssistedCombat.GetNextCastSpell()
--   * C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
--   * AssistedCombatManager:UpdateAllAssistedHighlightFramesForSpell (hook)

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.RotationGlow = {}

local RotationGlow = LuckyGrabbag.RotationGlow
local db

local FLIPBOOK = {
    atlas    = "RotationHelper_Ants_Flipbook_2x",
    rows     = 6,
    columns  = 5,
    frames   = 30,
    duration = 1.0,
    scale    = 1.5,
}

local enabled        = false
local hooksInstalled = false
local rotationSet    = {}     -- [spellID] = true
local rotationValid  = false
local suggestedSpell = nil

local function DevLog(msg)
    LuckyGrabbag.DevLog("RotationGlow", msg)
end

-- ---------------------------------------------------------------------------
-- Spell extraction & rotation cache
-- ---------------------------------------------------------------------------

local function GetIconSpellIDs(icon)
    if not icon.cooldownID then return nil, nil end
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
    if not info then return nil, nil end
    return info.spellID, info.overrideSpellID
end

local function RebuildRotationSet()
    wipe(rotationSet)
    local spells = C_AssistedCombat.GetRotationSpells()
    if spells then
        for _, spellID in ipairs(spells) do
            rotationSet[spellID] = true
        end
    end
    rotationValid = true
end

local function IsInRotation(spellID)
    if not spellID then return false end
    if not rotationValid then RebuildRotationSet() end
    return rotationSet[spellID] == true
end

-- ---------------------------------------------------------------------------
-- Flipbook overlay
-- ---------------------------------------------------------------------------

local function GetOrCreateOverlay(icon)
    local overlay = icon.luckyRotationGlow
    if overlay then
        local w, h = icon:GetSize()
        overlay.tex:SetSize(w * FLIPBOOK.scale, h * FLIPBOOK.scale)
        return overlay
    end

    overlay = CreateFrame("Frame", nil, icon)
    overlay:SetFrameLevel(icon:GetFrameLevel() + 10)
    overlay:SetAllPoints(icon)

    local tex = overlay:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(FLIPBOOK.atlas)
    tex:SetBlendMode("ADD")
    tex:SetPoint("CENTER", icon, "CENTER", 0, 0)
    local w, h = icon:GetSize()
    tex:SetSize(w * FLIPBOOK.scale, h * FLIPBOOK.scale)
    overlay.tex = tex

    local group = overlay:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group:SetToFinalAlpha(true)
    overlay.anim = group

    local alpha = group:CreateAnimation("Alpha")
    alpha:SetChildKey("tex")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.001)
    alpha:SetOrder(0)

    local flip = group:CreateAnimation("FlipBook")
    flip:SetChildKey("tex")
    flip:SetDuration(FLIPBOOK.duration)
    flip:SetOrder(0)
    flip:SetFlipBookRows(FLIPBOOK.rows)
    flip:SetFlipBookColumns(FLIPBOOK.columns)
    flip:SetFlipBookFrames(FLIPBOOK.frames)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)

    overlay:SetAlpha(0)
    overlay:Show()

    icon.luckyRotationGlow = overlay
    return overlay
end

local function HideOverlay(icon)
    local overlay = icon.luckyRotationGlow
    if not overlay then return end
    overlay:SetAlpha(0)
    if overlay.anim:IsPlaying() then
        overlay.anim:Stop()
    end
end

local function ShowOverlay(icon)
    local overlay = GetOrCreateOverlay(icon)
    overlay:SetAlpha(1)
    if not overlay.anim:IsPlaying() then
        overlay.anim:Play()
    end
end

-- ---------------------------------------------------------------------------
-- Update logic
-- ---------------------------------------------------------------------------

local function UpdateIcon(icon)
    local spellID, overrideID = GetIconSpellIDs(icon)
    if not spellID then
        HideOverlay(icon)
        return
    end

    if not (IsInRotation(spellID) or (overrideID and IsInRotation(overrideID))) then
        HideOverlay(icon)
        return
    end

    local isSuggested = suggestedSpell
        and (spellID == suggestedSpell or (overrideID and overrideID == suggestedSpell))

    if isSuggested then
        ShowOverlay(icon)
    else
        HideOverlay(icon)
    end
end

local function UpdateAll()
    suggestedSpell = C_AssistedCombat.GetNextCastSpell()

    local viewer = _G.EssentialCooldownViewer
    if not viewer then return end

    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.Icon then UpdateIcon(child) end
    end
end

local function HideAllOverlays()
    local viewer = _G.EssentialCooldownViewer
    if not viewer then return end
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child.Icon then HideOverlay(child) end
    end
end

-- ---------------------------------------------------------------------------
-- Events & hooks
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event)
    if not enabled then return end

    if event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "EDIT_MODE_LAYOUTS_UPDATED"
    then
        rotationValid = false
        RebuildRotationSet()
        UpdateAll()
    end
end)

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    local viewer = _G.EssentialCooldownViewer
    if viewer and viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function()
            if not enabled then return end
            UpdateAll()
        end)
    end

    if AssistedCombatManager and AssistedCombatManager.UpdateAllAssistedHighlightFramesForSpell then
        hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell", function()
            if not enabled then return end
            UpdateAll()
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Module API
-- ---------------------------------------------------------------------------

local function Enable()
    if enabled then return end
    DevLog("Enabling")

    if C_CVar.GetCVar("assistedCombatHighlight") ~= "1" then
        C_CVar.SetCVar("assistedCombatHighlight", "1")
    end

    enabled = true

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

    InstallHooks()

    rotationValid = false
    RebuildRotationSet()
    UpdateAll()
end

local function Disable()
    if not enabled then return end
    DevLog("Disabling")

    enabled = false
    frame:UnregisterAllEvents()
    wipe(rotationSet)
    rotationValid = false
    HideAllOverlays()
end

function RotationGlow:ApplySetting()
    if db.showRotationGlow then
        Enable()
    else
        Disable()
    end
end

function RotationGlow:Init(database)
    db = database
    if db.showRotationGlow then
        Enable()
    end
end
