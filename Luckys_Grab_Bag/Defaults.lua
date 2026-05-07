-- Lucky's Grab-bag: Saved-variable defaults
-- Edit values here to change the out-of-box behavior for new installs.
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.DB_DEFAULTS = {
    devMode                  = false,
    autoRepair               = true,
    autoRepairUseGuildFunds  = true,
    showTreatise             = false,
    reagentMainsEnabled      = false,
    reagentMainsCurrentExpOnly = false,
    reagentExcludedAlts      = {},
    reagentMains             = {},
    reagentMainsImported     = false,
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
    showConfirmPurchase      = true,
    confirmPurchaseOnSide    = false,
    keepTransmogTab          = false,
}

LuckyGrabbag.CHAR_DB_DEFAULTS = {
    bonusRollAutoDismiss      = false,
    bonusRollKeepInMythicPlus = true,
    bonusRollKeepInRaids      = true,
    bonusRollKeepInLFR        = true,
    bonusRollKeepInNormalRaid = true,
    bonusRollKeepInHeroicRaid = true,
    bonusRollKeepInMythicRaid = true,
    bonusRollKeepInDelve      = false,
    bonusRollKeepInDungeon    = false,
    bonusRollKeepInHunts      = false,
}
