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
-- Data as of 2026-06-10 (SimC build 1493847; the 5-target set was last
-- regenerated 2026-06-03). Refresh each balance patch or season by re-pulling
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
    [63]   = { 5.93, 6.79, 7.03 }, -- Fire Mage
    [102]  = { 5.23, 4.57, 4.22 }, -- Balance Druid
    [263]  = { 4.97, 5.05, 4.98 }, -- Enhancement Shaman
    [253]  = { 4.93, 2.83, 2.80 }, -- Beast Mastery Hunter
    [266]  = { 4.89, 5.33, 6.10 }, -- Demonology Warlock
    [269]  = { 4.89, 6.15, 6.51 }, -- Windwalker Monk
    [255]  = { 4.83, 4.33, 3.96 }, -- Survival Hunter
    [254]  = { 4.80, 4.96, 5.12 }, -- Marksmanship Hunter
    [262]  = { 4.58, 4.34, 3.86 }, -- Elemental Shaman
    [103]  = { 4.36, 4.34, 4.08 }, -- Feral Druid
    [70]   = { 4.35, 4.13, 3.95 }, -- Retribution Paladin
    [265]  = { 4.27, 3.84, 3.98 }, -- Affliction Warlock (fallback)
    [62]   = { 4.00, 4.12, 4.31 }, -- Arcane Mage
    [1480] = { 3.86, 3.71, 3.74 }, -- Devourer Demon Hunter
    [259]  = { 3.79, 2.19, 1.72 }, -- Assassination Rogue (fallback)
    [71]   = { 3.53, 3.00, 2.84 }, -- Arms Warrior
    [252]  = { 3.16, 3.02, 3.03 }, -- Unholy Death Knight
    [258]  = { 3.13, 3.76, 3.88 }, -- Shadow Priest
    [1467] = { 2.90, 3.82, 4.01 }, -- Devastation Evoker
    [64]   = { 2.72, 2.79, 2.87 }, -- Frost Mage
    [577]  = { 2.70, 2.95, 3.59 }, -- Havoc Demon Hunter
    [251]  = { 2.65, 2.54, 2.46 }, -- Frost Death Knight
    [72]   = { 2.62, 2.76, 2.62 }, -- Fury Warrior
    [267]  = { 2.24, 2.36, 2.16 }, -- Destruction Warlock
    [260]  = { 1.95, 2.08, 1.80 }, -- Outlaw Rogue (fallback)
    [261]  = { 1.27, 2.99, 2.23 }, -- Subtlety Rogue
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
