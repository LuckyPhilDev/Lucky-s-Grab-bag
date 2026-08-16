-- luacheck: globals C_Timer ATTACHMENTS_MAX_SEND CreateFrame GetSendMailItem
-- luacheck: globals SetSendMailShowing SendMail InCombatLockdown strtrim
-- luacheck: globals hooksecurefunc SendMailFrame SendMailNameEditBox
-- luacheck: globals SendMailSubjectEditBox SendMailBodyEditBox print

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
        runFrame:Fire("MAIL_SEND_SUCCESS")
    end)
end

function InCombatLockdown() return false end

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
            local batch = math.min(ATTACHMENTS_MAX_SEND, world.inCategory)
            world.inCategory = world.inCategory - batch
            world.attached   = batch
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
    hooks.CallMethodOnNearestAncestor(categoryButton, "TransferCategory")
end

local function SendAll(inCategory)
    Reset(inCategory)
    LuckyGrabbag.MailSendAll:SendAll()
    RunTimers()
end

-- ─── Checks ──────────────────────────────────────────────────────────────────

SendAll(30)
assert(world.mailsSent == 3, "30 items should take 3 mails, took " .. world.mailsSent)
assert(world.inCategory == 0, "the category should be empty, " .. world.inCategory .. " left")

SendAll(12)
assert(world.mailsSent == 1, "an exact bagful should take 1 mail, took " .. world.mailsSent)

SendAll(0)
assert(world.mailsSent == 0, "an empty category should send nothing")
assert(lastPrinted:find("Nothing"), "an empty category should say so, said: " .. tostring(lastPrinted))

-- Far more than the runaway guard allows.
SendAll(12 * 60)
assert(world.mailsSent == 30, "the guard should cap the run at 30 mails, sent " .. world.mailsSent)
assert(world.inCategory > 0, "a capped run should leave the rest in the bags")

Reset(30)
SendMailNameEditBox.text = "  "
LuckyGrabbag.MailSendAll:SendAll()
RunTimers()
assert(world.mailsSent == 0, "no recipient should send nothing")
assert(lastPrinted:find("recipient"), "no recipient should say so, said: " .. tostring(lastPrinted))

-- Baganator pools its header buttons, so a remembered one can come back pointing
-- somewhere else entirely.
Reset(30)
categoryButton.sourceKey = "consumables"
LuckyGrabbag.MailSendAll:SendAll()
RunTimers()
categoryButton.sourceKey = "trade-goods"
assert(world.mailsSent == 0, "a recycled category button should send nothing")
assert(lastPrinted:find("no longer on screen"), "a recycled button should say so, said: " .. tostring(lastPrinted))

realPrint("MailSendAll: all checks passed")
