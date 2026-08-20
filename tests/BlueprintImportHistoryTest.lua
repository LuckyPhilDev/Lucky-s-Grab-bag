-- luacheck: globals CreateFrame GameTooltip GameTooltip_Hide hooksecurefunc strtrim SAVE
-- luacheck: globals C_AddOns C_Texture HousingBlueprintImportFrame HousingBlueprintTypeStrings
-- luacheck: globals LuckySettings MenuTemplates MenuVariants MenuUtil

-- Covers features/BlueprintImportHistory.lua: pressing Next with a valid code
-- lands it in the history newest first and opens the name pane, invalid codes
-- and re-entries do not grow the list, the list stops at ten, menu rows refill
-- the share code box, and their inline icons delete and rename entries.
--
-- Run from the addon root: lua tests/BlueprintImportHistoryTest.lua

-- ─── Generic widget ──────────────────────────────────────────────────────────

local noop = function() end

local function Widget()
    local w = { shown = false, enabled = true, scripts = {} }
    w.SetScript   = function(self, event, fn) self.scripts[event] = fn end
    w.HookScript  = w.SetScript
    w.Show        = function(self) self.shown = true end
    w.Hide        = function(self) self.shown = false end
    w.IsShown     = function(self) return self.shown end
    w.SetShown    = function(self, shown) self.shown = shown end
    w.SetEnabled  = function(self, enabled) self.enabled = enabled end
    w.IsEnabled   = function(self) return self.enabled end
    w.SetText     = function(self, text) self.text = text end
    w.GetText     = function(self) return self.text end
    w.GetRegions  = function() return end
    w.SetupMenu   = function(self, generator) self.menuGenerator = generator end
    w.CreateFontString = function() return Widget() end
    w.CreateTexture    = function() return Widget() end
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
SAVE             = "Save"

function strtrim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function hooksecurefunc(tbl, name, fn)
    local original = tbl[name]
    tbl[name] = function(...)
        original(...)
        fn(...)
    end
end

C_AddOns  = { IsAddOnLoaded = function() return true end }
C_Texture = { GetAtlasInfo = function() return {} end }

LuckySettings = {
    Rich = {
        FillBg   = noop,
        EdgeRule = noop,
        Font     = "font",
        Theme    = setmetatable({}, { __index = function() return { 1, 1, 1, 1 } end }),
    },
}

-- ─── Menu attachment stubs, the Wardrobe row-icon pattern ────────────────────

local attachedButtons = {}

MenuTemplates = {
    AttachBasicButton = function()
        local b = Widget()
        b.AttachTexture = function() return Widget() end
        attachedButtons[#attachedButtons + 1] = b
        return b
    end,
}
MenuVariants = { CancelButtonTexture = "cancel-texture" }
MenuUtil     = { HookTooltipScripts = noop }

-- ─── Blizzard's import frame, reduced to what the feature touches ────────────

HousingBlueprintTypeStrings = { [1] = "House", [2] = "Room" }

local shareCodeBox
local typedCode, typedType, typedValid

HousingBlueprintImportFrame = Widget()
HousingBlueprintImportFrame.OnImportConfirmed = noop
HousingBlueprintImportFrame.OnInputNextClicked = noop
HousingBlueprintImportFrame.InputContent = Widget()
HousingBlueprintImportFrame.InputContent.GearDropdown = Widget()
HousingBlueprintImportFrame.InputContent.SetShareCode = function(_, code)
    shareCodeBox = code
end
HousingBlueprintImportFrame.InputContent.IsInputValid = function()
    return typedValid
end
HousingBlueprintImportFrame.InputContent.GetInputValues = function()
    return typedCode, typedType
end

-- ─── Addon under test ────────────────────────────────────────────────────────

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
LuckyGrabbag.DevLog = function() end
LuckyGrabbag.Logger = function() return function() end end
dofile("src/features/BlueprintImportHistory.lua")

local db = { blueprintImportHistory = true }
LuckyGrabbag.BlueprintImportHistory:Init(db)

local button = _G.LGB_BlueprintImportHistoryButton
assert(button, "history button was not created")

local function Import(code, blueprintType)
    HousingBlueprintImportFrame:OnImportConfirmed(code, blueprintType or 1)
end

local function PressNext(code, blueprintType, isValid)
    typedCode, typedType, typedValid = code, blueprintType or 1, isValid ~= false
    HousingBlueprintImportFrame:OnInputNextClicked()
end

local function NamePane()
    return _G.LGB_BlueprintCodeNamePane
end

--- Runs the menu generator, returning entries as {label, onClick, init}.
local function MenuEntries()
    local entries = {}
    local rootDescription = {
        CreateTitle  = noop,
        CreateButton = function(_, label, onClick)
            local row = { label = label, onClick = onClick }
            row.AddInitializer = function(_, init) row.init = init end
            entries[#entries + 1] = row
            return row
        end,
    }
    button.menuGenerator(button, rootDescription)
    return entries
end

--- Runs a row's initializer and returns its delete and rename icon buttons.
local function RowIcons(row)
    attachedButtons = {}
    row.init(Widget(), nil, { Close = noop })
    return attachedButtons[1], attachedButtons[2]
end

-- ─── Empty history shows the button disabled ─────────────────────────────────

assert(button:IsShown(), "button hidden while the setting is on")
assert(not button:IsEnabled(), "button enabled with nothing to list")

-- ─── Pressing Next saves the code and asks for a name ────────────────────────

PressNext("CODE-A")
assert(button:IsEnabled(), "button still disabled after a code was entered")
assert(#db.blueprintImportCodes == 1, "Next with a valid code did not save")
assert(NamePane():IsShown(), "name pane did not open on save")

NamePane().editBox:SetText("  Beach House  ")
NamePane().editBox.scripts.OnEnterPressed()
assert(db.blueprintImportCodes[1].name == "Beach House", "name not trimmed and saved")
assert(not NamePane():IsShown(), "name pane still open after saving")

PressNext("CODE-JUNK", 1, false)
assert(#db.blueprintImportCodes == 1, "Next with an invalid code was saved")

-- ─── Codes stack newest first, dedupe, and keep their names ──────────────────

Import("CODE-B")
PressNext("CODE-A") -- again: moves up, no duplicate
assert(#db.blueprintImportCodes == 2, "re-entering duplicated instead of moving")
assert(db.blueprintImportCodes[1].code == "CODE-A")
assert(db.blueprintImportCodes[1].name == "Beach House", "name lost on re-entry")
assert(db.blueprintImportCodes[2].code == "CODE-B")

-- A named entry leads with its name in the menu.
assert(MenuEntries()[1].label:find("Beach House", 1, true), "label missing the saved name")

-- Imports arriving without the input tab never open the pane.
NamePane():Hide()
Import("LINKED-CODE")
assert(not NamePane():IsShown(), "pane opened for a pre-filled import")

-- ─── The list stops at ten ───────────────────────────────────────────────────

for i = 1, 12 do
    Import("BULK-" .. i)
end
assert(#db.blueprintImportCodes == 10, "history grew past ten")
assert(db.blueprintImportCodes[1].code == "BULK-12")
assert(db.blueprintImportCodes[10].code == "BULK-3")

-- ─── Menu rows carry the type name and refill the share code box ─────────────

Import("ROOMCODE-1234567890", 2)
local entries = MenuEntries()
assert(#entries == 10, "menu entry count does not match history")
assert(entries[1].label:find("Room", 1, true), "label missing the blueprint type")
assert(entries[1].label:find("ROOMCODE-123", 1, true), "label missing the code preview")
assert(not entries[1].label:find("ROOMCODE-1234567890", 1, true), "long code not truncated")

entries[1].onClick()
assert(shareCodeBox == "ROOMCODE-1234567890", "menu click did not refill the full code")

-- ─── The row icons delete and rename ─────────────────────────────────────────

local deleteIcon = RowIcons(entries[1])
deleteIcon.scripts.OnClick()
assert(#db.blueprintImportCodes == 9, "delete icon did not remove the entry")
assert(db.blueprintImportCodes[1].code ~= "ROOMCODE-1234567890", "wrong entry deleted")

entries = MenuEntries()
local _, renameIcon = RowIcons(entries[1])
renameIcon.scripts.OnClick()
assert(NamePane():IsShown(), "rename icon did not open the name pane")

NamePane().editBox:SetText("Spare Room")
NamePane().saveButton.scripts.OnClick()
assert(db.blueprintImportCodes[1].name == "Spare Room", "rename did not save")

-- Saving an empty name clears it.
entries = MenuEntries()
local _, renameAgain = RowIcons(entries[1])
renameAgain.scripts.OnClick()
NamePane().editBox:SetText("   ")
NamePane().saveButton.scripts.OnClick()
assert(db.blueprintImportCodes[1].name == nil, "empty name did not clear")

-- ─── The toggle stops recording and hides the button ─────────────────────────

db.blueprintImportHistory = false
LuckyGrabbag.BlueprintImportHistory:ApplySetting()
assert(not button:IsShown(), "button still shown with the setting off")

NamePane():Hide()
PressNext("IGNORED")
assert(db.blueprintImportCodes[1].code ~= "IGNORED", "recorded while switched off")
assert(not NamePane():IsShown(), "pane opened while switched off")

print("BlueprintImportHistoryTest: all assertions passed")
