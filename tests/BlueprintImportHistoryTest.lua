-- luacheck: globals CreateFrame GameTooltip GameTooltip_Hide hooksecurefunc
-- luacheck: globals C_AddOns HousingBlueprintImportFrame HousingBlueprintTypeStrings

-- Covers features/BlueprintImportHistory.lua: imports land in the history
-- newest first, re-importing a code moves it up rather than duplicating it,
-- the list stops at ten, and picking a menu entry puts the full code back
-- into Blizzard's share code box.
--
-- Run from the addon root: lua tests/BlueprintImportHistoryTest.lua

-- ─── Generic widget ──────────────────────────────────────────────────────────

local noop = function() end

local function Widget()
    local w = { shown = false, scripts = {} }
    w.SetScript   = function(self, event, fn) self.scripts[event] = fn end
    w.HookScript  = w.SetScript
    w.Show        = function(self) self.shown = true end
    w.Hide        = function(self) self.shown = false end
    w.IsShown     = function(self) return self.shown end
    w.SetShown    = function(self, shown) self.shown = shown end
    w.GetRegions  = function() return end
    w.SetupMenu   = function(self, generator) self.menuGenerator = generator end
    return setmetatable(w, { __index = function(_, key)
        if type(key) == "string" and key:match("^[A-Z]") then return noop end
    end })
end

function CreateFrame(_, name)
    local w = Widget()
    if name then _G[name] = w end
    return w
end

GameTooltip      = Widget()
GameTooltip_Hide = noop

function hooksecurefunc(tbl, name, fn)
    local original = tbl[name]
    tbl[name] = function(...)
        original(...)
        fn(...)
    end
end

C_AddOns = { IsAddOnLoaded = function() return true end }

-- ─── Blizzard's import frame, reduced to what the feature touches ────────────

HousingBlueprintTypeStrings = { [1] = "House", [2] = "Room" }

local shareCodeBox
HousingBlueprintImportFrame = Widget()
HousingBlueprintImportFrame.OnImportConfirmed = noop
HousingBlueprintImportFrame.InputContent = Widget()
HousingBlueprintImportFrame.InputContent.GearDropdown = Widget()
HousingBlueprintImportFrame.InputContent.SetShareCode = function(_, code)
    shareCodeBox = code
end

-- ─── Addon under test ────────────────────────────────────────────────────────

dofile("src/Strings.lua")
LuckyGrabbag.DevLog = function() end
dofile("src/features/BlueprintImportHistory.lua")

local db = { blueprintImportHistory = true }
LuckyGrabbag.BlueprintImportHistory:Init(db)

local button = _G.LGB_BlueprintImportHistoryButton
assert(button, "history button was not created")

local function Import(code, blueprintType)
    HousingBlueprintImportFrame:OnImportConfirmed(code, blueprintType or 1)
end

--- Runs the menu generator and returns its entries as {label, onClick} pairs.
local function MenuEntries()
    local entries = {}
    local rootDescription = {
        CreateTitle  = noop,
        CreateButton = function(_, label, onClick)
            entries[#entries + 1] = { label = label, onClick = onClick }
        end,
    }
    button.menuGenerator(button, rootDescription)
    return entries
end

-- ─── Empty history hides the button ──────────────────────────────────────────

assert(not button:IsShown(), "button shown with nothing to list")

-- ─── Imports stack newest first and dedupe ───────────────────────────────────

Import("CODE-A")
assert(button:IsShown(), "button hidden after an import")
assert(#db.blueprintImportCodes == 1)

Import("CODE-B")
Import("CODE-A") -- again: moves up, no duplicate
assert(#db.blueprintImportCodes == 2, "re-import duplicated instead of moving")
assert(db.blueprintImportCodes[1].code == "CODE-A")
assert(db.blueprintImportCodes[2].code == "CODE-B")

-- ─── The list stops at ten ───────────────────────────────────────────────────

for i = 1, 12 do
    Import("BULK-" .. i)
end
assert(#db.blueprintImportCodes == 10, "history grew past ten")
assert(db.blueprintImportCodes[1].code == "BULK-12")
assert(db.blueprintImportCodes[10].code == "BULK-3")

-- ─── Menu entries carry the type name and refill the share code box ──────────

Import("ROOMCODE-1234567890", 2)
local entries = MenuEntries()
assert(#entries == 10, "menu entry count does not match history")
assert(entries[1].label:find("Room", 1, true), "label missing the blueprint type")
assert(entries[1].label:find("ROOMCODE-123", 1, true), "label missing the code preview")
assert(not entries[1].label:find("ROOMCODE-1234567890", 1, true), "long code not truncated")

entries[1].onClick()
assert(shareCodeBox == "ROOMCODE-1234567890", "menu click did not refill the full code")

-- ─── The toggle stops recording and hides the button ─────────────────────────

db.blueprintImportHistory = false
LuckyGrabbag.BlueprintImportHistory:ApplySetting()
assert(not button:IsShown(), "button still shown with the setting off")

Import("IGNORED")
assert(db.blueprintImportCodes[1].code == "ROOMCODE-1234567890", "recorded while switched off")

print("BlueprintImportHistoryTest: all assertions passed")
