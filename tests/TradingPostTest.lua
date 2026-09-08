-- luacheck: globals C_AddOns CreateFrame hooksecurefunc
-- Run from the addon root: lua tests/TradingPostTest.lua

function hooksecurefunc(object, method, hook)
    local original = object[method]
    object[method] = function(...)
        original(...)
        hook(...)
    end
end

local function Checkbox()
    return {
        shown = false,
        checked = false,
        hooks = {},
        HookScript = function(self, script, fn) self.hooks[script] = fn end,
        GetChecked = function(self) return self.checked end,
        SetChecked = function(self, value) self.checked = value end,
        IsShown = function(self) return self.shown end,
    }
end

local db = { rememberTradingPostAnimations = true }
for _, alreadyLoaded in ipairs({ false, true }) do
    local eventFrame
    C_AddOns = { IsAddOnLoaded = function() return alreadyLoaded end }
    function CreateFrame()
        eventFrame = {
            RegisterEvent = function(self, event) self.event = event end,
            UnregisterEvent = function(self) self.event = nil end,
            SetScript = function(self, _, fn) self.onEvent = fn end,
        }
        return eventFrame
    end

    local footer = { ToggleAttackAnimation = Checkbox(), ToggleMountSpecial = Checkbox() }
    local frame = { FooterFrame = footer }
    local actor = {}
    function actor:PlayAnimationKit() frame.actorMountSpecial = true end
    function actor:StopAnimationKit() frame.actorMountSpecial = false end
    function actor:SetAnimation(value) self.animation = value end
    local model = { MainModelScene = { GetActorByTag = function() return actor end } }
    frame.ModelSceneContainerFrame = model
    function model:UpdateMountSpecialAnimPlaying()
        self.timerActive = false
        if self.mountSpecialAnimPlaying then
            actor:PlayAnimationKit(1371, true)
            self.timerActive = true
        else
            -- SetAnimation changes the base pose; an active animation kit still overrides it.
            actor:SetAnimation(0)
        end
    end
    _G.PerksProgramFrame = frame
    local category, hasAnimation, attackEnabled, mountEnabled = "transmog", true, true, true

    function frame:GetAttackAnimationSetting() return self.attackAnimationPlaying end
    function frame:GetMountSpecialPreviewSetting() return self.mountSpecialAnimPlaying end
    function frame:PlayerSetAttackAnimationOnClick(value)
        local old = self.attackAnimationPlaying
        self.attackAnimationPlaying = value
        if old ~= value then
            -- Blizzard rebuilds the current model synchronously before the click hook runs.
            footer:UpdateTransmogControls(category, false)
        end
        self.actorAttacking = self.attackAnimationPlaying
    end
    function frame:SetMountSpecialPreviewOnClick(value)
        self.mountSpecialAnimPlaying = value
        model.mountSpecialAnimPlaying = value
        model:UpdateMountSpecialAnimPlaying()
    end
    function footer:UpdateTransmogControls(kind, newProduct)
        local visible = kind == "transmog" and hasAnimation and attackEnabled
        if newProduct then self.ToggleAttackAnimation.shown = visible end
        if visible then
            if newProduct then
                frame:PlayerSetAttackAnimationOnClick(true)
                self.ToggleAttackAnimation:SetChecked(true)
            else
                frame:PlayerSetAttackAnimationOnClick(frame:GetAttackAnimationSetting())
            end
        end
    end
    function footer:UpdateMountControls(kind, newProduct)
        if not newProduct then return end
        local visible = kind == "mount" and mountEnabled
        self.ToggleMountSpecial.shown = visible
        frame:SetMountSpecialPreviewOnClick(visible)
        self.ToggleMountSpecial:SetChecked(visible)
    end
    local function Select(kind)
        category = kind
        actor:StopAnimationKit()
        footer:UpdateMountControls(kind, true)
        footer:UpdateTransmogControls(kind, true)
    end
    local function Click(button, method, value)
        button:SetChecked(value)
        frame[method](frame, value)
        button.hooks.OnClick(button)
        assert(button:GetChecked() == value, "restoration must not undo a manual click")
    end

    dofile("src/features/TradingPost.lua")
    LuckyGrabbag.TradingPost:Init(db)
    if not alreadyLoaded then
        eventFrame:onEvent("ADDON_LOADED", "UnrelatedAddon")
        assert(not footer.ToggleAttackAnimation.hooks.OnClick)
        eventFrame:onEvent("ADDON_LOADED", "Blizzard_PerksProgram")
        assert(eventFrame.event == nil, "stop listening once hooks are installed")
    else
        assert(eventFrame == nil, "already-loaded UI needs no event listener")
    end

    Select("transmog")
    if not alreadyLoaded then
        assert(frame.actorAttacking == true and db.tradingPostCombatAnimation == nil,
            "leave Blizzard defaults until the user makes a choice")
    else
        assert(frame.actorAttacking == false, "combat preference survives a reload")
        Select("mount")
        assert(frame.actorMountSpecial == false, "mount preference survives a reload")
        Select("transmog")
    end

    local attack, mount = footer.ToggleAttackAnimation, footer.ToggleMountSpecial
    Click(attack, "PlayerSetAttackAnimationOnClick", false)
    Select("transmog")
    assert(frame.actorAttacking == false and attack:GetChecked() == false)
    assert(db.tradingPostCombatAnimation == false, "automatic resets must not overwrite saved choice")
    Click(attack, "PlayerSetAttackAnimationOnClick", true)
    Select("transmog")
    assert(frame.actorAttacking == true and db.tradingPostCombatAnimation == true)
    hasAnimation = false
    Select("transmog")
    assert(not attack:IsShown() and db.tradingPostCombatAnimation == true)
    hasAnimation, attackEnabled = true, false
    Select("transmog")
    assert(not attack:IsShown(), "server-disabled control must stay hidden")
    attackEnabled = true
    Select("transmog")
    Click(attack, "PlayerSetAttackAnimationOnClick", false)

    Select("mount")
    Click(mount, "SetMountSpecialPreviewOnClick", false)
    assert(frame.actorMountSpecial == false, "unchecking Mount Special must stop the running animation kit")
    assert(not model.timerActive, "unchecking must cancel the repeat timer")
    Select("mount")
    assert(frame.actorMountSpecial == false and mount:GetChecked() == false)
    Click(mount, "SetMountSpecialPreviewOnClick", true)
    mountEnabled = false
    Select("mount")
    assert(frame.actorMountSpecial == false and not mount:IsShown())
    assert(db.tradingPostMountSpecial == true, "hidden control must not erase preference")
    mountEnabled = true
    Select("mount")
    assert(frame.actorMountSpecial == true and mount:GetChecked() == true)
    Click(mount, "SetMountSpecialPreviewOnClick", false)
    Select("pet")
    Select("transmog")
    assert(frame.actorAttacking == false and not mount:IsShown())

    db.rememberTradingPostAnimations = false
    Select("transmog")
    assert(frame.actorAttacking == true, "disabled feature must leave Blizzard behavior alone")
    Click(attack, "PlayerSetAttackAnimationOnClick", true)
    Select("mount")
    assert(frame.actorMountSpecial == true)
    Click(mount, "SetMountSpecialPreviewOnClick", true)
    assert(db.tradingPostCombatAnimation == false and db.tradingPostMountSpecial == false)
    db.rememberTradingPostAnimations = true
    Select("mount")
    assert(frame.actorMountSpecial == false, "reenabling restores saved choice on next item")
end

print("TradingPostTest: passed")
