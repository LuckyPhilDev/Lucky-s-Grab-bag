-- luacheck: globals C_AddOns LuckyGrabbag LuckyStrings LuckyUtils LuckySettings LuckyDeps LuckyReminders
-- luacheck: globals LuckyBankRun LuckyPromo SlashCmdList SLASH_LUCKYGB1 SLASH_LUCKYGB2 strtrim print
--
-- Builds the settings panel against a recording fake, as retail and as WoW
-- Forever, to check where the rows for systems Forever lacks end up.
--
-- Run from the addon root: lua tests/SettingsForeverTest.lua

local function anything()
    return setmetatable({}, {
        __index = function(t, k) local v = anything(); rawset(t, k, v); return v end,
        __call = function() return nil end,
    })
end

C_AddOns = { GetAddOnMetadata = function() return "1.39.4" end }
LuckyStrings = { New = function(_, strings) return strings end }
LuckyDeps = { Check = function() return true end, IsEnabled = function() return false end }
LuckyReminders, LuckyBankRun, LuckyPromo = anything(), anything(), anything()
SlashCmdList = {}

local function newGroup(title)
    local group = { title = title, rows = {}, byLabel = {} }
    local function record(kind)
        return function(self, opts)
            local row = { kind = kind, opts = opts }
            self.rows[#self.rows + 1] = row
            if type(opts) == "table" and opts.label then self.byLabel[opts.label] = row end
            return self
        end
    end
    for _, kind in ipairs({ "Toggle", "Select", "Slider", "Button", "MultiSelect", "Notice", "Section", "Frame" }) do
        group[kind] = record(kind)
    end
    return group
end

local groups
LuckySettings = { NewRichPanel = function()
    return {
        Group = function(_, title) local g = newGroup(title); groups[#groups + 1] = g; return g end,
        Finalize = function() end,
    }
end }

local function build(mainline)
    groups = {}
    LuckyUtils = { IsMainline = function() return mainline end }
    LuckyGrabbag = nil
    dofile("src/Defaults.lua")
    dofile("src/Strings.lua")
    LuckyGrabbag.Reminders = { EnchantSlotOptions = function() return {} end }
    LuckyGrabbag.AutoDepositUtils = { StockistOwnsBank = function() return false end }
    LuckyGrabbag.BonusRoll = { HandedOff = function() return false end }
    LuckyGrabbag.EnchantStats = anything()
    dofile("src/Settings.lua")
    local db = setmetatable({ ahQualityIcons = "off", remindEnchantsIgnore = {} }, { __index = LuckyGrabbag.DB_DEFAULTS })
    LuckyGrabbag.Settings:Init(db, {})
    local byTitle = {}
    for _, g in ipairs(groups) do byTitle[g.title] = g end
    return byTitle
end

local SS
local retail = build(true)
SS = LuckyGrabbag.Strings.settings
assert(groups[#groups].title == SS.groups.interface, "retail ends on Interface")
assert(not retail[SS.groups.notOnForever], "retail has no Forever group")
assert(retail[SS.groups.delves].byLabel[SS.delveMap.label], "retail keeps delves in their own group")
assert(retail[SS.groups.crafting].byLabel[SS.concentrationView.label], "and modern professions in Professions")

local forever = build(false)
local unavailable = groups[#groups]
assert(unavailable.title == SS.groups.notOnForever, "Forever ends on the unavailable group")
for _, title in ipairs({ SS.groups.delves, SS.groups.housing, SS.groups.interface, "Auto-Deposit" }) do
    assert(not forever[title], title .. " has nothing left on Forever, so it is not built")
end
assert(not forever[SS.groups.crafting].byLabel[SS.concentrationView.label], "Concentration leaves Professions")
assert(forever[SS.groups.crafting].byLabel[SS.cookingButtons.label], "while cooking buttons stay")
assert(not forever[SS.groups.reminders].byLabel[SS.remindTradingPost.label], "the Trading Post reminder moves")
assert(forever[SS.groups.reminders].byLabel[SS.remindBags.label], "the bags reminder stays")

local headings, labels = {}, {}
for _, row in ipairs(unavailable.rows) do
    if row.kind == "Section" then
        headings[#headings + 1] = row.opts
    else
        labels[row.opts.label] = true
        assert(row.kind ~= "Button" or row.opts.parent, "a loose button cannot be locked, so it is left out")
        assert(row.opts.disabled or row.opts.parent, row.opts.label .. " is locked or sits under a locked row")
    end
end
assert(headings[1] == SS.groups.vendors, "headings follow the usual group order, Vendors first")
assert(labels[SS.delveMap.label] and labels[SS.bonusRoll.label] and labels[SS.reagentMains.label], "rows land in it")
assert(labels[SS.questShopping.label], "quest shopping is offered once")
local questShoppingRows = 0
for _, row in ipairs(unavailable.rows) do
    if row.opts.label == SS.questShopping.label then questShoppingRows = questShoppingRows + 1 end
end
assert(questShoppingRows == 1, "and only once, though retail shows it in two groups")
assert(unavailable.byLabel[SS.delveMapMinLevel.label].opts.parent == SS.delveMap.label, "children keep their parent")

print("SettingsForever: all checks passed")
