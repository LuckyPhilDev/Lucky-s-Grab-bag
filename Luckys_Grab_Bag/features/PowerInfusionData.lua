-- Lucky's Grab-bag: Power Infusion gain per specialization.
--
-- Source: bloodmallet.com Power Infusion charts (tier MID1). Three fight
-- styles, each a stand-still fight at a different target count:
--   castingpatchwerk   -> 1 target   (single target)
--   castingpatchwerk3  -> 3 targets
--   castingpatchwerk5  -> 5 targets
-- Chart:    https://bloodmallet.com/chart/power_infusion
-- Raw data: https://bloodmallet.com/chart/get/power_infusion/<fight_style>/priest/shadow
--   e.g. .../power_infusion/castingpatchwerk/priest/shadow  (3 and 5 swap the suffix)
-- Each spec's gain is (DPS with one PI on cooldown) over its no-PI baseline.
--
-- Data as of 2026-06-17 (SimC build 9f3b11b). Refresh each balance patch or season by re-pulling
-- the three raw-data URLs and recomputing: each spec has a with-PI value and a
-- "{Spec}" baseline, so gain = (with - base) / base.
--
-- GAIN values are the DPS increase from Power Infusion as a percentage, stored
-- per spec as { single, three, five } for the three target counts. Tiers are
-- derived from the single-target value (see Tier) so a small tuning pass
-- doesn't shuffle the list:
--   STRONG  >= 4.5%
--   GOOD    >= 3.0%
--   unlisted/below: weaker (and all healers and tanks, unrated on purpose).
--
-- Specs marked (fallback) lack external-PI support in their SimC APL, so
-- bloodmallet estimates them from set PI timings; treat those as rough.
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.PowerInfusionData = {
    STRONG_PCT = 4.5,
    GOOD_PCT   = 3.0,
}

local D = LuckyGrabbag.PowerInfusionData

-- specID -> { single-target, 3-target, 5-target } DPS % gain from Power
-- Infusion. DPS specs only; tanks and healers are intentionally absent so they
-- stay unrated. Ordered by single-target gain for readability.
D.GAIN = {
    [63]   = { 6.03, 6.68, 7.07 }, -- Fire Mage
    [102]  = { 5.27, 4.38, 4.25 }, -- Balance Druid
    [269]  = { 5.13, 6.10, 6.37 }, -- Windwalker Monk
    [263]  = { 5.07, 4.85, 5.04 }, -- Enhancement Shaman
    [253]  = { 4.98, 2.85, 2.72 }, -- Beast Mastery Hunter
    [266]  = { 4.90, 5.33, 6.04 }, -- Demonology Warlock
    [255]  = { 4.85, 4.31, 4.00 }, -- Survival Hunter
    [254]  = { 4.81, 5.00, 4.98 }, -- Marksmanship Hunter
    [262]  = { 4.59, 4.35, 4.05 }, -- Elemental Shaman
    [70]   = { 4.47, 4.09, 4.01 }, -- Retribution Paladin
    [103]  = { 4.42, 4.36, 4.18 }, -- Feral Druid
    [265]  = { 4.21, 3.91, 4.00 }, -- Affliction Warlock (fallback)
    [62]   = { 3.85, 4.11, 4.28 }, -- Arcane Mage
    [259]  = { 3.75, 2.19, 1.81 }, -- Assassination Rogue (fallback)
    [71]   = { 3.66, 2.96, 2.68 }, -- Arms Warrior
    [1480] = { 3.60, 3.73, 3.99 }, -- Devourer Demon Hunter
    [258]  = { 3.54, 3.75, 3.80 }, -- Shadow Priest
    [252]  = { 2.99, 2.73, 2.70 }, -- Unholy Death Knight
    [64]   = { 2.86, 2.88, 2.87 }, -- Frost Mage
    [251]  = { 2.82, 2.88, 2.74 }, -- Frost Death Knight
    [577]  = { 2.72, 3.00, 3.51 }, -- Havoc Demon Hunter
    [1467] = { 2.66, 3.71, 4.23 }, -- Devastation Evoker
    [72]   = { 2.56, 2.58, 2.62 }, -- Fury Warrior
    [267]  = { 2.34, 2.42, 2.17 }, -- Destruction Warlock
    [260]  = { 1.90, 2.04, 1.88 }, -- Outlaw Rogue (fallback)
    [261]  = { 1.41, 3.02, 2.31 }, -- Subtlety Rogue
}

-- Gain for a spec at a target-count index (1 = single, 2 = 3-target,
-- 3 = 5-target). Defaults to single target. nil when the spec is unrated.
function D.Gain(specID, idx)
    local g = specID and D.GAIN[specID]
    return g and g[idx or 1]
end

-- "STRONG", "GOOD", or nil for a given spec at a target-count index.
function D.Tier(specID, idx)
    local gain = D.Gain(specID, idx)
    if not gain then return nil end
    if gain >= D.STRONG_PCT then return "STRONG" end
    if gain >= D.GOOD_PCT then return "GOOD" end
    return nil
end
