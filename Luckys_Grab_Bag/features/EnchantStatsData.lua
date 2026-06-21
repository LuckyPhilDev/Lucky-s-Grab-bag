-- Lucky's Grab-bag: stat-badge data
--
-- Maps Midnight enchants, missives and gems to a short stat code shown on bag
-- icons and in the Auction House. Keyed by the item's name, so every craft
-- quality and rank of the same item resolves to one code. For most enchants the
-- key is the text after "Enchant <slot> - "; leg enchants, missives and gems
-- have no such prefix and are keyed by their full name.
-- Add or update entries here when a patch adds items.
--
-- Missives and gems carry two stats. Missive stats are equal weight, so their
-- order is normalised to Crit > Haste > Mastery > Versatility ("C&H"). Gems have
-- a larger major stat and a smaller minor stat, shown major-first with the minor
-- in lower case ("H&c").
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

    -- Missives ─ dual secondary stats, equal weight. Render order is normalised
    -- by stat priority in Resolve, so the listed order here doesn't matter.
    -- Combos verified against Midnight (Thalassian) missive tooltips. The
    -- crafting-stat missives (Multicraft, Resourcefulness, ...) set profession
    -- stats rather than player secondaries, so they're intentionally unlisted.
    ["Thalassian Missive of the Fireflash"]  = { "C", "H", kind = "missive" },
    ["Thalassian Missive of the Feverflare"] = { "M", "H", kind = "missive" },
    ["Thalassian Missive of the Aurora"]     = { "V", "H", kind = "missive" },
    ["Thalassian Missive of the Harmonious"] = { "V", "M", kind = "missive" },
    ["Thalassian Missive of the Peerless"]   = { "C", "M", kind = "missive" },
    ["Thalassian Missive of the Quickblade"] = { "V", "C", kind = "missive" },
}

-- Gems ─ generated rather than listed, because the names follow a strict rule
-- (verified against Midnight gem tooltips): the colour sets the major stat and
-- the prefix word sets the second stat. When they match it's a pure single-stat
-- gem; otherwise it's major (colour) + minor (prefix), e.g. Deadly Peridot is
-- +Haste & +Crit. "Flawless" is a higher-quality cut with the same stat pairing.
-- The Eversong Diamond and Heliotrope gems give primary stats / PVP utility, not
-- secondary stats, so they're left out.
local GEM_COLOR_STAT  = { Peridot = "H", Amethyst = "M", Garnet = "C", Lapis = "V" }
local GEM_PREFIX_STAT = { Quick = "H", Masterful = "M", Deadly = "C", Versatile = "V" }

for _, quality in ipairs({ "", "Flawless " }) do
    for prefix, minor in pairs(GEM_PREFIX_STAT) do
        for color, major in pairs(GEM_COLOR_STAT) do
            local key = quality .. prefix .. " " .. color
            if minor == major then
                D.byName[key] = { major }                        -- pure single-stat gem
            else
                D.byName[key] = { major, minor, kind = "gem" }   -- major colour, minor prefix
            end
        end
    end
end

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

-- Lower index = higher priority. Equal-weight missive pairs are shown in this
-- order so e.g. a Crit+Haste missive always reads "C&H", never "H&C".
local MISSIVE_PRIORITY = { C = 1, H = 2, M = 3, V = 4 }

-- Paired badges colour each stat individually, so the separator and any
-- uncoded text fall back to this neutral tone.
local NEUTRAL = { 0.72, 0.72, 0.72 }

local function Colorize(text, color)
    return ("|cff%02x%02x%02x%s|r"):format(
        color[1] * 255, color[2] * 255, color[3] * 255, text)
end

--- Resolves an item to a badge label (short and long) and colour.
---@param itemID number|nil
---@param name string|nil  the item name, if the caller already has it
---@return string|nil short  short label for bag badges; single-stat is plain text ("H", "Int")
---                          coloured by the returned colour, pairs embed per-stat colour ("H&c")
---@return string|nil long   longer label for the Auction House ("Haste", "Crit & Haste")
---@return table|nil color   {r, g, b}; the separator/fallback colour for pairs
function D:Resolve(itemID, name)
    name = name or (itemID and C_Item.GetItemNameByID(itemID))
    local entry = self.byName[self:KeyFor(name)]
    if not entry then return nil end

    local first = self.codes[entry[1]]
    if not first then return nil end

    -- Single stat: enchants and pure gems. Plain text the caller colours itself.
    if not entry[2] then
        local short, long = first.short, first.long
        if entry.premium then
            short = short .. "+"
            long = long .. "+"
        end
        return short, long, first.color
    end

    -- Paired stat: missives and dual gems.
    local second = self.codes[entry[2]]
    if not second then return nil end

    local major, minor = first, second
    if entry.kind == "missive"
        and (MISSIVE_PRIORITY[entry[2]] or 99) < (MISSIVE_PRIORITY[entry[1]] or 99) then
        major, minor = second, first
    end

    -- Gems mark the minor stat with a lower-case letter ("H&c"); missives keep
    -- both upper since the two stats are equal ("C&H").
    local minorShort = (entry.kind == "gem") and minor.short:lower() or minor.short
    local short = Colorize(major.short, major.color) .. "&" .. Colorize(minorShort, minor.color)
    local long  = Colorize(major.long, major.color) .. " & " .. Colorize(minor.long, minor.color)
    return short, long, NEUTRAL
end
