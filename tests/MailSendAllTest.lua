-- luacheck: globals C_Timer ATTACHMENTS_MAX_SEND CreateFrame GetSendMailItem
-- luacheck: globals SetSendMailShowing SendMail InCombatLockdown strtrim
-- luacheck: globals hooksecurefunc SendMailFrame SendMailNameEditBox
-- luacheck: globals SendMailSubjectEditBox SendMailBodyEditBox print IsAltKeyDown

-- Covers the send loop in features/MailSendAll.lua: it has to drain a category
-- across as many mails as it takes, stop when the category runs dry, and stop
-- itself before it can run away. The whole thing is timers and WoW mail globals,
-- so the mailbox is stubbed with a virtual clock the test pumps by hand.
--
-- Run from the addon root: lua tests/MailSendAllTest.lua

-- ─── Virtual clock ───────────────────────────────────────────────────────────

local now, timers = 0, {}

C_Timer = { After = function(delay, fn) table.insert(timers, { at = now + delay, fn = fn }) end }

local function RunTimers()
    for _ = 1, 20000 do
        local next, nextIndex
        for i, timer in ipairs(timers) do
            if not next or timer.at < next.at then next, nextIndex = timer, i end
        end
        if not next then return end
        table.remove(timers, nextIndex)
        now = next.at
        next.fn()
    end
    error("timers never drained")
end

-- ─── Stubbed mailbox ─────────────────────────────────────────────────────────

local world = { inCategory = 0, attached = 0, mailsSent = 0 }

local runFrame

ATTACHMENTS_MAX_SEND = 12

function CreateFrame()
    runFrame = {
        events = {},
        RegisterEvent      = function(self, event) self.events[event] = true end,
        UnregisterAllEvents = function(self) self.events = {} end,
        SetScript          = function(self, _, fn) self.onEvent = fn end,
        Fire               = function(self, event)
            if self.events[event] then self.onEvent(self, event) end
        end,
    }
    return runFrame
end

function GetSendMailItem(index)
    if index <= world.attached then return "Item " .. index, 1000 + index end
end

function SetSendMailShowing() end

function SendMail()
    C_Timer.After(0.1, function()
        world.mailsSent = world.mailsSent + 1
        world.attached  = 0
        if world.onSent then world.onSent() end
        runFrame:Fire("MAIL_SEND_SUCCESS")
    end)
end

function InCombatLockdown() return false end

local altDown = false
function IsAltKeyDown() return altDown end

function strtrim(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end

local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end

SendMailFrame = { IsShown = function() return true end }

local function EditBox(text)
    return { text = text, GetText = function(self) return self.text end }
end

SendMailNameEditBox    = EditBox("Bankalt")
SendMailSubjectEditBox = EditBox("")
SendMailBodyEditBox    = EditBox("")

local lastPrinted
local realPrint = print
print = function(msg) lastPrinted = msg end ---@diagnostic disable-line: lowercase-global

-- A Baganator category header: right-clicking it hands the next batch to the
-- post. The delay is longer than the settle window on purpose, so a batch that
-- is merely slow is not mistaken for an empty category.
local ATTACH_DELAY = 0.9

local categoryButton = {
    sourceKey = "trade-goods",
    Click = function()
        C_Timer.After(ATTACH_DELAY, function()
            -- Only free slots get filled, so a second click on a full post is a no-op.
            local batch = math.min(ATTACHMENTS_MAX_SEND - world.attached, world.inCategory)
            world.inCategory = world.inCategory - batch
            world.attached   = world.attached + batch
        end)
    end,
}

-- ─── Addon under test ────────────────────────────────────────────────────────

dofile("src/Strings.lua")
LuckyGrabbag.PREFIX = LuckyGrabbag.Strings.addon.prefix
dofile("src/features/MailSendAll.lua")

LuckyGrabbag.MailSendAll:Init({ mailSendAll = true })

local function Reset(inCategory)
    now, timers = 0, {}
    world = { inCategory = inCategory, attached = 0, mailsSent = 0 }
    lastPrinted = nil
    SendMailNameEditBox.text = "Bankalt"
end

-- Baganator attaches its own bagful before the hook sees the click, which the
-- stub button models by scheduling the same batch move.
local function RightClick(withAlt)
    altDown = withAlt
    categoryButton.Click()
    hooks.CallMethodOnNearestAncestor(categoryButton, "TransferCategory")
    altDown = false
    RunTimers()
end

local function AltRightClick(inCategory)
    Reset(inCategory)
    RightClick(true)
end

-- ─── Checks ──────────────────────────────────────────────────────────────────

AltRightClick(30)
assert(world.mailsSent == 3, "30 items should take 3 mails, took " .. world.mailsSent)
assert(world.inCategory == 0, "the category should be empty, " .. world.inCategory .. " left")

AltRightClick(12)
assert(world.mailsSent == 1, "an exact bagful should take 1 mail, took " .. world.mailsSent)

AltRightClick(0)
assert(world.mailsSent == 0, "an empty category should send nothing")
assert(lastPrinted:find("Nothing"), "an empty category should say so, said: " .. tostring(lastPrinted))

-- Far more than the runaway guard allows.
AltRightClick(12 * 60)
assert(world.mailsSent == 30, "the guard should cap the run at 30 mails, sent " .. world.mailsSent)
assert(world.inCategory > 0, "a capped run should leave the rest in the bags")

-- A plain right-click is Baganator's own one-bagful transfer, untouched.
Reset(30)
RightClick(false)
assert(world.mailsSent == 0, "a plain right-click should send nothing")

-- Alt-right-click away from a mailbox vendors or banks, so this must stay quiet.
Reset(30)
SendMailFrame.IsShown = function() return false end
RightClick(true)
SendMailFrame.IsShown = function() return true end
assert(world.mailsSent == 0, "away from a mailbox nothing should send")
assert(lastPrinted == nil, "away from a mailbox nothing should be said, said: " .. tostring(lastPrinted))

Reset(30)
SendMailNameEditBox.text = "  "
RightClick(true)
assert(world.mailsSent == 0, "no recipient should send nothing")
assert(lastPrinted:find("recipient"), "no recipient should say so, said: " .. tostring(lastPrinted))

-- Reopening the bag part way through a run can recycle the header button onto a
-- different category, which has to end the run rather than mail the wrong things.
Reset(60)
world.onSent = function()
    if world.mailsSent == 1 then categoryButton.sourceKey = "consumables" end
end
RightClick(true)
categoryButton.sourceKey = "trade-goods"
assert(world.mailsSent == 1, "a recycled button should stop the run, sent " .. world.mailsSent)
assert(lastPrinted:find("no longer on screen"), "a recycled button should say so, said: " .. tostring(lastPrinted))

realPrint("MailSendAll: all checks passed")
