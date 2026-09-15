-- luacheck: globals CreateFrame GameTooltip GameTooltip_Hide hooksecurefunc Enum RAID_CLASS_COLORS
-- luacheck: globals C_AddOns C_AutoComplete C_TradeSkillUI GetNormalizedRealmName ProfessionsCustomerOrdersFrame
-- Run from the addon root: lua tests/CraftingOrderAltsTest.lua

local noop = function() end

local function Widget()
    local w = { shown = false, scripts = {} }
    w.SetScript      = function(self, event, fn) self.scripts[event] = fn end
    w.Show           = function(self) self.shown = true end
    w.Hide           = function(self) self.shown = false end
    w.IsShown        = function(self) return self.shown end
    w.SetShown       = function(self, shown) self.shown = shown end
    w.SetText        = function(self, text) self.text = text end
    w.GetText        = function(self) return self.text end
    w.GetStringWidth = function(self) return #(self.text or "") end
    w.SetPoint       = function(self, _, relativeTo) self.anchor = relativeTo end
    w.CreateFontString = function() return Widget() end
    w.CreateTexture    = function() return Widget() end
    return setmetatable(w, { __index = function(_, key)
        if type(key) == "string" and key:match("^[A-Z]") then return noop end
    end })
end

local eventFrame, panel
local rows = {}
function CreateFrame(frameType)
    local w = Widget()
    if frameType == "Button" then
        table.insert(rows, w)
    else
        eventFrame = w
    end
    return w
end

LuckyUI = {
    C = setmetatable({}, { __index = function() return { 1, 1, 1, 1 } end }),
    CreatePanel = function()
        panel = Widget()
        return panel
    end,
}

function hooksecurefunc(object, method, hook)
    local original = object[method]
    object[method] = function(...)
        original(...)
        hook(...)
    end
end

GameTooltip = Widget()
GameTooltip_Hide = noop
Enum = { CraftingOrderType = { Public = 0, Guild = 1, Personal = 2 } }
RAID_CLASS_COLORS = setmetatable({}, { __index = function()
    return { WrapTextInColorCode = function(_, text) return "|cff" .. text .. "|r" end }
end })

local BLACKSMITHING, TAILORING = 164, 197
local professionByRecipe = {
    [1] = { professionID = 2872, parentProfessionID = BLACKSMITHING, parentProfessionName = "Blacksmithing" },
    [2] = { professionID = TAILORING, professionName = "Tailoring" },
}
C_AddOns = { IsAddOnLoaded = function() return false end }
C_AutoComplete = { GetAutoCompleteRealms = function() return { "Linked" } end }
C_TradeSkillUI = { GetProfessionInfoByRecipeID = function(recipeID) return professionByRecipe[recipeID] end }
function GetNormalizedRealmName() return "Home" end

local function Character(name, realm, skillLine)
    return { name = name, realm = realm, class = "WARRIOR", professions = { { skillLine = skillLine } } }
end
local roster = {
    ["Anvil-Linked"]  = Character("Anvil", "Linked", BLACKSMITHING),
    ["Far-Elsewhere"] = Character("Far", "Elsewhere", BLACKSMITHING),
    ["Main-Home"]     = Character("Main", "Home", BLACKSMITHING),
    ["Smith-Home"]    = Character("Smith", "Home", BLACKSMITHING),
    ["Stitch-Home"]   = Character("Stitch", "Home", TAILORING),
}
LuckyRoster = {
    GetKey  = function() return "Main-Home" end,
    Get     = function(_, key) return roster[key] end,
    GetKeys = function()
        local keys = {}
        for key in pairs(roster) do table.insert(keys, key) end
        table.sort(keys)
        return keys
    end,
}

local form = Widget()
form.CurrentListings = Widget()
form.OrderRecipientTarget = Widget()
form.OrderRecipientDropdown = Widget()
function form.OrderRecipientDropdown:GenerateMenu() self.label = form.order.orderType end
function form:Init(order)
    self.order = order
    self.committed = order.orderID ~= nil
    self:HideCurrentListings()
end
function form:SetRecraftItemGUID() self.order.spellID = 1 end
function form:ShowCurrentListings() self.CurrentListings:Show() end
function form:HideCurrentListings() self.CurrentListings:Hide() end
function form:SetOrderRecipient(orderType) self.order.orderType = orderType end
function form:UpdateListOrderButton() self.validatedTarget = self.OrderRecipientTarget:GetText() end
ProfessionsCustomerOrdersFrame = { Form = form }

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
dofile("src/features/CraftingOrderAlts.lua")

local db = { craftingOrderAlts = true }
LuckyGrabbag.CraftingOrderAlts:Init(db)

local function ShownTargets()
    local targets = {}
    if not (panel and panel:IsShown()) then return "" end
    for _, row in ipairs(rows) do
        if row:IsShown() then table.insert(targets, row.target) end
    end
    return table.concat(targets, ",")
end

local function OpenOrder(order)
    order.orderType = order.orderType or Enum.CraftingOrderType.Public
    form:Init(order)
end

eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "SomeOtherAddon")
OpenOrder({ spellID = 1 })
assert(ShownTargets() == "", "hooks installed before the crafting orders UI loaded")

eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "Blizzard_ProfessionsCustomerOrders")
OpenOrder({ spellID = 1 })
assert(ShownTargets() == "Anvil-Linked,Smith",
    "expected crafters on reachable realms, excluding yourself, got " .. ShownTargets())
assert(panel.profession:GetText() == "Blacksmithing")
assert(rows[1].realm:GetText() == "Linked" and rows[2].realm:GetText() == "", "only other realms are named")
assert(panel.anchor == form)
form:ShowCurrentListings()
assert(panel.anchor == form.CurrentListings, "the panel must move clear of the listings popout")

rows[2].scripts.OnEnter(rows[2])
rows[2].scripts.OnClick(rows[2])
assert(form.order.orderType == Enum.CraftingOrderType.Personal, "clicking a crafter makes the order Personal")
assert(form.OrderRecipientDropdown.label == Enum.CraftingOrderType.Personal, "dropdown label left stale")
assert(form.OrderRecipientTarget:GetText() == "Smith" and form.validatedTarget == "Smith")

OpenOrder({ spellID = 2 })
assert(ShownTargets() == "Stitch", "recipe on a base skill line, got " .. ShownTargets())
assert(panel.profession:GetText() == "Tailoring")

OpenOrder({ spellID = 1, orderID = 99 })
assert(ShownTargets() == "", "an order already placed takes no recipient")

OpenOrder({ isRecraft = true })
assert(ShownTargets() == "", "a recraft with no item chosen has no profession yet")
form:SetRecraftItemGUID("item-guid")
assert(ShownTargets() == "Anvil-Linked,Smith", "choosing the recraft item should reveal its crafters")

db.craftingOrderAlts = false
OpenOrder({ spellID = 1 })
assert(ShownTargets() == "", "setting off must hide the panel")

print("CraftingOrderAltsTest: passed")
