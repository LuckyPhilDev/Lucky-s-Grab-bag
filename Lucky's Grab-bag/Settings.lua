-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

function LuckyGrabbag.Settings:Init(db)
    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() Settings.OpenToCategory(category.ID) end

    local panel = CreateFrame("Frame")
    panel.name = "Lucky's Grab-bag"

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)

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
        LuckyGrabbag.Quickbuy:ApplySetting()
    end)
end
