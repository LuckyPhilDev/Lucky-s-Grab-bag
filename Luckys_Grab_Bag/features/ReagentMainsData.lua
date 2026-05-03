-- Lucky's Grab-bag: Reagent Mains — taxonomy data
-- Categories of crafting reagents and the profession skill lines that map to each.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ReagentMainsData = {}

local Data = LuckyGrabbag.ReagentMainsData

local TRADEGOODS_CLASS = 7  -- Enum.ItemClass.Tradegoods

-- Canonical category definitions.
-- subclassIDs match the numeric subclass returned by GetItemInfo for Tradegoods items.
-- Display names live in LuckyGrabbag.Strings.reagentCategories, keyed by category key.
Data.Categories = {
    herb       = { subclassIDs = { 9 } },
    leather    = { subclassIDs = { 6 } },
    cloth      = { subclassIDs = { 5 } },
    metalstone = { subclassIDs = { 7 } },
    gems       = { subclassIDs = { 4 } },
    enchanting = { subclassIDs = { 12 } },
    cooking    = { subclassIDs = { 8 } },
    elemental  = { subclassIDs = { 10 } },
    crafting   = { subclassIDs = { 13, 15 } }, -- materials + optional reagents
    finishing  = { subclassIDs = { 16, 19 } }, -- legacy + TWW finishing reagents
    other      = { subclassIDs = { 11, 14 } }, -- misc + inscription
}

-- Display order for UI rows.
Data.CategoryOrder = {
    "herb", "leather", "cloth", "metalstone", "gems",
    "enchanting", "cooking", "elemental",
    "crafting", "finishing", "other",
}

-- Maps stable profession skill line IDs to reagent category keys.
-- Skill line IDs are locale-independent and stable across patches.
Data.ProfessionCategories = {
    [171] = "herb",        -- Alchemy
    [773] = "herb",        -- Inscription
    [182] = "herb",        -- Herbalism
    [197] = "cloth",       -- Tailoring
    [165] = "leather",     -- Leatherworking
    [393] = "leather",     -- Skinning
    [164] = "metalstone",  -- Blacksmithing
    [202] = "metalstone",  -- Engineering
    [755] = "gems",        -- Jewelcrafting
    [186] = "metalstone",  -- Mining
    [333] = "enchanting",  -- Enchanting
    [185] = "cooking",     -- Cooking
    [356] = "cooking",     -- Fishing
}

-- Sentinel value stored in db.reagentMains[cat] to mean "every character keeps these".
Data.ALL_SENTINEL = "__all__"

-- Cache to avoid repeated GetItemInfo calls for the same item.
local _classifyCache = {}

--- Returns the category key (e.g. "herb") for the given item ID, false if the item
--- is not a tracked reagent category, or nil if item data is not yet in client cache.
function Data:Classify(itemID)
    if _classifyCache[itemID] ~= nil then return _classifyCache[itemID] end

    local classID, subclassID = select(12, GetItemInfo(itemID))
    if classID == nil then return nil end  -- not in cache; caller must skip

    if classID ~= TRADEGOODS_CLASS then
        _classifyCache[itemID] = false
        return false
    end

    for cat, def in pairs(self.Categories) do
        for _, sc in ipairs(def.subclassIDs) do
            if sc == subclassID then
                _classifyCache[itemID] = cat
                return cat
            end
        end
    end

    _classifyCache[itemID] = false
    return false
end

function Data:ClearCache()
    wipe(_classifyCache)
end

--- For each category, returns a single suggested character key when exactly one
--- known character has a profession that maps to that category. Used for hints.
function Data:GetSuggestions()
    local catChars = {}  -- cat → list of charKeys
    local roster = LuckyRoster and LuckyRoster:GetAll() or {}

    for charKey, entry in pairs(roster) do
        local seen = {}
        for _, prof in ipairs(entry.professions or {}) do
            local cat = self.ProfessionCategories[prof.skillLine]
            if cat and not seen[cat] then
                seen[cat] = true
                catChars[cat] = catChars[cat] or {}
                table.insert(catChars[cat], charKey)
            end
        end
    end

    local suggestions = {}
    for cat, chars in pairs(catChars) do
        if #chars == 1 then suggestions[cat] = chars[1] end
    end
    return suggestions
end
