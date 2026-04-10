-- Lucky's Grab-bag: UseItems matching data
-- Add or remove entries here when new consumable profession items are added to the game.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.UseItemsData = {
    -- Any bag item whose name contains one of these fragments gets a "use" button.
    itemNamePatterns = {
        "Artisan's Consortium Payout",
        "Glimmer of Midnight",
        "Flicker of Midnight",
        "Thalassian Treatise on",
        "Brimming Mana Shard",
        "Swirling Arcane Essence",
    },

    -- Weekly profession quest rewards use "Thalassian <profession> <suffix>" naming.
    -- We match the prefix + suffix separately to avoid hardcoding each profession name.
    thalassianSuffixes = { "Folio", "Notebook", "Journal", "Notepad" },

    -- The shared prefix for all treatise items. Used both for pattern matching and for
    -- treatise-specific filtering logic (profession eligibility, weekly quest status).
    treatisePattern = "Thalassian Treatise on",
}
