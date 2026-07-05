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
-- Data as of 2026-06-24 (SimC build c12e9e5). Refresh each balance patch or season by re-pulling
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
    [63]   = { 6.28, 7.41, 7.69 }, -- Fire Mage
    [102]  = { 5.32, 4.36, 4.29 }, -- Balance Druid
    [269]  = { 5.06, 6.12, 6.40 }, -- Windwalker Monk
    [263]  = { 5.05, 4.92, 4.89 }, -- Enhancement Shaman
    [253]  = { 4.97, 3.05, 2.75 }, -- Beast Mastery Hunter
    [266]  = { 4.89, 5.45, 5.98 }, -- Demonology Warlock
    [255]  = { 4.76, 4.46, 3.97 }, -- Survival Hunter
    [254]  = { 4.74, 5.08, 5.01 }, -- Marksmanship Hunter
    [262]  = { 4.63, 4.24, 3.84 }, -- Elemental Shaman
    [103]  = { 4.47, 4.30, 4.10 }, -- Feral Druid
    [70]   = { 4.44, 4.12, 4.17 }, -- Retribution Paladin
    [265]  = { 4.21, 3.96, 3.92 }, -- Affliction Warlock (fallback)
    [62]   = { 4.20, 4.16, 4.43 }, -- Arcane Mage
    [1480] = { 3.76, 3.93, 4.06 }, -- Devourer Demon Hunter
    [259]  = { 3.73, 2.18, 1.66 }, -- Assassination Rogue (fallback)
    [71]   = { 3.62, 2.98, 2.76 }, -- Arms Warrior
    [258]  = { 3.44, 3.67, 3.91 }, -- Shadow Priest
    [252]  = { 2.99, 2.77, 2.81 }, -- Unholy Death Knight
    [1467] = { 2.94, 3.63, 4.08 }, -- Devastation Evoker
    [64]   = { 2.80, 2.83, 2.93 }, -- Frost Mage
    [577]  = { 2.76, 3.01, 3.68 }, -- Havoc Demon Hunter
    [251]  = { 2.73, 2.81, 2.76 }, -- Frost Death Knight
    [72]   = { 2.59, 2.76, 2.70 }, -- Fury Warrior
    [267]  = { 2.25, 2.32, 2.31 }, -- Destruction Warlock
    [260]  = { 1.91, 1.89, 1.99 }, -- Outlaw Rogue (fallback)
    [261]  = { 1.36, 2.82, 2.30 }, -- Subtlety Rogue
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
