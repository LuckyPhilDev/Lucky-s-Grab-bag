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
-- Data as of 2026-07-16 (SimC build 3344f0f). Refresh each balance patch or season by re-pulling
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
    [63]   = { 6.31, 7.31, 7.93 }, -- Fire Mage
    [102]  = { 5.23, 4.47, 4.24 }, -- Balance Druid
    [269]  = { 5.16, 6.06, 6.35 }, -- Windwalker Monk
    [263]  = { 5.14, 4.85, 5.03 }, -- Enhancement Shaman
    [253]  = { 4.95, 2.99, 2.78 }, -- Beast Mastery Hunter
    [266]  = { 4.85, 5.28, 5.92 }, -- Demonology Warlock
    [255]  = { 4.83, 4.29, 3.94 }, -- Survival Hunter
    [254]  = { 4.75, 5.00, 5.02 }, -- Marksmanship Hunter
    [262]  = { 4.59, 4.30, 4.02 }, -- Elemental Shaman
    [265]  = { 4.40, 3.74, 3.91 }, -- Affliction Warlock (fallback)
    [103]  = { 4.39, 4.38, 4.18 }, -- Feral Druid
    [62]   = { 4.32, 4.21, 4.34 }, -- Arcane Mage
    [70]   = { 4.29, 4.13, 4.15 }, -- Retribution Paladin
    [259]  = { 3.84, 2.23, 1.82 }, -- Assassination Rogue (fallback)
    [1480] = { 3.58, 3.74, 3.67 }, -- Devourer Demon Hunter
    [71]   = { 3.57, 2.87, 2.81 }, -- Arms Warrior
    [258]  = { 3.47, 3.71, 3.90 }, -- Shadow Priest
    [252]  = { 3.10, 2.79, 2.70 }, -- Unholy Death Knight
    [577]  = { 2.78, 3.11, 3.66 }, -- Havoc Demon Hunter
    [251]  = { 2.75, 2.81, 2.64 }, -- Frost Death Knight
    [64]   = { 2.73, 2.89, 3.05 }, -- Frost Mage
    [1467] = { 2.68, 3.56, 4.17 }, -- Devastation Evoker
    [72]   = { 2.55, 2.74, 2.58 }, -- Fury Warrior
    [267]  = { 2.20, 2.34, 2.32 }, -- Destruction Warlock
    [260]  = { 1.96, 1.87, 1.93 }, -- Outlaw Rogue (fallback)
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
