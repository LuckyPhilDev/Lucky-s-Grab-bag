-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

local function AddDependencyWarning(panel, requires)
    local anchor = panel.lastAnchor.desc or panel.lastAnchor
    local warning = panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    warning:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    warning:SetWidth(400)
    warning:SetJustifyH("LEFT")
    warning:SetTextColor(1, 0.3, 0.3)
    warning:Hide()

    panel.panel:HookScript("OnShow", function()
        local ok, msg = LuckyDeps:Check(requires.addon, requires.minVersion)
        warning:SetShown(not ok)
        if not ok then
            warning:SetText(msg)
        end
    end)

    panel.lastAnchor = warning
end

function LuckyGrabbag.Settings:Init(db)
    local panel = LuckySettings:NewPanel("Lucky's Grab-bag")
    self.category = panel.category

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() panel:Open() end

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    panel:Toggle({
        label    = "Dev Mode",
        desc     = "Development logging and diagnostics.",
        tooltip  = "Enables verbose debug output via LuckyLog. Has no visible effect for regular users.",
        checked  = db.devMode,
        gap      = 16,
        onToggle = function(checked) db.devMode = checked end,
    })

    local minimapState = db.minimap or {}
    panel:Toggle({
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
    -- Auto Repair
    ---------------------------------------------------------------------------
    panel:Section("Auto Repair")

    panel:Toggle({
        label    = "Auto Repair",
        desc     = "Automatically repair your gear when visiting a repair vendor.",
        tooltip  = "When you open a vendor that can repair, all damaged gear is repaired automatically.",
        checked  = db.autoRepair,
        onToggle = function(checked) db.autoRepair = checked end,
    })

    panel:Toggle({
        label    = "Use Guild Funds",
        desc     = "Prefer guild bank funds when repairing, if available.",
        tooltip  = "Repair costs are paid from the guild bank if your guild allows it. Falls back to your own gold if guild repair isn't available.",
        checked  = db.autoRepairUseGuildFunds,
        indent   = 20,
        onToggle = function(checked) db.autoRepairUseGuildFunds = checked end,
    })

    ---------------------------------------------------------------------------
    -- Auctionator Enhancements
    ---------------------------------------------------------------------------
    panel:Section("Auctionator Enhancements")

    panel:Toggle({
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

    AddDependencyWarning(panel, LuckyGrabbag.Quickbuy.requires)

    panel:Toggle({
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

    AddDependencyWarning(panel, LuckyGrabbag.TestflightBuy.requires)

    ---------------------------------------------------------------------------
    -- Professions
    ---------------------------------------------------------------------------
    panel:Section("Professions")

    panel:Toggle({
        label    = "Thalassian Treatise Auto-Withdrawal",
        desc     = "Withdraws unread treatises from Warband Bank when opened.",
        tooltip  = "When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.",
        checked  = db.showTreatise,
        onToggle = function(checked) db.showTreatise = checked end,
    })

    panel:Toggle({
        label    = "Use Items Popup",
        desc     = "Floating buttons for consumable profession items in your bags.",
        tooltip  = "Shows buttons for Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, and Thalassian Treatises. Draggable, auto-hides when empty, respects combat lockdown.",
        checked  = db.showUseItems,
        onToggle = function(checked)
            db.showUseItems = checked
            LuckyGrabbag.UseItems:ApplySetting()
        end,
    })

    panel:Toggle({
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

    panel:Toggle({
        label    = "Cooking Utility Buttons",
        desc     = "Campfire and Chef's Hat buttons on the Cooking window.",
        tooltip  = "Adds a Campfire button (casts Basic Campfire) and a Chef's Hat toggle (glows when active, click again to cancel) alongside the Cooking profession window.",
        checked  = db.showCookingButtons,
        onToggle = function(checked) db.showCookingButtons = checked end,
    })

    ---------------------------------------------------------------------------
    -- Delves
    ---------------------------------------------------------------------------
    panel:Section("Delves")

    panel:Toggle({
        label    = "Trovehunter's Bounty Map",
        desc     = "Shows a clickable button for your Bounty Map when in a qualifying delve.",
        tooltip  = "Displays a floating button to use your Trovehunter's Bounty Map when you're inside a delve that meets the minimum level. Right-click and drag to reposition.",
        checked  = db.showDelveMap,
        onToggle = function(checked)
            db.showDelveMap = checked
            LuckyGrabbag.DelveMap:ApplySetting()
        end,
    })

    panel:Slider({
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
    panel:Section("Combat Prep")

    panel:Toggle({
        label    = "Combat Prep Window",
        desc     = "Shows a floating window with pull timer and ready check buttons.",
        tooltip  = "Displays a small window when you're out of combat in a raid or Mythic+ dungeon. Right-click and drag to reposition.",
        checked  = db.showCombatPrep,
        onToggle = function(checked)
            db.showCombatPrep = checked
            LuckyGrabbag.CombatPrep:ApplySetting()
        end,
    })

    panel:Toggle({
        label    = "Ready Check Button",
        desc     = "Show the ready check button on the combat prep window.",
        checked  = db.combatPrepReadyCheck,
        indent   = 20,
        onToggle = function(checked)
            db.combatPrepReadyCheck = checked
            LuckyGrabbag.CombatPrep:ApplySetting()
        end,
    })

    panel:Slider({
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

    panel:Slider({
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

    ---------------------------------------------------------------------------
    -- Rotation Glow
    ---------------------------------------------------------------------------
    panel:Section("Rotation Glow")

    panel:Toggle({
        label    = "Rotation Glow",
        desc     = "Animates the suggested next-cast spell on the Essential Cooldown Viewer.",
        tooltip  = "Uses Blizzard's assisted combat data to highlight the icon matching the suggested next cast. Requires the Essential Cooldown Viewer to be enabled in Edit Mode.",
        checked  = db.showRotationGlow,
        onToggle = function(checked)
            db.showRotationGlow = checked
            LuckyGrabbag.RotationGlow:ApplySetting()
        end,
    })
end
