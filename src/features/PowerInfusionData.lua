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
-- Data as of 2026-07-07 (SimC build ef52631). Refresh each balance patch or season by re-pulling
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
    [63]   = { 6.31, 7.36, 7.85 }, -- Fire Mage
    [102]  = { 5.08, 4.37, 4.22 }, -- Balance Druid
    [269]  = { 5.07, 6.04, 6.59 }, -- Windwalker Monk
    [255]  = { 4.92, 4.25, 4.02 }, -- Survival Hunter
    [263]  = { 4.92, 4.85, 4.97 }, -- Enhancement Shaman
    [253]  = { 4.89, 3.06, 2.78 }, -- Beast Mastery Hunter
    [254]  = { 4.77, 4.97, 4.93 }, -- Marksmanship Hunter
    [266]  = { 4.76, 5.25, 5.90 }, -- Demonology Warlock
    [262]  = { 4.50, 4.39, 3.92 }, -- Elemental Shaman
    [265]  = { 4.41, 3.81, 3.93 }, -- Affliction Warlock (fallback)
    [103]  = { 4.41, 4.23, 4.20 }, -- Feral Druid
    [70]   = { 4.35, 4.00, 4.09 }, -- Retribution Paladin
    [62]   = { 4.12, 4.35, 4.31 }, -- Arcane Mage
    [259]  = { 3.71, 2.14, 1.54 }, -- Assassination Rogue (fallback)
    [1480] = { 3.63, 3.81, 3.97 }, -- Devourer Demon Hunter
    [71]   = { 3.63, 2.87, 2.75 }, -- Arms Warrior
    [258]  = { 3.50, 3.84, 3.88 }, -- Shadow Priest
    [64]   = { 2.95, 2.76, 3.08 }, -- Frost Mage
    [252]  = { 2.86, 2.77, 2.74 }, -- Unholy Death Knight
    [1467] = { 2.83, 3.61, 4.02 }, -- Devastation Evoker
    [251]  = { 2.79, 2.85, 2.84 }, -- Frost Death Knight
    [577]  = { 2.70, 3.14, 3.47 }, -- Havoc Demon Hunter
    [72]   = { 2.53, 2.68, 2.66 }, -- Fury Warrior
    [267]  = { 2.07, 2.31, 2.08 }, -- Destruction Warlock
    [260]  = { 1.93, 1.96, 1.90 }, -- Outlaw Rogue (fallback)
    [261]  = { 1.41, 2.90, 2.27 }, -- Subtlety Rogue
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
