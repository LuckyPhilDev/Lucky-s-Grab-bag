-- Lucky's Grab-bag: Saved-variable defaults
-- Edit values here to change the out-of-box behavior for new installs.
LuckyGrabbag = LuckyGrabbag or {}

local ADDON_NAME = ...

-- Settings panel: any setting flagged with a `since` version at or above this
-- gets a "NEW" badge and appears in the "What's New" list. Worked out from the
-- .toc version rather than kept by hand, so a release cannot ship still
-- trumpeting features from several cycles ago.
local WHATS_NEW_MINOR_SPAN = 2

local function whatsNewFloor()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
    local major, minor = version:match("^(%d+)%.(%d+)")
    if not major then return "0.0.0" end
    return major .. "." .. math.max(tonumber(minor) - WHATS_NEW_MINOR_SPAN, 0) .. ".0"
end

LuckyGrabbag.WHATS_NEW_MIN_VERSION = whatsNewFloor()

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
    useItemsShowCombinable   = false,
    showDelveMap             = true,
    delveMapMinLevel         = 8,
    dungeonPortals           = true,
    dungeonPortalsDungeons   = true,
    dungeonPortalsClass      = true,
    dungeonPortalsToys       = true,
    showCombatPrep           = false,
    combatPrepReadyCheck     = false,
    combatPrepTimerMythic    = 10,
    combatPrepTimerRaid      = 12,
    combatPrepBreakTimer     = 5,
    showRotationGlow         = false,
    showPIPicker             = true,
    piFocusFirst             = false,
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
    -- Retired, both moved to Lucky's Wardrobe.
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
    blueprintImportHistory   = true,
    blueprintImportCodes     = {},
    highlightTrackedDecor    = true,
    decorAutoBuy             = false,
    decorList                = {},
    mailSendAll              = true,
    massDelete               = true,
    questShopping            = true,
    questShoppingAutoBuy     = false,
    professionQuestAutoAccept = false,
    professionQuestAutoTurnIn = false,
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
