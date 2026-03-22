-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

local function AddDependencyWarning(panel, posAnchor, controlAnchor, requires)
    local warning = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    warning:SetPoint("TOPLEFT", posAnchor, "BOTTOMLEFT", 0, -4)
    warning:SetWidth(420)
    warning:SetJustifyH("LEFT")
    warning:SetTextColor(1, 0.3, 0.3)
    warning:Hide()

    panel:HookScript("OnShow", function()
        local ok, msg = LuckyGrabbag.Dependencies.Check(requires.addon, requires.minVersion)
        warning:SetShown(not ok)
        if not ok then
            warning:SetText(msg)
            controlAnchor:Disable()
            controlAnchor.text:SetFontObject("GameFontDisable")
        else
            controlAnchor:Enable()
            controlAnchor.text:SetFontObject("GameFontNormal")
        end
    end)

    return warning
end

-- Adds a labelled section with a heading, checkbox, and descriptive blurb.
-- Returns the checkbox and blurb so callers can anchor the next section to the blurb.
local function AddFeatureSection(panel, prevAnchor, opts)
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("LEFT", panel, "LEFT", 16, 0)
    heading:SetPoint("TOP", prevAnchor, "BOTTOM", 0, -24)
    heading:SetText(opts.heading)

    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    check:SetChecked(opts.checked)
    check.text:SetText(opts.checkLabel)
    check:SetScript("OnClick", function(btn)
        opts.onToggle(btn:GetChecked())
    end)

    local blurb = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    blurb:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 20, -4)
    blurb:SetWidth(420)
    blurb:SetJustifyH("LEFT")
    blurb:SetTextColor(0.7, 0.7, 0.7)
    blurb:SetText(opts.blurb)

    return check, blurb
end

function LuckyGrabbag.Settings:Init(db)
    local panel = CreateFrame("Frame")
    panel.name = "Lucky's Grab-bag"

    local category = LuckySettings:Register(panel, panel.name)

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() LuckySettings:Open(category) end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lucky's Grab-bag")

    -- Dev Mode
    local _, devBlurb = AddFeatureSection(panel, title, {
        heading    = "Developer Tools",
        checkLabel = "Enable Dev Mode",
        blurb      = "Enables development-only logging and diagnostics. Has no visible effect for regular users.",
        checked    = db.devMode,
        onToggle   = function(checked) db.devMode = checked end,
    })

    -- CraftSim Quickbuy
    local quickbuyCheck, quickbuyBlurb = AddFeatureSection(panel, devBlurb, {
        heading    = "CraftSim Quickbuy",
        checkLabel = "Show Quickbuy button",
        blurb      = "Places a shortcut button next to the Auction House window. Each click purchases one row of items from your CraftSim crafting queue's shopping list.",
        checked    = db.showQuickbuy,
        onToggle   = function(checked)
            db.showQuickbuy = checked
            db.showQuickbuyAutoDefault = false
            LuckyGrabbag.Quickbuy:ApplySetting()
        end,
    })

    AddDependencyWarning(panel, quickbuyBlurb, quickbuyCheck, LuckyGrabbag.Quickbuy.requires)

    -- Thalassian Treatises
    local _, treatiseBlurb = AddFeatureSection(panel, quickbuyBlurb, {
        heading    = "Thalassian Treatises",
        checkLabel = "Auto-withdraw treatises from Warband Bank",
        blurb      = "When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.",
        checked    = db.showTreatise,
        onToggle   = function(checked) db.showTreatise = checked end,
    })

    -- Use Items
    local _, useItemsBlurb = AddFeatureSection(panel, treatiseBlurb, {
        heading    = "Use Items",
        checkLabel = "Show use-item buttons",
        blurb      = "Displays a floating row of buttons when you have consumable profession items in your bags (Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, Thalassian Treatises). Click each button to use the item. The bar is draggable and hides automatically when empty.",
        checked    = db.showUseItems,
        onToggle   = function(checked)
            db.showUseItems = checked
            LuckyGrabbag.UseItems:ApplySetting()
        end,
    })

    -- Cooking Buttons
    AddFeatureSection(panel, useItemsBlurb, {
        heading    = "Cooking",
        checkLabel = "Show cooking utility buttons",
        blurb      = "Adds a Campfire button and a Chef's Hat toggle button alongside the Cooking profession window. The Chef's Hat button glows when the buff is active; clicking it again cancels the buff.",
        checked    = db.showCookingButtons,
        onToggle   = function(checked) db.showCookingButtons = checked end,
    })
end
