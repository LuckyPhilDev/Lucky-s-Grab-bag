-- luacheck: globals CreateFrame UIParent ContainerFrameCombinedBags GamepadBagBar IsUsingGamepad
-- luacheck: globals InCombatLockdown SmartNavigation hooksecurefunc
-- luacheck: globals SMART_NAV_INPUT_DIRECTION SmartNavigation_AddJumpNavigationOverride
-- luacheck: globals SmartNavigation_ClearJumpNavigationOverridesInDirection wipe
-- luacheck: globals LuckyUtils LuckyGrabbag
local scripts, events, visible, current, bagScripts, bagShown = {}, {}, false, nil, {}, true
local function widget()
    return setmetatable({}, { __index = function(_, key)
        if key == "CreateTexture" then return widget end
        return function() end
    end })
end
local input = widget()
function input:SetScript(name, fn) scripts[name] = fn end
function input:RegisterEvent(name) events[name] = true end
function input:SetShown(value) visible = value end
function input:IsShown() return visible end
function CreateFrame() return input end
UIParent = {}
local first = { IsVisible = function() return true end, GetCenter = function() return 10, 10 end,
    GetWidth = function() return 20 end, GetHeight = function() return 20 end, GetEffectiveScale = function() return 1 end }
local second = { IsVisible = function() return true end, GetCenter = function() return 30, 10 end,
    GetWidth = first.GetWidth, GetHeight = first.GetHeight, GetEffectiveScale = first.GetEffectiveScale }
local below = { IsVisible = function() return true end, GetCenter = function() return 20, -10 end,
    GetWidth = first.GetWidth, GetHeight = first.GetHeight }
ContainerFrameCombinedBags = { Items = { first, second, below }, IsShown = function() return bagShown end,
    HookScript = function(_, name, fn) bagScripts[name] = fn end }
local bagButton = { IsVisible = function() return true end, GetCenter = function() return 20, 10 end,
    GetWidth = first.GetWidth, GetHeight = first.GetHeight }
GamepadBagBar = { BagButtonArray = { bagButton } }
SMART_NAV_INPUT_DIRECTION = { LEFT = { dirKey = "left" }, RIGHT = { dirKey = "right" },
    UP = { dirKey = "up" }, DOWN = { dirKey = "down" } }
function SmartNavigation_AddJumpNavigationOverride(button, direction, target)
    button["smartNavigationOverride-" .. direction.dirKey] = target
end
function SmartNavigation_ClearJumpNavigationOverridesInDirection(button, direction)
    button["smartNavigationOverride-" .. direction.dirKey] = nil
end
function wipe(t) for key in pairs(t) do t[key] = nil end end
function IsUsingGamepad() return true end
function InCombatLockdown() return false end
SmartNavigation = {
    GetActiveFrame = function() return ContainerFrameCombinedBags end,
    GetCurrentButton = function() return current end,
    SelectButton = function(_, item) current = item end,
    SetTargetButtonForFrame = function(self, _, item) self:SelectButton(item) end,
}
function hooksecurefunc(object, name, fn)
    local original = object[name]
    object[name] = function(...) original(...) fn(...) end
end
LuckyUtils = { IsForever = function() return true end }
LuckyGrabbag = { db = { controllerBags = true } }
dofile("src/features/ControllerBags.lua")
assert(not visible and events.GAME_PAD_ACTIVE_CHANGED)
bagScripts.OnShow()
assert(visible)
assert(not scripts.OnGamePadButtonDown)
local previous = {}
first["smartNavigationOverride-right"] = previous
SmartNavigation:SelectButton(first)
assert(first["smartNavigationOverride-right"] == bagButton)
SmartNavigation:SelectButton(second)
assert(first["smartNavigationOverride-right"] == previous)
assert(second["smartNavigationOverride-left"] == bagButton)
SmartNavigation:SelectButton(bagButton)
assert(second["smartNavigationOverride-left"] == nil)
assert(bagButton["smartNavigationOverride-left"] == first)
assert(bagButton["smartNavigationOverride-right"] == second)
assert(bagButton["smartNavigationOverride-down"] == below)
assert(bagButton["smartNavigationOverride-up"] == nil)
SmartNavigation:SelectButton(below)
assert(below["smartNavigationOverride-up"] == bagButton)
assert(below["smartNavigationOverride-down"] == nil)
LuckyGrabbag.db.controllerBags = false
LuckyGrabbag.ControllerBags.ApplySetting()
assert(not visible and below["smartNavigationOverride-up"] == nil)
LuckyGrabbag.db.controllerBags = true
LuckyGrabbag.ControllerBags.ApplySetting()
assert(visible and below["smartNavigationOverride-up"] == bagButton)
SmartNavigation:SelectButton(nil)
bagShown = false
bagScripts.OnHide()
assert(not visible)
