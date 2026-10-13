-- Lucky's Grab-bag: Power Infusion gain per specialization.
--
-- ponytail: parked. Nothing reads this while the numbers are a season out of
-- date, so the picker shows an unranked group list instead. Refresh GAIN from
-- the sources below and wire Gain/Tier back into PowerInfusion.lua to revive it.
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
-- Data as of 2026-10-13 (SimC build e3fa778). Refresh each balance patch or season by re-pulling
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
    [259]  = { 5.99, 5.31, 5.36 }, -- Assassination Rogue
    [265]  = { 5.72, 3.90, 3.83 }, -- Affliction Warlock
    [102]  = { 5.23, 4.47, 4.24 }, -- Balance Druid
    [70]   = { 5.03, 6.09, 5.87 }, -- Retribution Paladin
    [103]  = { 4.74, 4.68, 4.60 }, -- Feral Druid
    [263]  = { 4.68, 4.55, 4.51 }, -- Enhancement Shaman
    [254]  = { 4.59, 4.46, 4.14 }, -- Marksmanship Hunter
    [262]  = { 4.58, 4.76, 4.30 }, -- Elemental Shaman
    [63]   = { 4.48, 4.71, 4.72 }, -- Fire Mage
    [269]  = { 4.44, 5.29, 5.11 }, -- Windwalker Monk
    [266]  = { 4.30, 5.29, 5.94 }, -- Demonology Warlock
    [252]  = { 3.94, 3.90, 2.70 }, -- Unholy Death Knight
    [255]  = { 3.74, 3.88, 3.82 }, -- Survival Hunter
    [253]  = { 3.56, 3.65, 3.40 }, -- Beast Mastery Hunter
    [62]   = { 3.37, 3.60, 3.55 }, -- Arcane Mage
    [251]  = { 3.28, 2.96, 3.10 }, -- Frost Death Knight
    [71]   = { 3.12, 3.97, 3.33 }, -- Arms Warrior
    [258]  = { 2.75, 2.92, 3.08 }, -- Shadow Priest
    [1467] = { 2.68, 3.56, 4.17 }, -- Devastation Evoker
    [64]   = { 2.67, 2.75, 2.73 }, -- Frost Mage
    [1480] = { 2.66, 1.82, 1.96 }, -- Devourer Demon Hunter
    [267]  = { 2.64, 2.89, 2.77 }, -- Destruction Warlock
    [260]  = { 2.59, 3.68, 3.93 }, -- Outlaw Rogue (fallback)
    [72]   = { 2.23, 2.90, 2.82 }, -- Fury Warrior
    [577]  = { 1.97, 1.92, 1.93 }, -- Havoc Demon Hunter (fallback)
    [261]  = { 1.31, 1.32, 0.82 }, -- Subtlety Rogue
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
