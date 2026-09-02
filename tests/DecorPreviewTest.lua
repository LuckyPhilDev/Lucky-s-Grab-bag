-- luacheck: globals CreateFrame UIParent MerchantFrame GameTooltip Enum
-- luacheck: globals C_HousingCatalog Constants TooltipDataProcessor LuckyUI LuckyStrings LuckyGrabbag

-- Covers features/DecorPreview.lua: which hovered vendor items put a model
-- beside the window, and everything that has to take it away again. The hovered
-- item is read off the tooltip rather than the button, because vendor UI
-- replacements rewrite both the merchant buttons and their item indices.
--
-- Run from the addon root: lua tests/DecorPreviewTest.lua

-- ─── Stubbed world ───────────────────────────────────────────────────────────

local noop = function() return nil end

local function Widget(name)
    local w = { shown = false, scripts = {}, name = name }
    w.SetScript  = function(self, event, fn) self.scripts[event] = fn end
    w.HookScript = w.SetScript
    w.Show       = function(self) self.shown = true end
    w.Hide       = function(self) self.shown = false end
    w.IsShown    = function(self) return self.shown end
    w.GetName    = function(self) return self.name end
    w.SetText    = function(self, text) self.text = text end
    w.CreateFontString = function() return Widget() end
    w.CreateTexture    = function() return Widget() end
    return setmetatable(w, { __index = function(_, key)
        if type(key) == "string" and key:match("^[A-Z]") then return noop end
    end })
end

local actor = Widget()
actor.SetModelByFileID = function(self, fileID) self.fileID = fileID end
actor.SetYaw = function(self, yaw) self.yaw = yaw end

local scene
function CreateFrame(frameType)
    local w = Widget()
    if frameType == "ModelScene" then
        w.TransitionToModelSceneID = function(self, sceneID) self.sceneID = sceneID end
        w.GetActorByTag = function() return actor end
        scene = w
    end
    return w
end

local panel
UIParent = Widget()
UIParent.GetRight = function() return 1920 end
MerchantFrame = Widget()
MerchantFrame:Show()

local owner = Widget("MerchantItem7ItemButton")
GameTooltip = Widget()
GameTooltip.GetOwner = function() return owner end
GameTooltip.GetRight = function() return GameTooltip.right end
GameTooltip.right = 900

LuckyUI = {
    CreatePanel = function()
        panel = Widget()
        panel.points = {}
        panel.ClearAllPoints = function(self) self.points = {} end
        panel.SetPoint = function(self, ...) self.points = { ... } end
        return panel
    end,
}

Constants = { HousingCatalogConsts = { HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT = 900 } }
Enum = { TooltipDataType = { Item = 0 } }

local catalog = {}
C_HousingCatalog = { GetCatalogEntryInfoByItem = function(itemID) return catalog[itemID] end }

local tooltipHook
TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, fn)
        if dataType == Enum.TooltipDataType.Item then tooltipHook = fn end
    end,
}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
LuckyGrabbag.Logger = function() return noop end

dofile("src/features/DecorPreview.lua")

local db = { decorVendorPreview = true }
LuckyGrabbag.DecorPreview:Init(db)

local function Hover(itemID) tooltipHook(GameTooltip, { id = itemID }) end
local function Frame(elapsed) panel.scripts.OnUpdate(panel, elapsed) end

catalog[1] = { recordID = 11, name = "Gilded Bench", asset = 4242, uiModelSceneID = 77 }
catalog[3] = { recordID = 33, name = "Assetless Decor" }
catalog[4] = { recordID = 44, name = "Sceneless Decor", asset = 5150 }

-- ─── Checks ──────────────────────────────────────────────────────────────────

Hover(1)
assert(panel:IsShown(), "hovering decor should show the preview")
assert(scene.sceneID == 77, "the entry's own scene should be used, got " .. tostring(scene.sceneID))
assert(actor.fileID == 4242, "the decor model should load, got " .. tostring(actor.fileID))
assert(panel.points[1] == "TOPLEFT" and panel.points[3] == "TOPRIGHT",
    "with room to the right the preview should sit right of the tooltip")

Hover(2)
assert(not panel:IsShown(), "a plain vendor item should take the preview away")

-- An entry with no scene of its own still has to be framed by something.
Hover(4)
assert(panel:IsShown() and scene.sceneID == 900,
    "no scene on the entry should fall back to the default, got " .. tostring(scene.sceneID))

actor.fileID = nil
Hover(3)
assert(not panel:IsShown(), "decor with no model asset should not be previewed")
assert(actor.fileID == nil, "decor with no model asset should load nothing")

-- A tooltip somewhere else on screen must not drive the vendor preview.
Hover(1)
owner.name = "ContainerFrame1Item3"
actor.fileID = nil
Hover(3)
assert(panel:IsShown() and actor.fileID == nil, "a bag tooltip should leave the preview alone")
owner.name = "MerchantItem7ItemButton"

-- The tooltip refreshes itself while hovered; reloading would restart the turn.
Hover(1)
Frame(1)
local turned = actor.yaw
Hover(1)
Frame(1)
assert(actor.yaw > turned, "a refreshed tooltip should not restart the turntable, yaw " .. tostring(actor.yaw))

-- A tooltip near the right edge leaves no room, so the preview swaps sides.
GameTooltip.right = 1800
Frame(0)
assert(panel.points[1] == "TOPRIGHT" and panel.points[3] == "TOPLEFT",
    "with no room to the right the preview should flip to the left of the tooltip")
GameTooltip.right = 900

GameTooltip.scripts.OnHide()
assert(not panel:IsShown(), "the preview should go when the tooltip does")

MerchantFrame:Hide()
Hover(1)
assert(not panel:IsShown(), "away from a vendor nothing should preview")
MerchantFrame:Show()

db.decorVendorPreview = false
Hover(1)
LuckyGrabbag.DecorPreview:ApplySetting()
assert(not panel:IsShown(), "with the setting off nothing should show")

print("DecorPreview: all checks passed")
