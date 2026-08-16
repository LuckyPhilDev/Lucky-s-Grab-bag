-- Lucky's Grab-bag: User-facing strings.
-- Centralised here so wording can be tweaked without hunting through feature files.
-- Format strings use Lua's standard %s / %d placeholders; pass through string.format at the call site.
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.Strings = {
    addon = {
        title       = "Lucky's Grab-bag",
        prefix      = "|cff00cc00Lucky's Grab-bag:|r",
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

    autoSellJunk = {
        soldOne  = "Sold 1 junk item for %s.",
        soldMany = "Sold %d junk items for %s.",
    },

    treatise = {
        withdrawn = "Withdrawn %s treatise.",
    },

    recipeSearchFilter = {
        allExpansions = "All Expansions",
    },

    concentrationView = {
        barLabel        = "Concentration",
        tooltipCurrent  = "Concentration: %d / %d",
        tooltipRecharge = "Full in %s",
        tooltipFull     = "Full",
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

    transmogSets = {
        trackedOne     = "Now tracking %d appearance from %s.",
        trackedMany    = "Now tracking %d appearances from %s.",
        nothingToTrack = "Nothing new to track from %s.",
        skippedSuffix  = "%d could not be tracked.",
        trackedItem    = "Now tracking %s.",
        itemAlready    = "%s is already collected or being tracked.",
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

    powerInfusion = {
        title        = "POWER INFUSION",
        currentFmt   = "Casts on: %s",
        noTarget     = "nobody yet",
        notInGroup   = "Join a party or raid to pick a target.",
        targetSet    = "Power Infusion macro now casts on %s.",
        macroCreated = "Created the 'PI' macro and picked it up. Drop it onto your action bar.",
        slotsFull    = "Your macro slots are full. Free a slot and pick a target again.",
        inCombat     = "Cannot update macros during combat.",
        targetsLabel = "Targets",
        gainHeader   = "DPS gain from Power Infusion:",
        target1      = "Single target",
        target3      = "3 targets",
        target5      = "5 targets",
        recStrong    = "Strong Power Infusion target",
        recGood      = "Good Power Infusion target",
    },

    autoCombatLog = {
        started = "Combat logging on (%s).",
        stopped = "Combat logging off.",
    },

    omniumFolio = {
        restored      = "Restored Omnium Folio runes for %s: %s",
        restoreFailed = "Could not restore your Omnium Folio runes. Open the Omnium Folio and set them manually.",
        unknownRune   = "Unknown rune",
    },

    decorTracking = {
        trackMissing        = "Track Missing",
        trackMissingTooltip = "Adds every decor piece this blueprint is missing to your decor shopping list, however many that is.",
        addedOne            = "1 decor piece added to your shopping list.",
        addedMany           = "%d decor pieces added to your shopping list.",
        raisedCounts        = "Raised the count on %d pieces already on your shopping list.",
        nothingMissing      = "Nothing missing to add, your shopping list already covers this blueprint.",

        listTitle           = "Decor Shopping List",
        listSubtitle        = "GRAB-BAG",
        listDescription     = "Decor you are short of. Available counts what a blueprint can use, so copies already placed in a house or dyed do not count. Any vendor selling one of these is flagged for you.",
        listEmpty           = "Nothing on the list yet. Open a blueprint's item list and press Track Missing.",
        headerDecor         = "Decor",
        headerAvailable     = "Available",
        clearAll            = "Clear All",
        clearCollected      = "Clear Collected",
        unknownDecor        = "Unknown decor",
        pinTooltipTitle     = "Find this piece",
        pinTooltip          = "Click to open the map where it can be found, and point the waypoint arrow at it. Blizzard's tracker holds 15 pieces at a time.",
        pinUntrackTooltip   = "Right-click to take it out of Blizzard's tracker.",
        locationPending     = "Still looking up where that comes from, try again in a moment.",
        locationUnknown     = "No known location for that piece.",
        blizzardFull        = "Blizzard's tracker is full at %d. Take something out of it first.",
        blizzardUntrackable = "Blizzard has no source to point you at for that piece.",

        vendorBuyHint       = "Alt-right-click to buy the %d you still need.",
        buyAll              = "Buy All Needed",
        buyAllWithCost      = "Buy All Needed (%s)",
        buyAllTooltip       = "Buys everything this vendor stocks that is on your shopping list, in the amounts you are short of. Right-click and drag to move this button.",
        buyAllConfirm       = "Buy %d decor pieces for %s?",
        buyAllOtherCost     = "Some are paid for with currency or items on top of that.",
        buying              = "Buying %d x %s.",
        cannotAfford        = "You cannot afford even one of those.",
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

    mailSendAll = {
        bindingName     = "Send a whole Baganator category",
        notAtMailbox    = "Open the Send Mail tab at a mailbox first.",
        noCategory      = "Right-click a Baganator category at the mailbox first, then press the key.",
        categoryChanged = "That Baganator category is no longer on screen. Right-click it again.",
        noRecipient     = "Type a recipient in the To field first.",
        nothingToSend   = "Nothing in that category to send.",
        inCombat        = "Mail cannot be sent in combat.",
        defaultSubject  = "Items",
        finished        = "Sent %d mails.",
        cancelled       = "Stopped after %d mails.",
        interrupted     = "Stopped after %d mails.",
        timedOut        = "That mail did not send, so the rest were left in your bags.",
        hitLimit        = "Stopped at the %d mail limit. Press the key again to carry on.",
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
            housing      = "Housing",
            interface    = "Interface",
        },
        sections = {
            automation  = "Automation",
            purchasing  = "Purchasing",
            tooltips    = "Tooltips",
            wardrobe    = "Wardrobe",
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
        autoSellJunk = {
            label = "Auto Sell Junk",
            desc  = "Automatically sells grey-quality junk items when you open a vendor, and reports the total earned in chat.",
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
        mailSendAll = {
            label = "Send a whole category by mail",
            desc  = "Right-clicking a Baganator category at the mailbox loads 12 items into the post, which is one mail's worth. Bind a key under Key Bindings, Lucky's Grab-bag, and it keeps refilling and sending until the category is empty. Right-click the category, type a recipient, then press the key. Alt-M is free on a default setup. Press Escape after typing the recipient, otherwise the To field swallows the key.",
        },
        combatPrep = {
            label = "Combat Prep Window",
            desc  = "Pull timer and ready check buttons in dungeons, raids, and grouped scenarios such as delves. Shows out of combat. Right-click drag to move.",
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
            desc   = "Default break length. When DBM or BigWigs is installed, the break is sent through it so your whole group sees the timer. Otherwise a standard countdown is used.",
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
        omniumFolio = {
            label = "Per-Spec Omnium Folio Runes",
            desc  = "Remembers your Omnium Folio rune choices for each specialization and restores them when you switch specs. A chat message shows which runes were swapped back.",
        },
        piPicker = {
            label = "Power Infusion Picker",
            desc  = "For priests: shows a window in dungeons, raids, and grouped scenarios such as delves to pick who receives your Power Infusion. Clicking a name updates a 'PI' macro that casts Power Infusion on that player. Drag the macro to your action bar once, then pick new targets any time. Right-click drag to move the window. Players who gain the most from it are starred.",
        },
        autoCombatLog = {
            label = "Auto Combat Logging",
            desc  = "Starts combat logging when you enter the raid or Mythic+ content selected below, and stops it when you leave. Your log file is ready for Warcraft Logs without ever typing /combatlog.",
        },
        autoCombatLogMythicPlus = {
            label = "Log Mythic+",
            desc  = "Start logging when a Mythic+ keystone run begins.",
        },
        autoCombatLogRaids = {
            label = "Log Raids",
            desc  = "Start logging when you enter a raid at one of the selected difficulties.",
        },
        autoCombatLogRaidDifficulties = {
            label     = "Difficulties",
            desc      = "Limit which raid difficulties start logging.",
            optLFR    = "Raid Finder",
            optNormal = "Normal",
            optHeroic = "Heroic",
            optMythic = "Mythic",
        },
        autoCombatLogCurrentSeason = {
            label = "Current Season Only",
            desc  = "Only log raids from the current raid tier. Older raids never start logging. Mythic+ keys are always current content.",
        },
        delveMap = {
            label = "Trovehunter's Bounty Map",
            desc  = "Floating button to use your Trovehunter's Bounty Map when you're inside a delve that meets the minimum level. Right-click and drag to reposition.",
        },
        delveMapMinLevel = {
            label = "Minimum Delve Level",
            desc  = "Only show the Bounty Map button in delves at or above this tier.",
        },
        blueprintTrackMissing = {
            label = "Track Missing Decor Button",
            desc  = "Adds a Track Missing button to a blueprint's item list. It puts every decor piece you are short of onto your shopping list, with the number the blueprint wants.",
        },
        highlightTrackedDecor = {
            label = "Flag Shopping List Decor at Vendors",
            desc  = "Puts a green glow and the number you still need on any vendor item that grants a decor piece from your shopping list.",
        },
        decorAutoBuy = {
            label = "Alt-Right-Click to Buy What You Need",
            desc  = "Alt-right-click a flagged vendor item and it buys the number you are still short of, in one go. Off by default, since it spends your gold without a confirmation.",
        },
        openDecorList = {
            label = "Open Shopping List",
            desc  = "Opens the decor shopping list, where you can see what each piece needs, drop pieces you no longer want, and send one to Blizzard's tracker for a map pin. Also available as /grabbag decor.",
        },
        alwaysCompareItems = {
            label = "Always Compare Items",
            desc  = "Shows the comparison tooltip beside gear you hover over. Turn it off to see comparisons only while holding Shift. This is a game setting, so it applies to every character and stays put if you disable the addon.",
        },
        transmog = {
            label = "Keep Active Transmog Tab",
            desc  = "Keeps whichever tab you're on when switching outfits at the transmog NPC, instead of jumping back to Items. Clicking a slot still opens Items.",
            note  = "This has moved to Lucky's Wardrobe, which now handles it natively. The setting here is turned off and no longer does anything.",
        },
        trackTransmogSets = {
            label = "Shift-Click Set Tracking",
            desc  = "Shift-click a set on the Appearances Sets tab to track every appearance you are still missing from it, just like shift-clicking an item on the Items tab.",
            note  = "This has moved to Lucky's Wardrobe, which now handles it natively. The setting here is turned off and no longer does anything.",
        },
        autoTipAlt = {
            label = "1s Tip on Alt Work Orders",
            desc  = "When sending a personal work order to one of your own characters, automatically sets the tip to 1 silver.",
        },
        spendToNextPerk = {
            label = "Spend to Next Perk",
            desc  = "Clicking a profession specialisation node automatically spends knowledge points up to the next perk threshold (every 5 ranks).",
        },
        recipeSearchFilter = {
            label = "Search Selected Expansion Only",
            desc  = "When searching recipes, only shows results from the expansion selected in the Filter dropdown. An All Expansions option at the top of that list searches everything at once, which is Blizzard's normal behaviour.",
        },
        concentrationView = {
            label = "Concentration on Profession Book",
            desc  = "Adds a Concentration bar above each profession's skill bar in the Profession Book, so you can see your Concentration for both at a glance without opening each one.",
        },
        enchantBadges = {
            label = "Stat Badges",
            desc  = "Marks enchants, missives and gems with their stat so you can tell them apart at a glance: H haste, C crit, M mastery, V versatility, Sp speed, Le leech, Av avoidance. Two-stat items show both, like Crit and Haste as 'C&H'. On a gem the bigger stat is upper case and the smaller is lower case, like 'H&c'. A '+' means the pricier, higher-stat version of an enchant. Bag badges work with the default Blizzard bags and Baganator. Other bag addons may not show them.",
        },
        enchantBadgesAH = {
            label = "Also tag the Auction House",
            desc  = "Shows the same stat tag next to item names in the Auction House browse list.",
        },
        bonusRoll = {
            label = "Auto-dismiss Bonus Roll",
            desc  = "Automatically passes on the Bonus Roll popup that appears at the end of content, except in the situations selected below.",
            note  = "Turned off while it's tested against the new content, so nothing is dismissed for now. It will be back in a coming update.",
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
