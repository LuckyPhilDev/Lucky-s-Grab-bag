-- luacheck: globals UIParent MerchantFrame StaticPopup1 GetMouseFoci CreateFrame Enum LuckyLog LuckyGrabbag
local noop = function() end
local function frame(name)
    local f = { name = name, scripts = {}, visible = true }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:IsVisible() return self.visible end
    function f:IsShown() return self.visible end
    function f:HookScript(event, fn) self.scripts[event] = fn end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:SetPoint(...) self.point = { ... } end
    function f:ClearAllPoints() self.point = nil end
    function f:Show() self.visible = true end
    function f:Hide() self.visible = false end
    return setmetatable(f, { __index = function() return noop end })
end
UIParent, MerchantFrame, StaticPopup1 = frame(), frame(), frame()
StaticPopup1.which = 'CONFIRM_BUY_ITEM'
local focus, tick, eventFrame
function GetMouseFoci() return { focus } end
function CreateFrame() local f = frame(); if not eventFrame then eventFrame = f end; return f end
LuckyGrabbag = { Logger = function() return noop end, EnableGroupDrag = function(f) f.RestorePosition = noop; f.RegisterDraggable = noop end,
    CreateIconButton = function() tick = frame(); tick.GetPushedTexture = function() return frame() end; return tick end }
Enum = {}
LuckyGrabbag.Strings = LuckyGrabbag.Strings or { addon = { prefix = "test" } }
LuckyLog = { New = function() return noop end }
Enum.BagIndex = { ReagentBag = 5 }
dofile("src/UIHelpers.lua")
LuckyGrabbag.Logger = function() return noop end
LuckyGrabbag.EnableGroupDrag = function(f) f.RestorePosition = noop; f.RegisterDraggable = noop end
LuckyGrabbag.CreateIconButton = function() tick = frame(); tick.GetPushedTexture = function() return frame() end; return tick end

dofile('src/features/ConfirmPurchase.lua')
local db = { showConfirmPurchase = true, confirmPurchaseOnSide = false }
LuckyGrabbag.ConfirmPurchase:Init(db)
eventFrame.scripts.OnEvent(eventFrame, 'MERCHANT_SHOW')
focus = frame('KrowiEVU_MerchantItem23ItemButton')
StaticPopup1.scripts.OnShow(StaticPopup1)
assert(tick.point[2] == focus, 'confirmation tick must overlay the clicked Krowi item')
StaticPopup1.scripts.OnHide()
local child = frame('ChildTexture')
child.parent = focus
focus = child
StaticPopup1.scripts.OnShow(StaticPopup1)
assert(tick.point[2] == child.parent, 'child focus must resolve to the merchant button')
db.confirmPurchaseOnSide = true
LuckyGrabbag.ConfirmPurchase:ApplySetting()
assert(tick.point[2] ~= child.parent, 'side setting must keep the tick beside the vendor')
print('ConfirmPurchase: all checks passed')
