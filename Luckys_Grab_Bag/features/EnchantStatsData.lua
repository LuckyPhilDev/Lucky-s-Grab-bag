-- Lucky's Grab-bag: Enchant stat-badge data
--
-- Maps Midnight enchants to a short stat code shown on bag icons and in the
-- Auction House. Keyed by the enchant's name, so every craft quality and rank
-- of the same enchant resolves to one code. For most enchants the key is the
-- text after "Enchant <slot> - "; leg enchants have no such prefix (they're
-- named "... Spellthread" / "... Armor Kit") and are keyed by their full name.
-- Add or update entries here when a patch adds enchants.
--
-- Note: name keys are English; on a non-English client the codes won't resolve.
--
-- Codes cover secondary stats (H/C/M/V), tertiaries (Sp/Le/Av), primary stats
-- (Str/Agi/Int; A/S for armor kits' Agi-or-Str; Pri for any-primary) and a few
-- weapon procs with no stat (Shi shield, Heal, DoT).
--
-- premium = true marks the higher-stat (more expensive) version when two enchants
-- give the same stat for the same slot. Budget vs premium pairs:
--   rings  haste/vers/mastery/crit  -- confirmed via wow-professions Midnight guide
--   helm   speed/leech/avoidance    -- "Empowered" prefix is the premium version
--   shoulders leech                 -- Silvermoon (premium) vs Thalassian (budget)
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.EnchantStatsData = {}

local D = LuckyGrabbag.EnchantStatsData

-- Primary-stat enchants are class-determined, so the colour carries no extra
-- choice; one neutral tone keeps them visually distinct from the vivid
-- secondary-stat codes, and the letter (Str/Agi/Int/P) tells them apart.
local PRIMARY = { 0.88, 0.86, 0.78 }

-- code → { short label for bag badges (max 3 chars), long label for the
-- Auction House list, RGB colour }
D.codes = {
    H  = { short = "H",   long = "Haste",   color = { 0.40, 0.80, 0.45 } },
    C  = { short = "C",   long = "Crit",    color = { 0.95, 0.70, 0.20 } },
    CEff = { short = "C", long = "Crit Effect", color = { 0.95, 0.70, 0.20 } }, -- crit effectiveness, not crit rating
    M  = { short = "M",   long = "Mastery", color = { 0.82, 0.45, 0.86 } },
    V  = { short = "V",   long = "Vers",    color = { 0.32, 0.70, 0.95 } },
    Sp = { short = "Sp",  long = "Speed",   color = { 0.45, 0.85, 0.85 } },
    Le = { short = "Le",  long = "Leech",   color = { 0.85, 0.38, 0.48 } },
    Av = { short = "Av",  long = "Avoid",   color = { 0.85, 0.78, 0.45 } },
    Str = { short = "Str", long = "Str",    color = PRIMARY }, -- Strength
    Agi = { short = "Agi", long = "Agi",    color = PRIMARY }, -- Agility
    Int = { short = "Int", long = "Int",    color = PRIMARY }, -- Intellect
    P   = { short = "Pri", long = "Primary", color = PRIMARY }, -- any primary (class-flexible)
    AgiStr = { short = "A/S", long = "Agi/Str", color = PRIMARY }, -- Agility or Strength (armor kits)
    IntMana = { short = "Mna", long = "Int + Mana", color = PRIMARY }, -- Intellect plus a mana bonus
    -- Weapon procs with no stat: describe the effect instead.
    Shi  = { short = "Shi", long = "Shield", color = { 0.65, 0.78, 0.92 } }, -- absorb shield
    Heal = { short = "Hea", long = "Heal",   color = { 0.40, 0.88, 0.62 } }, -- healing
    DoT  = { short = "DoT", long = "DoT",    color = { 0.90, 0.45, 0.30 } }, -- damage over time
}

-- enchant name (text after "Enchant <slot> - ") → { stat code, premium = true|nil }
D.byName = {
    -- Rings ─ secondary stats, budget vs premium pairs
    ["Thalassian Haste"]       = { "H" },
    ["Silvermoon's Alacrity"]  = { "H", premium = true },
    ["Thalassian Versatility"] = { "V" },
    ["Silvermoon's Tenacity"]  = { "V", premium = true },
    ["Amani Mastery"]          = { "M" },
    ["Zul'jin's Mastery"]      = { "M", premium = true },
    ["Nature's Wrath"]         = { "C" },
    ["Nature's Fury"]          = { "C", premium = true },
    ["Eyes of the Eagle"]      = { "CEff" }, -- crit effectiveness, niche

    -- Helm ─ tertiary, base vs "Empowered" (premium)
    ["Blessing of Speed"]           = { "Sp" },
    ["Empowered Blessing of Speed"] = { "Sp", premium = true },
    ["Hex of Leeching"]             = { "Le" },
    ["Empowered Hex of Leeching"]   = { "Le", premium = true },
    ["Rune of Avoidance"]           = { "Av" },
    ["Empowered Rune of Avoidance"] = { "Av", premium = true },

    -- Shoulders ─ tertiary
    ["Thalassian Recovery"]  = { "Le" },
    ["Silvermoon's Mending"] = { "Le", premium = true },
    ["Flight of the Eagle"]  = { "Sp" },
    ["Akil'zon's Swiftness"] = { "Sp", premium = true },
    ["Nature's Grace"]       = { "Av" },
    ["Amirdrassil's Grace"]  = { "Av", premium = true },

    -- Boots ─ tertiary + stamina, one option per stat
    ["Farstrider's Hunt"]    = { "Sp" },
    ["Lynx's Dexterity"]     = { "Av" },
    ["Shaladrassil's Roots"] = { "Le" },

    -- Weapon ─ proc enchants. Stat procs tag the stat; effect procs (shield,
    -- heal, damage-over-time) describe what they do.
    ["Berserker's Rage"]        = { "H" },
    ["Jan'alai's Precision"]    = { "C" },
    ["Arcane Mastery"]          = { "M" },
    ["Worldsoul Tenacity"]      = { "V" },
    ["Acuity of the Ren'dorei"] = { "P" },    -- primary stat, varies by spec
    ["Worldsoul Aegis"]         = { "Shi" },
    ["Worldsoul Cradle"]        = { "Heal" },
    ["Flames of the Sin'dorei"] = { "DoT" },
    ["Strength of Halazzi"]     = { "DoT" },

    -- Chest ─ primary stat (each also grants a varying secondary)
    ["Mark of Nalorakk"]       = { "Str" }, -- + Stamina
    ["Mark of the Magister"]   = { "Int" }, -- + Mana
    ["Mark of the Rootwarden"] = { "Agi" }, -- + Speed
    ["Mark of the Worldsoul"]  = { "P" },   -- any primary, class-flexible

    -- Leg ─ primary stat. Spellthreads give Intellect; armor kits give the
    -- wearer's physical primary, always Agility or Strength (never Int).
    ["Bright Linen Spellthread"]   = { "Int" },
    ["Sunfire Silk Spellthread"]   = { "Int", premium = true },
    ["Arcanoweave Spellthread"]    = { "IntMana" },
    ["Forest Hunter's Armor Kit"]  = { "AgiStr" },
    ["Blood Knight's Armor Kit"]   = { "AgiStr" },
    ["Thalassian Scout Armor Kit"] = { "AgiStr" },
}

-- Enchants we recognise but intentionally leave unbadged (e.g. a future no-stat
-- proc). Keyed by name; keeps the dev-mode "unmapped enchant" logger quiet.
D.ignoreNames = {}

-- Item links carry craft-quality and rank decoration the plain item name doesn't:
-- an inline quality-star atlas, a trailing rank like " 3*", or a " ???" placeholder
-- before the icon loads. Strip it so the key matches byName. The Auction House
-- passes a clean itemName and needs none of this, but bags and Baganator read the
-- decorated link, so without it every enchant fails to resolve there.
local function CleanName(name)
    name = name:gsub("|A.-|a", "")        -- inline atlas markup (quality stars)
    name = name:gsub("%s*%d*%*+%s*$", "") -- trailing rank, e.g. " 3*"
    name = name:gsub("%s*%?+%s*$", "")    -- trailing "???" placeholder
    return (name:gsub("%s+$", ""))
end

-- The lookup key for an item: the text after "Enchant <slot> - " when present,
-- otherwise the full name (spellthreads and armor kits have no such prefix).
function D:KeyFor(name)
    if not name then return nil end
    name = CleanName(name)
    return name:match("^Enchant .- %- (.+)$") or name
end

--- Resolves an enchant to a badge label (short and long) and colour.
---@param itemID number|nil
---@param name string|nil  the item name, if the caller already has it
---@return string|nil short  3-char-or-fewer label for bag badges, e.g. "H", "H+", "Int"; nil if not badged
---@return string|nil long   longer label for the Auction House, e.g. "Haste", "Haste+", "Primary"
---@return table|nil color   {r, g, b}
function D:Resolve(itemID, name)
    name = name or (itemID and C_Item.GetItemNameByID(itemID))
    local entry = self.byName[self:KeyFor(name)]
    if not entry then return nil end
    local code = self.codes[entry[1]]
    if not code then return nil end
    local short, long = code.short, code.long
    if entry.premium then
        short = short .. "+"
        long = long .. "+"
    end
    return short, long, code.color
end
