-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

local function AddDependencyWarning(content, check, requires)
    local warning = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    warning:SetPoint("TOPLEFT", check.desc, "BOTTOMLEFT", 0, -2)
    warning:SetWidth(400)
    warning:SetJustifyH("LEFT")
    warning:SetTextColor(1, 0.3, 0.3)
    warning:Hide()

    content:GetParent():GetParent():HookScript("OnShow", function()
        local ok, msg = LuckyDeps:Check(requires.addon, requires.minVersion)
        warning:SetShown(not ok)
        if not ok then
            warning:SetText(msg)
            check:Disable()
            check.text:SetFontObject("GameFontDisable")
        else
            check:Enable()
            check.text:SetFontObject("GameFontNormal")
        end
    end)

    return warning
end

-- Adds a group heading with a horizontal rule that extends from the text to the right edge.
-- Returns the heading so the next element can anchor to it.
local function AddGroupHeading(content, prevAnchor, text)
    local anchor = prevAnchor.desc or prevAnchor
    local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("LEFT", content, "LEFT", 16, 0)
    heading:SetPoint("TOP", anchor, "BOTTOM", 0, -20)
    heading:SetTextColor(0.79, 0.66, 0.30) -- gold-accent
    heading:SetText(text)

    local rule = content:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", heading, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    rule:SetColorTexture(0.23, 0.18, 0.10) -- section divider (#3a2e1a)

    return heading
end

-- Adds a checkbox with a short description underneath.
-- Hovering the checkbox shows the full tooltip.
-- Returns the checkbox (use as anchor for the next item).
local function AddFeatureToggle(content, prevAnchor, opts)
    local anchor = prevAnchor.desc or prevAnchor
    local leftInset = 16 + (opts.indent or 0)
    local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    check:SetPoint("LEFT", content, "LEFT", leftInset, 0)
    check:SetPoint("TOP", anchor, "BOTTOM", 0, -(opts.gap or 8))
    check:SetChecked(opts.checked)
    check.text:SetText(opts.label)
    check:SetScript("OnClick", function(btn)
        opts.onToggle(btn:GetChecked())
    end)

    if opts.tooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(opts.label, 1, 1, 1)
            GameTooltip:AddLine(opts.tooltip, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 26, -2)
    desc:SetWidth(400)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.54, 0.49, 0.42) -- text-muted
    desc:SetText(opts.desc)

    check.desc = desc
    return check
end

-- Adds a labeled slider with a value readout.
-- Returns the slider frame (use .desc for anchoring the next item).
local function AddSlider(content, prevAnchor, opts)
    local anchor = prevAnchor.desc or prevAnchor
    local leftInset = 16 + (opts.indent or 0)

    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", content, "LEFT", leftInset, 0)
    label:SetPoint("TOP", anchor, "BOTTOM", 0, -(opts.gap or 12))
    label:SetText(opts.label)

    local slider = CreateFrame("Slider", "LGB_Slider_" .. opts.key, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -14)
    slider:SetWidth(opts.width or 160)
    slider:SetMinMaxValues(opts.min, opts.max)
    slider:SetValueStep(opts.step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(opts.value)
    slider.Low:SetText(opts.min)
    slider.High:SetText(opts.max)

    local valueText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetText(opts.value .. (opts.suffix or ""))

    slider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val + 0.5)
        valueText:SetText(val .. (opts.suffix or ""))
        opts.onChanged(val)
    end)

    -- Invisible anchor region below the slider for consistent spacing
    local spacer = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    spacer:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)
    spacer:SetText("")
    slider.desc = spacer

    return slider
end

local function CreateScrollFrame(panel)
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 500)
    scrollFrame:SetScrollChild(content)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)

    return scrollFrame, content
end

-- Update content height to fit all children so the scroll range is correct.
local function UpdateContentHeight(content)
    local bottom = 0
    for _, child in pairs({ content:GetRegions() }) do
        local _, _, _, _, y = child:GetPoint()
        if y then
            local childBottom = -y + (child.GetHeight and child:GetHeight() or 0)
            if childBottom > bottom then bottom = childBottom end
        end
    end
    for _, child in pairs({ content:GetChildren() }) do
        local _, _, _, _, y = child:GetPoint()
        if y then
            local childBottom = -y + child:GetHeight()
            if childBottom > bottom then bottom = childBottom end
        end
    end
    content:SetHeight(bottom + 24)
end

function LuckyGrabbag.Settings:Init(db)
    local panel = CreateFrame("Frame")
    panel.name = "Lucky's Grab-bag"

    local category = LuckySettings:Register(panel, panel.name)
    LuckyGrabbag.Settings.category = category

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() LuckySettings:Open(category) end

    local scrollFrame, content = CreateScrollFrame(panel)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lucky's Grab-bag")

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    local devCheck = AddFeatureToggle(content, title, {
        label    = "Dev Mode",
        desc     = "Development logging and diagnostics.",
        tooltip  = "Enables verbose debug output via LuckyLog. Has no visible effect for regular users.",
        checked  = db.devMode,
        gap      = 16,
        onToggle = function(checked) db.devMode = checked end,
    })

    local minimapState = db.minimap or {}
    local minimapCheck = AddFeatureToggle(content, devCheck, {
        label    = "Minimap Button",
        desc     = "Show the Lucky's Grab-bag button on the minimap.",
        tooltip  = "Toggle the minimap button. Shift-drag to reposition it.",
        checked  = not minimapState.hide,
        onToggle = function(checked)
            if LuckyGrabbag.minimapButton then
                LuckyGrabbag.minimapButton:SetShown_Persisted(checked)
            end
        end,
    })

    ---------------------------------------------------------------------------
    -- Auctionator Enhancements
    ---------------------------------------------------------------------------
    local ahHeading = AddGroupHeading(content, minimapCheck, "Auctionator Enhancements")

    local quickbuyCheck = AddFeatureToggle(content, ahHeading, {
        label    = "CraftSim Quickbuy",
        desc     = "One-click purchasing from your CraftSim shopping list.",
        tooltip  = "Adds a button next to the Auction House window. Each click purchases one row of items from your CraftSim crafting queue's shopping list.",
        checked  = db.showQuickbuy,

        onToggle = function(checked)
            db.showQuickbuy = checked
            db.showQuickbuyAutoDefault = false
            LuckyGrabbag.Quickbuy:ApplySetting()
        end,
    })

    AddDependencyWarning(content, quickbuyCheck, LuckyGrabbag.Quickbuy.requires)

    local tfBuyCheck = AddFeatureToggle(content, quickbuyCheck, {
        label    = "TestFlight Buy Next",
        desc     = "Step through Auctionator purchases one click at a time.",
        tooltip  = "Adds a button next to the Auction House window. Each click advances through Auctionator's purchase workflow — selecting the next item, buying it, and confirming — to quickly buy all items on a shopping list.",
        checked  = db.showTestflightBuy,

        onToggle = function(checked)
            db.showTestflightBuy = checked
            db.showTestflightBuyAutoDefault = false
            LuckyGrabbag.TestflightBuy:ApplySetting()
        end,
    })

    AddDependencyWarning(content, tfBuyCheck, LuckyGrabbag.TestflightBuy.requires)

    ---------------------------------------------------------------------------
    -- Professions
    ---------------------------------------------------------------------------
    local profHeading = AddGroupHeading(content, tfBuyCheck, "Professions")

    local treatiseCheck = AddFeatureToggle(content, profHeading, {
        label    = "Thalassian Treatise Auto-Withdrawal",
        desc     = "Withdraws unread treatises from Warband Bank when opened.",
        tooltip  = "When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.",
        checked  = db.showTreatise,

        onToggle = function(checked) db.showTreatise = checked end,
    })

    local useItemsCheck = AddFeatureToggle(content, treatiseCheck, {
        label    = "Use Items Popup",
        desc     = "Floating buttons for consumable profession items in your bags.",
        tooltip  = "Shows buttons for Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, and Thalassian Treatises. Draggable, auto-hides when empty, respects combat lockdown.",
        checked  = db.showUseItems,

        onToggle = function(checked)
            db.showUseItems = checked
            LuckyGrabbag.UseItems:ApplySetting()
        end,
    })

    local cityOnlyCheck = AddFeatureToggle(content, useItemsCheck, {
        label    = "Only in Cities",
        desc     = "Buttons only appear while in a city or inn.",
        tooltip  = "When enabled, the Use Items popup is hidden outside of rest areas (cities and inns).",
        checked  = db.useItemsCityOnly,
        indent   = 20,

        onToggle = function(checked)
            db.useItemsCityOnly = checked
            LuckyGrabbag.UseItems:ApplySetting()
        end,
    })

    local cookingCheck = AddFeatureToggle(content, cityOnlyCheck, {
        label    = "Cooking Utility Buttons",
        desc     = "Campfire and Chef's Hat buttons on the Cooking window.",
        tooltip  = "Adds a Campfire button (casts Basic Campfire) and a Chef's Hat toggle (glows when active, click again to cancel) alongside the Cooking profession window.",
        checked  = db.showCookingButtons,

        onToggle = function(checked) db.showCookingButtons = checked end,
    })

    ---------------------------------------------------------------------------
    -- Delves
    ---------------------------------------------------------------------------
    local delveHeading = AddGroupHeading(content, cookingCheck, "Delves")

    local delveMapCheck = AddFeatureToggle(content, delveHeading, {
        label    = "Trovehunter's Bounty Map",
        desc     = "Shows a clickable button for your Bounty Map when in a qualifying delve.",
        tooltip  = "Displays a floating button to use your Trovehunter's Bounty Map when you're inside a delve that meets the minimum level. Right-click and drag to reposition.",
        checked  = db.showDelveMap,

        onToggle = function(checked)
            db.showDelveMap = checked
            LuckyGrabbag.DelveMap:ApplySetting()
        end,
    })

    local delveMinSlider = AddSlider(content, delveMapCheck, {
        label    = "Minimum Delve Level",
        key      = "DelveMapMinLevel",
        min      = 1,
        max      = 11,
        value    = db.delveMapMinLevel,
        indent   = 20,

        onChanged = function(val)
            db.delveMapMinLevel = val
            LuckyGrabbag.DelveMap:ApplySetting()
        end,
    })

    ---------------------------------------------------------------------------
    -- Combat Prep
    ---------------------------------------------------------------------------
    local combatPrepHeading = AddGroupHeading(content, delveMinSlider, "Combat Prep")

    local combatPrepCheck = AddFeatureToggle(content, combatPrepHeading, {
        label    = "Combat Prep Window",
        desc     = "Shows a floating window with pull timer and ready check buttons.",
        tooltip  = "Displays a small window when you're out of combat in a raid or Mythic+ dungeon. Right-click and drag to reposition.",
        checked  = db.showCombatPrep,

        onToggle = function(checked)
            db.showCombatPrep = checked
            LuckyGrabbag.CombatPrep:ApplySetting()
        end,
    })

    local readyCheckToggle = AddFeatureToggle(content, combatPrepCheck, {
        label    = "Ready Check Button",
        desc     = "Show the ready check button on the combat prep window.",
        checked  = db.combatPrepReadyCheck,
        indent   = 20,

        onToggle = function(checked)
            db.combatPrepReadyCheck = checked
            LuckyGrabbag.CombatPrep:ApplySetting()
        end,
    })

    local timerSlider = AddSlider(content, readyCheckToggle, {
        label    = "Pull Timer Duration",
        key      = "CombatPrepTimer",
        min      = 3,
        max      = 30,
        value    = db.combatPrepTimer,
        suffix   = "s",
        indent   = 20,

        onChanged = function(val)
            db.combatPrepTimer = val
            LuckyGrabbag.CombatPrep:ApplySetting()
        end,
    })

    local breakSlider = AddSlider(content, timerSlider, {
        label    = "Break Timer Duration",
        key      = "CombatPrepBreakTimer",
        min      = 1,
        max      = 15,
        value    = db.combatPrepBreakTimer,
        suffix   = "m",
        indent   = 20,

        onChanged = function(val)
            db.combatPrepBreakTimer = val
            LuckyGrabbag.CombatPrep:ApplySetting()
        end,
    })

    panel:HookScript("OnShow", function()
        UpdateContentHeight(content)
    end)
end
