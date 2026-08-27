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
        -- Crest exchange satchels from Vaskarn (upgrade/downgrade bags). Every tier's
        -- bag ends in the plural "Dawncrests"; the crests themselves are currencies, not
        -- bag items, so this fragment only matches the exchange bags.
        "Dawncrests",
    },

    -- Weekly profession quest rewards use "Thalassian <profession> <suffix>" naming.
    -- We match the prefix + suffix separately to avoid hardcoding each profession name.
    thalassianSuffixes = { "Folio", "Notebook", "Journal", "Notepad" },

    -- The shared prefix for all treatise items. Used both for pattern matching and for
    -- treatise-specific filtering logic (profession eligibility, weekly quest status).
    treatisePattern = "Thalassian Treatise on",

    -- Finishing crafting reagents whose "use" is "Combine 5 to create <better item>".
    -- Opt-in via db.useItemsShowCombinable: a working crafter carries these permanently,
    -- so the buttons would never clear out on their own.
    -- Matched by name, not ID: each of these ships in several quality tiers that share
    -- one name but have separate item IDs, and a tier we failed to list would go missing.
    combinableNamePatterns = {
        "Multicraft Matrix",          -- -> Multicraft Manifold
        "Resourceful Rebar",          -- -> Resourceful Routing
        "Ingenious Identifier",       -- -> Ingenious Identity
        "Apprentice's Scribbles",     -- -> Artisan's Ledger
        "Artisan's Ledger",           -- -> Mentor's Helpful Handiwork
        "Mentor's Helpful Handiwork", -- -> Artisan's Consortium Gold Star
    },

    -- How many of a combinable item one combine consumes. Every item above uses 5.
    combineCount = 5,

    -- Explicit item IDs that should always get a "use" button, regardless of name.
    -- Treatises are matched by name pattern above and intentionally omitted here.
    itemIDs = {
        264314, 264315, 264316, 264317, 264318,
        264319, 264320, 264321, 264322, 264323,

        -- Unique books / treasure-pickup knowledge items
        224007, 224023, 224024, 224036, 224038, 224050, 224052, 224053, 224054, 224055,
        224056, 224645, 224647, 224648, 224651, 224652, 224653, 224654, 224655, 224656,
        224657, 224658, 226265, 226266, 226267, 226268, 226269, 226270, 226271, 226272,
        226276, 226277, 226278, 226279, 226280, 226281, 226282, 226283, 226284, 226285,
        226286, 226287, 226288, 226289, 226290, 226291, 226292, 226293, 226294, 226295,
        226296, 226297, 226298, 226299, 226300, 226301, 226302, 226303, 226304, 226305,
        226306, 226307, 226308, 226309, 226310, 226311, 226312, 226313, 226314, 226315,
        226316, 226317, 226318, 226319, 226320, 226321, 226322, 226323, 226324, 226325,
        226326, 226327, 226328, 226329, 226330, 226331, 226332, 226333, 226334, 226335,
        226336, 226337, 226338, 226339, 226340, 226341, 226342, 226343, 226344, 226345,
        226346, 226347, 226348, 226349, 226350, 226351, 226352, 226353, 226354, 226355,
        227407, 227408, 227409, 227410, 227411, 227412, 227413, 227414, 227415, 227416,
        227417, 227418, 227419, 227420, 227421, 227422, 227423, 227424, 227425, 227426,
        227427, 227428, 227429, 227430, 227431, 227432, 227433, 227434, 227435, 227436,
        227437, 227438, 227439, 232499, 232500, 232501, 232502, 232503, 232504, 232505,
        232506, 232507, 232508, 232509, 235855, 235856, 235857, 235858, 235859, 235860,
        235861, 235862, 235863, 235864, 235865, 238468, 238469, 238470, 238471, 238472,
        238473, 238474, 238475, 238532, 238533, 238534, 238535, 238536, 238537, 238538,
        238539, 238540, 238541, 238542, 238543, 238544, 238545, 238546, 238547, 238548,
        238549, 238550, 238551, 238552, 238553, 238554, 238555, 238556, 238557, 238558,
        238559, 238560, 238561, 238562, 238563, 238572, 238573, 238574, 238575, 238576,
        238577, 238578, 238579, 238580, 238581, 238582, 238583, 238584, 238585, 238586,
        238587, 238588, 238589, 238590, 238591, 238592, 238593, 238594, 238595, 238596,
        238597, 238598, 238599, 238600, 238601, 238602, 238603, 238612, 238613, 238614,
        238615, 238616, 238617, 238618, 238619, 238628, 238629, 238630, 238631, 238632,
        238633, 238634, 238635, 250360, 250443, 250444, 250445, 250922, 250923, 250924,
        257599, 257600, 257601, 258410, 258411, 262644, 262645, 262646,

        -- Weekly profession quest reward items
        224807, 224817, 224818, 227667, 228773, 228774, 228775, 228776, 228777, 228778,
        228779, 263454, 263455, 263456, 263457, 263458, 263459, 263460, 263461, 263462,
        263463, 263464,

        -- Catch-up mechanic items
        224782, 224835, 224838, 227662, 228724, 228726, 228730, 228732, 228734, 228736,
        228738, 237507, 238467, 238627, 246320, 246322, 246326, 246328, 246330, 246332,
        246334, 267653,

        -- Weekly treasure-hunt items
        225220, 225221, 225222, 225223, 225224, 225225, 225226, 225227, 225228, 225229,
        225230, 225231, 225232, 225233, 225234, 225235, 259188, 259189, 259190, 259191,
        259192, 259193, 259194, 259195, 259196, 259197, 259198, 259199, 259200, 259201,
        259202, 259203,

        -- Gathering / disenchanting knowledge drops
        224264, 224265, 224583, 224584, 224780, 224781, 227659, 227661, 237496, 237506,
        238465, 238466, 238625, 238626, 267654, 267655,
    },
}
