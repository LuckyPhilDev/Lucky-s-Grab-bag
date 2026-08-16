-- Lucky's Grab-bag: Mail a whole Baganator category, one bag of attachments at a time.
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.MailSendAll = {
    requires = { addon = "Baganator" },
}

local MAX_MAILS      = 30
local SETTLE_STEP    = 0.2
local SETTLE_STABLE  = 2
local SETTLE_TIMEOUT = 4
local SEND_TIMEOUT   = 10

local db, runFrame
local categoryButton, categoryIdentity
local running, recipient, subject, body, mailsSent

BINDING_NAME_LUCKYGRABBAG_MAIL_SEND_ALL = LuckyGrabbag.Strings.mailSendAll.bindingName

local function Say(msg)
    print(LuckyGrabbag.PREFIX .. " " .. msg)
end

local function AttachmentCount()
    local count = 0
    for i = 1, ATTACHMENTS_MAX_SEND do
        if select(2, GetSendMailItem(i)) then count = count + 1 end
    end
    return count
end

local function Stop(message)
    running = false
    runFrame:UnregisterAllEvents()
    if message then Say(message) end
end

-- Attachments only appear a server round-trip after the item moves, so wait for
-- the count to stop climbing rather than guessing a delay. An empty slate never
-- settles early, because a slow first item is indistinguishable from an empty
-- category until the timeout is up.
local function WhenAttachmentsSettle(onSettled)
    local lastCount, stableTicks, waited = -1, 0, 0
    local function Poll()
        if not running then return end
        local count = AttachmentCount()
        if count == lastCount then
            stableTicks = stableTicks + 1
        else
            lastCount, stableTicks = count, 0
        end
        waited = waited + SETTLE_STEP
        if (count > 0 and stableTicks >= SETTLE_STABLE) or waited >= SETTLE_TIMEOUT then
            onSettled(count)
        else
            C_Timer.After(SETTLE_STEP, Poll)
        end
    end
    C_Timer.After(SETTLE_STEP, Poll)
end

local function SendCurrentBatch()
    local S = LuckyGrabbag.Strings.mailSendAll
    if AttachmentCount() == 0 then
        Stop(string.format(S.finished, mailsSent))
        return
    end

    -- Postage shortfalls and Blizzard's send throttle arrive as a UI error with
    -- no MAIL_FAILED, so a silent send has to time out.
    local sentSoFar = mailsSent
    SendMail(recipient, subject, body)
    C_Timer.After(SEND_TIMEOUT, function()
        if running and mailsSent == sentSoFar then Stop(S.timedOut) end
    end)
end

local function AttachNextBatch(onEmpty)
    SetSendMailShowing(true)
    categoryButton:Click("RightButton")
    WhenAttachmentsSettle(function(count)
        if count == 0 then onEmpty() else SendCurrentBatch() end
    end)
end

local function OnEvent(_, event)
    if not running then return end
    local S = LuckyGrabbag.Strings.mailSendAll

    if event ~= "MAIL_SEND_SUCCESS" then
        Stop(string.format(S.interrupted, mailsSent))
        return
    end

    mailsSent = mailsSent + 1
    if mailsSent >= MAX_MAILS then
        Stop(string.format(S.hitLimit, mailsSent))
        return
    end

    AttachNextBatch(function() Stop(string.format(S.finished, mailsSent)) end)
end

function LuckyGrabbag.MailSendAll:SendAll()
    local S = LuckyGrabbag.Strings.mailSendAll
    if not db.mailSendAll then return end
    if running then Stop(string.format(S.cancelled, mailsSent)) return end
    if InCombatLockdown() then Say(S.inCombat) return end
    if not (SendMailFrame and SendMailFrame:IsShown()) then Say(S.notAtMailbox) return end
    if not categoryButton then Say(S.noCategory) return end

    -- Baganator pools its header buttons, so a remembered one can be pointing at
    -- a different category by the time the key is pressed.
    if (categoryButton.sourceKey or categoryButton.source) ~= categoryIdentity then
        categoryButton = nil
        Say(S.categoryChanged)
        return
    end

    recipient = strtrim(SendMailNameEditBox:GetText() or "")
    if recipient == "" then Say(S.noRecipient) return end

    -- Sending resets the form, so the wording is captured once for the whole run.
    subject = strtrim(SendMailSubjectEditBox:GetText() or "")
    if subject == "" then subject = S.defaultSubject end
    body = SendMailBodyEditBox:GetText() or ""

    running, mailsSent = true, 0
    runFrame:RegisterEvent("MAIL_SEND_SUCCESS")
    runFrame:RegisterEvent("MAIL_FAILED")
    runFrame:RegisterEvent("MAIL_CLOSED")
    runFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

    AttachNextBatch(function() Stop(S.nothingToSend) end)
end

function LuckyGrabbag.MailSendAll:Init(database)
    db = database

    runFrame = CreateFrame("Frame")
    runFrame:SetScript("OnEvent", OnEvent)

    hooksecurefunc("CallMethodOnNearestAncestor", function(frame, method)
        if method == "TransferCategory" or method == "TransferSection" then
            categoryButton   = frame
            categoryIdentity = frame.sourceKey or frame.source
        end
    end)
end
