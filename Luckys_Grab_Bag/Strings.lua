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

    kickMacro = {
        created      = "Created 'Kick' macro using %s.",
        alreadyExists = "A macro named 'Kick' already exists.",
        slotsFull    = "Your character macro slots are full.",
        noInterrupt  = "No interrupt available for your current spec.",
    },

    reagentMains = {
        title             = "Reagent Mains",
        subtitle          = "GRAB-BAG",
        description       = "Pick which characters keep each category. Anyone not listed deposits those reagents on opening the warband bank.",
        excludedLabel     = "Excluded characters",
        excludedTooltip   = "These characters are never asked to deposit anything, regardless of category assignments. Useful for bank alts.",
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
            crafting     = "Professions",
            inventory    = "Inventory",
            combat       = "Combat",
            delves       = "Delves",
            interface    = "Interface",
        },
        sections = {
            automation  = "Automation",
            purchasing  = "Purchasing",
            wardrobe    = "Wardrobe",
            versionInfo = "Version Info",
        },
        grabbagVersion = {
            label = "Grab-bag",
        },
        luckyUtilsVersion = {
            label = "Lucky's Utils",
        },
        discord = {
            label = "Discord",
            url   = "discord.gg/87HRHcAYP",
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
            desc  = "Shows a large tick button on vendor currency, sell, 'no longer refundable', and 'bind on equip' popups, anchored on the item where possible.",
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
            label = "Withdraw Treatise from Warbank",
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
        reagentMainsCurrentExpOnly = {
            label = "Only current expansion",
            desc  = "Only deposit reagents from the current expansion. Older expansion materials stay in your bags.",
        },
        configureMains = {
            label = "Configure mains…",
            desc  = "Assign reagent categories to characters.",
        },
        warboundAutoDeposit = {
            label = "Auto-Deposit Warbound Items",
            desc  = "Deposits warbound armor, weapons, and tokens into the warband bank when you open it.",
        },
        warboundDepositArmor = {
            label = "Warbound Armor",
            desc  = "Auto-deposit warbound armor.",
        },
        warboundDepositWeapons = {
            label = "Warbound Weapons",
            desc  = "Auto-deposit warbound weapons.",
        },
        warboundDepositTokens = {
            label = "Warbound Tokens",
            desc  = "Auto-deposit warbound tokens.",
        },
        warboundDepositLumber = {
            label = "Lumber",
            desc  = "Auto-deposit lumber.",
        },
        warboundItemWhitelist = {
            label = "Custom Item Whitelist",
            desc  = "Add specific items to always auto-deposit. Use with the button below.",
        },
        configureWhitelist = {
            label = "Configure whitelist…",
            desc  = "Add or remove items from the auto-deposit whitelist.",
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
        kickMacro = {
            label = "Create Kick Macro",
            desc  = "Creates a 'Kick' macro using your class interrupt.\n\nIf you have a focus set, it interrupts that target — letting you kick a caster without switching away from your main target.\n\nWith no focus, it grabs the nearest enemy, kicks them, then clears focus so the next press does the same.",
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
        transmog = {
            label = "Keep Active Transmog Tab",
            desc  = "Keeps whichever tab you're on when switching slots at the transmog NPC, instead of jumping back to Items.",
        },
        autoTipAlt = {
            label = "1s Tip on Alt Work Orders",
            desc  = "When sending a personal work order to one of your own characters, automatically sets the tip to 1 silver.",
        },
        spendToNextPerk = {
            label = "Spend to Next Perk",
            desc  = "Clicking a profession specialisation node automatically spends knowledge points up to the next perk threshold (every 5 ranks).",
        },
        bonusRoll = {
            label = "Auto-dismiss Bonus Roll",
            desc  = "Automatically passes on the Bonus Roll popup that appears at the end of content, except in the situations selected below.",
            note  = "This is a per-character setting.",
        },
        bonusRollKeepInMythicPlus = {
            label = "Keep in Mythic+",
            desc  = "Show the Bonus Roll popup after Mythic+ runs.",
        },
        bonusRollMythicPlusMinLevel = {
            label = "Minimum key level",
            desc  = "Only keep the popup on keys at or above this level. Keys below this level are always dismissed.",
        },
        bonusRollKeepInRaids = {
            label = "Keep in Raids",
            desc  = "Show the Bonus Roll popup after raid bosses.",
        },
        bonusRollRaidDifficulties = {
            label     = "Difficulties",
            desc      = "Limit which raid difficulties keep the popup.",
            optLFR    = "Raid Finder",
            optNormal = "Normal",
            optHeroic = "Heroic",
            optMythic = "Mythic",
        },
        bonusRollKeepInDelve = {
            label = "Keep in Delves",
            desc  = "Show the Bonus Roll popup after delve completions.",
        },
        bonusRollKeepInDungeon = {
            label = "Keep in Dungeons",
            desc  = "Show the Bonus Roll popup after Normal, Heroic, and Mythic-0 dungeon runs.",
        },
        bonusRollKeepInHunts = {
            label = "Keep in Hunts",
            desc  = "Show the Bonus Roll popup after completing hunts.",
        },
    },
}
