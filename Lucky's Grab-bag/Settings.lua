-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

local function AddDependencyWarning(panel, anchor, requires)
    local warning = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    warning:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 20, -2)
    warning:SetWidth(400)
    warning:SetJustifyH("LEFT")
    warning:SetTextColor(1, 0.3, 0.3)
    warning:Hide()

    panel:HookScript("OnShow", function()
        local ok, msg = LuckyGrabbag.Dependencies.Check(requires.addon, requires.minVersion)
        warning:SetShown(not ok)
        if not ok then
            warning:SetText(msg)
            anchor:Disable()
            anchor.text:SetFontObject("GameFontDisable")
        else
            anchor:Enable()
            anchor.text:SetFontObject("GameFontNormal")
        end
    end)

    return warning
end

function LuckyGrabbag.Settings:Init(db)
    local panel = CreateFrame("Frame")
    panel.name = "Lucky's Grab-bag"

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() Settings.OpenToCategory(category.ID) end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lucky's Grab-bag")

    -- Dev Mode
    local devCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    devCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    devCheck:SetChecked(db.devMode)
    devCheck.text:SetText("Dev Mode")
    devCheck:SetScript("OnClick", function(btn)
        db.devMode = btn:GetChecked()
    end)

    -- CraftSim Quickbuy toggle
    local quickbuyCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    quickbuyCheck:SetPoint("TOPLEFT", devCheck, "BOTTOMLEFT", 0, -8)
    quickbuyCheck:SetChecked(db.showQuickbuy)
    quickbuyCheck.text:SetText("Show CraftSim Quickbuy button")
    quickbuyCheck:SetScript("OnClick", function(btn)
        db.showQuickbuy = btn:GetChecked()
        db.showQuickbuyAutoDefault = false
        LuckyGrabbag.Quickbuy:ApplySetting()
    end)

    AddDependencyWarning(panel, quickbuyCheck, LuckyGrabbag.Quickbuy.requires)
end
