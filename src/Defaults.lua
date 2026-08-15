-- Lucky's Grab-bag: Saved-variable defaults
-- Edit values here to change the out-of-box behavior for new installs.
LuckyGrabbag = LuckyGrabbag or {}

-- Settings panel: any setting flagged with a `since` version at or above this
-- gets a "NEW" badge and appears in the "What's New" list. Bump this each
-- release cycle so only recent features are highlighted.
LuckyGrabbag.WHATS_NEW_MIN_VERSION = "1.19.0"

LuckyGrabbag.DB_DEFAULTS = {
    devMode                  = false,
    autoRepair               = true,
    autoRepairUseGuildFunds  = true,
    autoSellJunk             = false,
    showTreatise             = false,
    reagentMainsEnabled      = false,
    reagentMainsCurrentExpOnly = false,
    reagentExcludedAlts      = {},
    reagentMains             = {},
    reagentMainsImported     = false,
    warboundAutoDepositEnabled = false,
    warboundDepositArmor     = false,
    warboundDepositWeapons   = false,
    warboundDepositTokens    = false,
    warboundDepositLumber    = false,
    warboundItemWhitelist    = {},
    showCookingButtons       = true,
    showUseItems             = true,
    useItemsCityOnly         = false,
    showDelveMap             = true,
    delveMapMinLevel         = 8,
    showCombatPrep           = false,
    combatPrepReadyCheck     = false,
    combatPrepTimerMythic    = 10,
    combatPrepTimerRaid      = 12,
    combatPrepBreakTimer     = 5,
    showRotationGlow         = false,
    showPIPicker             = true,
    autoCombatLog            = false,
    autoCombatLogMythicPlus  = true,
    autoCombatLogRaids       = true,
    autoCombatLogLFR         = false,
    autoCombatLogNormalRaid  = true,
    autoCombatLogHeroicRaid  = true,
    autoCombatLogMythicRaid  = true,
    autoCombatLogCurrentSeasonOnly = true,
    showConfirmPurchase      = true,
    confirmPurchaseOnSide    = false,
    -- Retired, both moved to Better Wardrobe and Transmog.
    keepTransmogTab          = false,
    trackTransmogSets        = false,
    autoTipAlt               = true,
    spendToNextPerk          = true,
    searchSelectedExpansionOnly = true,
    searchAllExpansions      = false,
    showConcentration        = true,
    showEnchantBadges        = true,
    enchantBadgesAH          = true,
    omniumFolioPerSpec       = true,
    blueprintTrackMissing    = true,
    highlightTrackedDecor    = true,
    decorAutoBuy             = false,
    decorList                = {},
}

LuckyGrabbag.CHAR_DB_DEFAULTS = {
    bonusRollAutoDismiss      = false,
    bonusRollKeepInMythicPlus = true,
    bonusRollMythicPlusMinLevel = 10,
    bonusRollKeepInRaids      = true,
    bonusRollKeepInLFR        = true,
    bonusRollKeepInNormalRaid = true,
    bonusRollKeepInHeroicRaid = true,
    bonusRollKeepInMythicRaid = true,
    bonusRollKeepInDelve      = false,
    bonusRollKeepInDungeon    = false,
    bonusRollKeepInHunts      = false,
}
