-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip wipe print
-- luacheck: globals hooksecurefunc C_Container GetCursorInfo ClearCursor
-- luacheck: globals DeleteCursorItem StaticPopup1 StaticPopup_Hide LuckySettings
-- luacheck: globals EnumerateFrames

-- Covers features/MassDelete.lua: the Mass Delete button rides the game's own
-- delete popup, bag clicks toggle items in and out of the queue, and the
-- Delete button drains the queue one item per hardware click, which is the
-- limit Blizzard put on DeleteCursorItem in 9.1.5. The stub enforces that
-- limit, so a regression into loop-deleting fails here instead of in game.
--
-- Run from the addon root: lua tests/MassDeleteTest.lua

-- ─── Generic widget ──────────────────────────────────────────────────────────

local noop = function() end

local function Widget()
    local w = {
        shown = false, enabled = true, scripts = {},
    }
    w.SetScript   = function(self, event, fn) self.scripts[event] = fn end
    w.HookScript  = w.SetScript
    w.Show        = function(self)
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    w.Hide        = function(self)
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    w.IsShown     = function(self) return self.shown end
    w.SetShown    = function(self, shown) self.shown = shown end
    w.Click       = function(self) self.scripts.OnClick(self) end
    w.SetText     = function(self, text) self.text = text end
    w.GetText     = function(self) return self.text end
    w.SetEnabled  = function(self, enabled) self.enabled = enabled end
    w.IsEnabled   = function(self) return self.enabled end
    w.SetPoint    = function(self, point, rel, relPoint, x, y)
        self.point = { point, rel, relPoint, x, y }
    end
    w.SetHeight   = function(self, height) self.height = height end
    w.GetHeight   = function(self) return self.height or 0 end
    w.CreateTexture    = function() return Widget() end
    w.CreateFontString = function() return Widget() end
    -- Unknown methods no-op, but plain data fields (which, _lgb markers)
    -- read back nil like they do on a real frame.
    return setmetatable(w, { __index = function(_, key)
        if type(key) == "string" and key:match("^[A-Z]") then return noop end
    end })
end

function CreateFrame(_, name)
    local w = Widget()
    if name then _G[name] = w end
    return w
end

UIParent        = Widget()
GameTooltip     = Widget()
StaticPopup1    = Widget()
UISpecialFrames = {}

function wipe(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

function hooksecurefunc(tbl, name, fn)
    local original = tbl[name]
    tbl[name] = function(...)
        original(...)
        fn(...)
    end
end

-- The frames EnumerateFrames hands out: empty until a fake bag window opens.
local enumFrames = {}

function EnumerateFrames(current)
    if current == nil then return enumFrames[1] end
    for i, frame in ipairs(enumFrames) do
        if frame == current then return enumFrames[i + 1] end
    end
end

-- A bag window the way an addon draws one: an item button nested two frames
-- deep, plus a decoy frame and a hidden bag button that must both be skipped.
local function OpenFakeBags()
    local window = Widget()
    window.GetParent = function() return UIParent end
    window.GetName   = function() return "FakeBagWindow" end
    local section = Widget()
    section.GetParent = function() return window end
    local button = Widget()
    button.IsVisible = function() return true end
    button.GetBagID  = function() return 0 end
    button.GetParent = function() return section end
    local hidden = Widget()
    hidden.IsVisible = function() return false end
    hidden.GetBagID  = function() return 4 end
    enumFrames = { Widget(), hidden, button }
    return window
end

LuckySettings = {
    Rich = {
        FillBg   = noop,
        EdgeRule = noop,
        Font     = "font",
        Theme    = setmetatable({}, { __index = function() return { 1, 1, 1, 1 } end }),
    },
}

-- ─── Stubbed bags and cursor ─────────────────────────────────────────────────

local bags, cursor, deleteBudget
local world = { deleted = 0 }

C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and 10 or 0 end,
    GetContainerItemLink = function(bag, slot)
        local item = bags[bag] and bags[bag][slot]
        return item and item.link
    end,
    GetContainerItemInfo = function(bag, slot)
        local item = bags[bag] and bags[bag][slot]
        if not item then return end
        return {
            hyperlink  = item.link,
            iconFileID = item.icon or 1,
            stackCount = item.count or 1,
            isLocked   = item.locked or false,
        }
    end,
    PickupContainerItem = function(bag, slot)
        local item = bags[bag] and bags[bag][slot]
        if not cursor and item and not item.locked then
            item.locked = true
            cursor = { bag = bag, slot = slot }
        end
    end,
}

function GetCursorInfo()
    if not cursor then return end
    return "item", 1234, bags[cursor.bag][cursor.slot].link
end

function ClearCursor()
    if cursor then
        bags[cursor.bag][cursor.slot].locked = false
        cursor = nil
    end
end

function DeleteCursorItem()
    assert(cursor, "DeleteCursorItem with nothing on the cursor")
    -- Over budget, the real client blocks the call silently and the item
    -- stays on the cursor.
    if deleteBudget <= 0 then return end
    deleteBudget = deleteBudget - 1
    bags[cursor.bag][cursor.slot] = nil
    cursor = nil
    world.deleted = world.deleted + 1
end

function StaticPopup_Hide(which)
    if StaticPopup1.which == which then
        StaticPopup1.which = nil
        StaticPopup1:Hide()
    end
end

local lastPrinted
local realPrint = print
print = function(msg) lastPrinted = msg end ---@diagnostic disable-line: lowercase-global

-- ─── Addon under test ────────────────────────────────────────────────────────

dofile("src/Strings.lua")
LuckyGrabbag.PREFIX = LuckyGrabbag.Strings.addon.prefix
LuckyGrabbag.DevLog = function() end
LuckyGrabbag.Logger = function() return function() end end
dofile("src/features/MassDelete.lua")

local db = { massDelete = true }
LuckyGrabbag.MassDelete:Init(db)

-- ─── Drivers: everything a user does is one hardware event ───────────────────

local function Item(link, count)
    return { link = link, count = count or 1 }
end

local function Reset(bagSetup)
    local panel = _G.LGB_MassDeletePanel
    if panel and panel.shown then panel:Hide() end
    bags = bagSetup
    for bag = 0, 5 do bags[bag] = bags[bag] or {} end
    cursor, deleteBudget = nil, 0
    world.deleted = 0
    lastPrinted = nil
    enumFrames = {}
end

local function ShowPopup(which)
    StaticPopup1.which = which
    StaticPopup1:Show()
end

local function ClickButton(button)
    deleteBudget = 1
    button:Click()
end

local function ClickBagItem(bag, slot)
    deleteBudget = 1
    C_Container.PickupContainerItem(bag, slot)
end

local function WheelTick(button)
    deleteBudget = 1
    button.scripts.OnMouseWheel(button, -1)
end

-- Drag an item out of the bag the way the game does before its delete popup.
local function StartNativeDelete(bag, slot)
    ClickBagItem(bag, slot)
    ShowPopup("DELETE_ITEM")
end

local function Panel()      return _G.LGB_MassDeletePanel end
local function DeleteBtn()  return _G.LGB_MassDeleteButton end
local function OpenBtn()    return _G.LGB_MassDeleteOpenButton end

-- ─── Checks ──────────────────────────────────────────────────────────────────

local S = LuckyGrabbag.Strings.massDelete

-- The button appears on delete popups and only those, centered in a strip
-- opened along the dialog's bottom by stretching the popup.
Reset({ [0] = { Item("[Junk A]") } })
StaticPopup1.height = 100
ShowPopup("DELETE_ITEM")
assert(OpenBtn() and OpenBtn().shown, "the Mass Delete button should show on a delete popup")
assert(OpenBtn().point[1] == "BOTTOM" and OpenBtn().point[2] == StaticPopup1,
    "the button should sit centered at the bottom of the dialog")
assert(StaticPopup1.height == 132, "the popup should be stretched to make room, height " .. tostring(StaticPopup1.height))
StaticPopup_Hide("DELETE_ITEM")
ShowPopup("USE_NO_REFUND_CONFIRM")
assert(not OpenBtn().shown, "the Mass Delete button should stay off other popups")

-- Opening the list cancels the pending delete and seeds it as the first entry.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]", 5), Item("[Junk C]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
assert(Panel().shown, "the list should open")
assert(not StaticPopup1.shown, "the delete popup should be dismissed")
assert(cursor == nil, "the pending item should be back in its slot")
assert(DeleteBtn().text == S.deleteLast, "the seeded item should be the only entry, button says: " .. tostring(DeleteBtn().text))

-- Bag clicks toggle items in and out; empty slots do nothing.
ClickBagItem(0, 2)
assert(DeleteBtn().text == string.format(S.deleteNext, 2), "a bag click should queue the item")
assert(cursor == nil, "a queued item should not stay on the cursor")
ClickBagItem(0, 2)
assert(DeleteBtn().text == S.deleteLast, "clicking a queued item should remove it")
ClickBagItem(0, 9)
assert(DeleteBtn().text == S.deleteLast, "an empty slot should change nothing")
ClickBagItem(0, 2)

-- Each click deletes exactly one item; a sorted-away item is chased by link.
ClickButton(DeleteBtn())
assert(world.deleted == 1, "one click should delete one item, deleted " .. world.deleted)
assert(Panel().shown, "the list should stay open while items remain")
assert(Panel().point[1] == "BOTTOMLEFT" and Panel().point[2] == UIParent,
    "the first delete should pin the panel by its bottom edge so the button stays put")
bags[2][4] = bags[0][2] -- a bag sort moves the remaining item
bags[0][2] = nil
ClickButton(DeleteBtn())
assert(world.deleted == 2, "a moved item should be found by its link and deleted")
assert(not Panel().shown, "an emptied list should close")
assert(lastPrinted:find("Deleted 2 items"), "the run should be summed up, said: " .. tostring(lastPrinted))

-- The mouse wheel drains the list too, one item per notch.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]"), Item("[Junk C]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
ClickBagItem(0, 2)
ClickBagItem(0, 3)
WheelTick(DeleteBtn())
assert(world.deleted == 1, "one notch should delete one item, deleted " .. world.deleted)
WheelTick(DeleteBtn())
WheelTick(DeleteBtn())
assert(world.deleted == 3, "each notch should delete the next item, deleted " .. world.deleted)
assert(not Panel().shown, "a wheel-emptied list should close")

-- A notch the client refuses leaves the item queued and the cursor clean.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
ClickBagItem(0, 2)
deleteBudget = 0
DeleteBtn().scripts.OnMouseWheel(DeleteBtn(), -1)
assert(world.deleted == 0, "a blocked delete should not count")
assert(cursor == nil, "a blocked delete should not strand the item on the cursor")
assert(DeleteBtn().text == string.format(S.deleteNext, 2), "a blocked delete should keep the queue whole, button says: " .. tostring(DeleteBtn().text))
WheelTick(DeleteBtn())
assert(world.deleted == 1, "the next proper notch should carry on the run")

-- An item no longer in the bags is skipped with a note, not deleted.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
ClickBagItem(0, 2)
bags[0][1] = nil -- vendored mid-session
ClickButton(DeleteBtn())
assert(world.deleted == 0, "a vanished item should not count as deleted")
assert(lastPrinted:find("Skipped"), "a vanished item should be called out, said: " .. tostring(lastPrinted))
assert(DeleteBtn().text == S.deleteLast, "the rest of the queue should survive a skip")
ClickButton(DeleteBtn())
assert(world.deleted == 1 and lastPrinted:find("Deleted 1 item"), "the survivor should still delete")

-- Closing the list abandons the session and clicks stop queueing.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
Panel():Hide()
ClickBagItem(0, 2)
assert(cursor ~= nil, "after closing, a bag click should be a normal pickup again")
ClearCursor()

-- A delete popup during an open session adds the item instead of restarting.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
StartNativeDelete(0, 2)
ClickButton(OpenBtn())
assert(DeleteBtn().text == string.format(S.deleteNext, 2), "the second popup's item should join the queue, button says: " .. tostring(DeleteBtn().text))

-- The list anchors beside whatever window draws the bag slots, found from a
-- bag item button rather than a hardcoded frame name.
Reset({ [0] = { Item("[Junk A]") } })
local bagWindow = OpenFakeBags()
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
assert(Panel().point[2] == bagWindow, "the panel should anchor to the bag window, got " .. tostring(Panel().point[2]))
assert(Panel().point[1] == "TOPRIGHT" and Panel().point[3] == "TOPLEFT",
    "the panel should hang off the window's left edge with tops level")

-- No bag window on screen at entry: fall back, then snap over on the next bag click.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]") } })
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
assert(Panel().point[2] == UIParent, "with no bag window the panel should fall back to the screen")
bagWindow = OpenFakeBags()
ClickBagItem(0, 2)
assert(Panel().point[2] == bagWindow, "the first bag click should re-anchor beside the window")

-- Closing the bag window clears the list and puts the panel away.
Reset({ [0] = { Item("[Junk A]"), Item("[Junk B]") } })
bagWindow = OpenFakeBags()
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
ClickBagItem(0, 2)
bagWindow:Hide()
assert(not Panel().shown, "closing the bags should close the list")
ClickBagItem(0, 2)
assert(cursor ~= nil, "after the bags close the session should be over")
ClearCursor()

-- A second session against the same window still ends with it.
StartNativeDelete(0, 1)
ClickButton(OpenBtn())
assert(Panel().shown, "a new session should open against the same window")
assert(DeleteBtn().text == LuckyGrabbag.Strings.massDelete.deleteLast,
    "the abandoned session's items should not linger, button says: " .. tostring(DeleteBtn().text))
bagWindow:Hide()
assert(not Panel().shown, "closing the bags should still close the list")

-- Switched off, the button leaves the delete popup alone.
Reset({ [0] = { Item("[Junk A]") } })
db.massDelete = false
StartNativeDelete(0, 1)
assert(not OpenBtn().shown, "disabled, the button should stay hidden")
db.massDelete = true

realPrint("MassDelete: all checks passed")
