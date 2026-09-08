LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.TradingPost = {}

local db

local function InstallHooks()
    local frame = _G.PerksProgramFrame
    local footer = frame.FooterFrame

    hooksecurefunc(frame.ModelSceneContainerFrame, "UpdateMountSpecialAnimPlaying", function(self)
        if not db.rememberTradingPostAnimations or self.mountSpecialAnimPlaying then return end
        if not footer.ToggleMountSpecial:IsShown() then return end
        local actor = self.MainModelScene:GetActorByTag("mount")
        -- Blizzard sets the idle pose but leaves the looping animation kit running over it.
        if actor then actor:StopAnimationKit() end
    end)

    footer.ToggleAttackAnimation:HookScript("OnClick", function(button)
        if db.rememberTradingPostAnimations then
            db.tradingPostCombatAnimation = button:GetChecked()
        end
    end)
    footer.ToggleMountSpecial:HookScript("OnClick", function(button)
        if db.rememberTradingPostAnimations then
            db.tradingPostMountSpecial = button:GetChecked()
        end
    end)

    hooksecurefunc(footer, "UpdateTransmogControls", function(self, _, newProduct)
        local saved = db.tradingPostCombatAnimation
        if not db.rememberTradingPostAnimations or saved == nil or not newProduct then return end
        if not self.ToggleAttackAnimation:IsShown() then return end

        -- Same-item refreshes also run during a click, before its new choice is saved.
        if frame:GetAttackAnimationSetting() ~= saved then
            frame:PlayerSetAttackAnimationOnClick(saved)
        end
        self.ToggleAttackAnimation:SetChecked(saved)
    end)
    hooksecurefunc(footer, "UpdateMountControls", function(self, _, newProduct)
        local saved = db.tradingPostMountSpecial
        if not db.rememberTradingPostAnimations or saved == nil or not newProduct then return end
        if not self.ToggleMountSpecial:IsShown() then return end

        if frame:GetMountSpecialPreviewSetting() ~= saved then
            frame:SetMountSpecialPreviewOnClick(saved)
        end
        self.ToggleMountSpecial:SetChecked(saved)
    end)
end

function LuckyGrabbag.TradingPost:Init(database)
    db = database
    if C_AddOns.IsAddOnLoaded("Blizzard_PerksProgram") then
        InstallHooks()
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= "Blizzard_PerksProgram" then return end
        self:UnregisterEvent("ADDON_LOADED")
        InstallHooks()
    end)
end
