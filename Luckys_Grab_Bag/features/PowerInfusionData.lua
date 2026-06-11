-- Lucky's Grab-bag: Power Infusion gain ratings per specialization.
--
-- Source: Ulria & Mazz raidbots sims for Midnight Season 1 (12.0.5),
-- 5-minute patchwerk with PI used on cooldown, 4pc tier, best hero build.
-- https://www.wowhead.com/news/midnight-season-1-tier-set-and-pi-estimate-spreadsheet-by-ulria-380819
--
-- Data as of June 2026. Refresh each balance patch or season. Tiers are
-- deliberately coarse so small tuning passes don't invalidate them:
--   STRONG  ~5.5% DPS gain or more
--   GOOD    ~3.5% to 5.5%
--   unlisted: under ~3.5% (and all healers and tanks, unrated on purpose)
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.PowerInfusionData = {
    STRONG = 3,
    GOOD   = 2,
}

local D = LuckyGrabbag.PowerInfusionData

D.RATING = {
    -- Strong
    [265]  = D.STRONG, -- Affliction Warlock (6.5%)
    [254]  = D.STRONG, -- Marksmanship Hunter (6.3%)
    [63]   = D.STRONG, -- Fire Mage (6.1%)
    [269]  = D.STRONG, -- Windwalker Monk (5.7%)
    [266]  = D.STRONG, -- Demonology Warlock (5.5%)

    -- Good
    [1467] = D.GOOD,   -- Devastation Evoker (6.1% Flameshaper, 2.5% Scalecommander)
    [70]   = D.GOOD,   -- Retribution Paladin (5.1% Herald, 3.4% Templar)
    [263]  = D.GOOD,   -- Enhancement Shaman (4.9%)
    [253]  = D.GOOD,   -- Beast Mastery Hunter (4.9%)
    [262]  = D.GOOD,   -- Elemental Shaman (4.8% Stormbringer, 2.5% Farseer)
    [1480] = D.GOOD,   -- Devourer Demon Hunter (4.5%)
    [255]  = D.GOOD,   -- Survival Hunter (4.1%)
    [103]  = D.GOOD,   -- Feral Druid (4.1%)
    [62]   = D.GOOD,   -- Arcane Mage (3.9%)
    [71]   = D.GOOD,   -- Arms Warrior (3.7%)
    [102]  = D.GOOD,   -- Balance Druid (3.7% Elune, 2.3% Keeper)
}
