-- Lucky's Grab-bag: User-facing strings.
-- Centralised here so wording can be tweaked without hunting through feature files.
-- Format strings use Lua's standard %s / %d placeholders; pass through string.format at the call site.
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.Strings = {
    addon = {
        title       = "Lucky's Grab-bag",
        prefix      = "|cff00cc00Lucky:|r",
        errorPrefix = "|cffff0000Lucky's Grab-bag:|r",
    },

    minimap = {
        tooltipTitle  = "Lucky's Grab-bag",
        leftClick     = "Left-click: Open settings",
        rightClick    = "Right-click: Open settings",
        middleClick   = "Middle-click: Toggle dev mode",
        shiftDrag     = "Shift+drag: Move button",
        devModePrefix = "Dev mode ",
        devModeOn     = "ON",
        devModeOff    = "OFF",
    },

    autoRepair = {
        repaired      = "Repaired all items (%s from %s)",
        guildFunds    = "guild funds",
        personalFunds = "personal funds",
    },

    treatise = {
        withdrawn = "Withdrawn %s treatise.",
    },

    auctionHouse = {
        quickbuyTooltip      = "CraftSim Quickbuy",
        testflightTooltip    = "TestFlight Buy Next",
        craftsimNotLoaded    = "CraftSim is not loaded.",
        testflightNotLoaded  = "TestFlight is not loaded.",
    },

    confirmPurchase = {
        tooltip = "Confirm Purchase",
    },

    combatPrep = {
        readyCheck   = "Ready Check",
        pullTimerFmt = "Pull %ds",
        breakTimerFmt = "Break %dm",
        cancelLabel  = "X",
    },

    reagentMains = {
        title             = "Reagent Mains",
        subtitle          = "GRAB-BAG",
        description       = "Pick which characters keep each category. Anyone not listed deposits those reagents on opening the warband bank.",
        detectButton      = "Detect Professions",
        detectTooltip     = "Re-scan the current character's professions and refresh hints.",
        headerCategory    = "Category",
        headerMain        = "Main",
        headerProfessions = "Professions",
        ddNone            = "None",
        ddAllOption       = "All (everyone keeps)",
        ddAllShort        = "All",
        ddMultiCharsFmt   = "%d characters",
    },

    -- Reagent category display names. Keys mirror LuckyGrabbag.ReagentMainsData.Categories keys.
    reagentCategories = {
        herb       = "Herbs",
        leather    = "Leather",
        cloth      = "Cloth",
        metalstone = "Metal & Stone",
        gems       = "Gems",
        enchanting = "Enchanting",
        cooking    = "Cooking",
        elemental  = "Elemental",
        crafting   = "Crafting Reagents",
        finishing  = "Finishing Reagents",
        other      = "Other",
    },

    settings = {
        groups = {
            general      = "General",
            vendors      = "Vendors",
            auctionHouse = "Auction House",
            crafting     = "Crafting",
            inventory    = "Inventory",
            combat       = "Combat",
            delves       = "Delves",
        },
        sections = {
            automation  = "Automation",
            purchasing  = "Purchasing",
            versionInfo = "Version Info",
        },
        grabbagVersion = {
            label = "Grab-bag",
        },
        luckyUtilsVersion = {
            label = "Lucky's Utils",
        },
        devMode = {
            label = "Dev Mode",
            desc  = "Development logging and diagnostics. Has no visible effect for regular users.",
        },
        minimapButton = {
            label = "Minimap Button",
            desc  = "Shows the Grab-bag button on the minimap. Shift-drag to move.",
        },
        autoRepair = {
            label = "Auto Repair",
            desc  = "Automatically repair all damaged gear when you open a vendor that can repair.",
        },
        useGuildFunds = {
            label = "Use Guild Funds",
            desc  = "Pays from the guild bank when allowed, otherwise your own gold.",
        },
        confirmPurchase = {
            label = "Easy Confirm Purchase",
            desc  = "Shows a large tick button on top of the item you clicked when a vendor currency-confirmation popup appears.",
        },
        confirmPurchaseOnSide = {
            label = "Button on Side",
            desc  = "Floats the tick button next to the vendor window instead of overlaying the clicked item. Right-click drag to move.",
        },
        quickbuy = {
            label = "CraftSim Quickbuy",
            desc  = "Adds a button next to the Auction House. Each click buys one row from your CraftSim shopping list.",
        },
        testflightBuy = {
            label = "TestFlight Buy Next",
            desc  = "Adds a button next to the Auction House that steps through Auctionator's purchase workflow — selecting, buying, and confirming each item in turn.",
        },
        treatise = {
            label = "Thalassian Treatise",
            desc  = "Withdraws unused Thalassian Treatises for your professions when you open the warband bank.",
        },
        cookingButtons = {
            label = "Cooking Utility Buttons",
            desc  = "Adds Campfire and Chef's Hat buttons next to the Cooking window.",
        },
        reagentMains = {
            label = "Reagent Mains",
            desc  = "Deposits reagents into the warband bank that belong to a different character.",
        },
        configureMains = {
            label = "Configure mains…",
            desc  = "Assign reagent categories to characters.",
        },
        useItems = {
            label = "Use Items Popup",
            desc  = "Floating buttons for Payouts, Glimmers/Flickers, and Treatises in your bags. Draggable; hides when empty.",
        },
        useItemsCityOnly = {
            label = "Only while rested",
            desc  = "Hides the popup outside rest areas.",
        },
        combatPrep = {
            label = "Combat Prep Window",
            desc  = "Pull timer and ready check buttons in raids and Mythic+. Shows out of combat. Right-click drag to move.",
        },
        combatPrepReadyCheck = {
            label = "Ready Check Button",
            desc  = "Show the ready check button on the combat prep window.",
        },
        pullTimerMythic = {
            label  = "Pull Timer (Mythic+)",
            desc   = "Pull countdown length in Mythic+.",
            suffix = "s",
        },
        pullTimerRaid = {
            label  = "Pull Timer (Raid)",
            desc   = "Pull countdown length in raids.",
            suffix = "s",
        },
        breakTimer = {
            label  = "Break Timer Duration",
            desc   = "Default break length.",
            suffix = "m",
        },
        rotationGlow = {
            label = "Rotation Glow",
            desc  = "Animates the next-cast spell on the Essential Cooldown Viewer. Enable the viewer in Edit Mode.",
        },
        delveMap = {
            label = "Trovehunter's Bounty Map",
            desc  = "Floating button to use your Trovehunter's Bounty Map when you're inside a delve that meets the minimum level. Right-click and drag to reposition.",
        },
        delveMapMinLevel = {
            label = "Minimum Delve Level",
            desc  = "Only show the Bounty Map button in delves at or above this tier.",
        },
    },
}
