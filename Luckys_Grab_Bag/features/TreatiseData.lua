-- Lucky's Grab-bag: Thalassian Treatise data
-- Game IDs for all professions that have a Midnight expansion treatise.
-- Update these when a new expansion adds treatise support for a profession.
--
-- skillLineID:     stable WoW profession IDs (same across expansions)
-- midnightSpellID: the spell learned when training the Midnight version of the profession
-- itemID:          the treatise item in the Warband Bank
-- questID:         the hidden weekly quest completed when the treatise is used
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.TreatiseData = {
    { name = "Alchemy",        skillLineID = 171, midnightSpellID = 423321, itemID = 245755, questID = 95127 },
    { name = "Blacksmithing",  skillLineID = 164, midnightSpellID = 423332, itemID = 245763, questID = 95128 },
    { name = "Enchanting",     skillLineID = 333, midnightSpellID = 423334, itemID = 245759, questID = 95129 },
    { name = "Engineering",    skillLineID = 202, midnightSpellID = 423335, itemID = 245809, questID = 95138 },
    { name = "Herbalism",      skillLineID = 182, midnightSpellID = 441327, itemID = 245761, questID = 95130 },
    { name = "Inscription",    skillLineID = 773, midnightSpellID = 423338, itemID = 245757, questID = 95131 },
    { name = "Jewelcrafting",  skillLineID = 755, midnightSpellID = 423339, itemID = 245760, questID = 95133 },
    { name = "Leatherworking", skillLineID = 165, midnightSpellID = 423340, itemID = 245758, questID = 95134 },
    { name = "Mining",         skillLineID = 186, midnightSpellID = 423341, itemID = 245762, questID = 95135 },
    { name = "Skinning",       skillLineID = 393, midnightSpellID = 423342, itemID = 245828, questID = 95136 },
    { name = "Tailoring",      skillLineID = 197, midnightSpellID = 423343, itemID = 245756, questID = 95137 },
}
