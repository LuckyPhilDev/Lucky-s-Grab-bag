-- Lucky's Grab-bag: Power Infusion gain per specialization.
--
-- Source: bloodmallet.com Power Infusion chart (castingpatchwerk, tier MID1).
-- Chart:    https://bloodmallet.com/chart/power_infusion
-- Raw data: https://bloodmallet.com/chart/get/power_infusion/castingpatchwerk/priest/shadow
-- Each spec's gain is (DPS with one PI on cooldown) over its no-PI baseline.
--
-- Data as of 2026-06-10 (SimC build 1493847). Refresh each balance patch or
-- season by re-pulling the raw-data URL and recomputing the percentages: each
-- spec has a with-PI value and a "{Spec}" baseline, so gain = (with - base) / base.
--
-- GAIN values are the DPS increase from receiving Power Infusion, as a
-- percentage. Tiers are derived from thresholds (see Tier) so a small tuning
-- pass doesn't shuffle the list:
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

-- specID -> DPS % gain from Power Infusion. DPS specs only; tanks and healers
-- are intentionally absent so they stay unrated.
D.GAIN = {
    [63]   = 5.93, -- Fire Mage
    [102]  = 5.23, -- Balance Druid
    [263]  = 4.97, -- Enhancement Shaman
    [253]  = 4.93, -- Beast Mastery Hunter
    [266]  = 4.89, -- Demonology Warlock
    [269]  = 4.89, -- Windwalker Monk
    [255]  = 4.83, -- Survival Hunter
    [254]  = 4.80, -- Marksmanship Hunter
    [262]  = 4.58, -- Elemental Shaman
    [103]  = 4.36, -- Feral Druid
    [70]   = 4.35, -- Retribution Paladin
    [265]  = 4.27, -- Affliction Warlock (fallback)
    [62]   = 4.00, -- Arcane Mage
    [1480] = 3.86, -- Devourer Demon Hunter
    [259]  = 3.79, -- Assassination Rogue (fallback)
    [71]   = 3.53, -- Arms Warrior
    [252]  = 3.16, -- Unholy Death Knight
    [258]  = 3.13, -- Shadow Priest
    [1467] = 2.90, -- Devastation Evoker
    [64]   = 2.72, -- Frost Mage
    [577]  = 2.70, -- Havoc Demon Hunter
    [251]  = 2.65, -- Frost Death Knight
    [72]   = 2.62, -- Fury Warrior
    [267]  = 2.24, -- Destruction Warlock
    [260]  = 1.95, -- Outlaw Rogue (fallback)
    [261]  = 1.27, -- Subtlety Rogue
}

-- "STRONG", "GOOD", or nil for a given spec, based on its gain percentage.
function D.Tier(specID)
    local gain = specID and D.GAIN[specID]
    if not gain then return nil end
    if gain >= D.STRONG_PCT then return "STRONG" end
    if gain >= D.GOOD_PCT then return "GOOD" end
    return nil
end
