-- Lucky's Grab-bag: Thalassian Treatise auto-withdrawal
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Treatise = {}

local TREATISES = LuckyGrabbag.TreatiseData  -- defined in TreatiseData.lua

local db

local function DevLog(msg)
    LuckyGrabbag.DevLog("Treatise", msg)
end

-- Returns a map of skillLineID -> profession name for the current character's professions.
-- GetProfessionInfo returns: name, texture, rank, maxRank, numSpells, spellOffset, skillLine, ...
local function GetCharacterSkillLines()
    local skillLines = {}
    local indices = { GetProfessions() }
    DevLog("GetProfessions() returned " .. #indices .. " indices")
    for _, idx in ipairs(indices) do
        if idx then
            local name, _, _, _, _, _, skillLine = GetProfessionInfo(idx)
            if skillLine then
                skillLines[skillLine] = name
                DevLog("  Profession: " .. tostring(name) .. " (skillLineID=" .. tostring(skillLine) .. ")")
            else
                DevLog("  GetProfessionInfo(" .. tostring(idx) .. ") returned nil skillLine")
            end
        end
    end
    return skillLines
end

-- Checks whether the character meets all item requirements (e.g. profession skill level) by
-- inspecting the item tooltip. WoW renders unmet requirements as red text (RED_FONT_COLOR).
-- This works regardless of which profession window is open and correctly reads expansion-specific
-- skill thresholds.
local function MeetsItemRequirements(itemID)
    local tooltipData = C_TooltipInfo.GetItemByID(itemID)
    if not tooltipData or not tooltipData.lines then
        DevLog("  MeetsItemRequirements: no tooltip data for itemID=" .. itemID .. " — assuming usable")
        return true
    end
    for _, line in ipairs(tooltipData.lines) do
        if line.leftColor and line.leftColor.r > 0.9 and line.leftColor.g < 0.3 and line.leftColor.b < 0.3 then
            DevLog("  MeetsItemRequirements: itemID=" .. itemID .. " has unmet requirement: " .. tostring(line.leftText))
            return false
        end
    end
    return true
end

-- Checks whether the character is eligible to use this treatise this week.
-- When a treatise is used it completes a hidden weekly quest — if already completed, skip.
local function IsEligibleThisWeek(questID, profName)
    local completed = C_QuestLog.IsQuestFlaggedCompleted(questID)
    DevLog("  QuestID " .. questID .. " (" .. profName .. ") completed=" .. tostring(completed))
    return not completed
end

local function FindEmptyBagSlot()
    for bag = 0, NUM_BAG_SLOTS do
        local freeSlots = C_Container.GetContainerFreeSlots(bag)
        if freeSlots and #freeSlots > 0 then
            return bag, freeSlots[1]
        end
    end
    return nil, nil
end

local function IsItemInBags(itemID)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return true
            end
        end
    end
    return false
end

-- Polls until condition() is true or timeout elapses. Calls onReady(true) on success,
-- onReady(false) on timeout. interval and timeout are in seconds.
local function WaitFor(condition, onReady, interval, timeout)
    interval = interval or 0.05
    timeout = timeout or 1.0
    local elapsed = 0
    local function tick()
        if condition() then
            onReady(true)
            return
        end
        elapsed = elapsed + interval
        if elapsed >= timeout then
            onReady(false)
            return
        end
        C_Timer.After(interval, tick)
    end
    C_Timer.After(interval, tick)
end

-- Waits for a single BAG_UPDATE_DELAYED event, then calls onReady. Falls back to onReady
-- after a max wait in case no event fires (nothing moved).
local function WaitForBagUpdate(onReady, maxWait)
    maxWait = maxWait or 1.0
    local frame = CreateFrame("Frame")
    local done = false
    local function finish()
        if done then return end
        done = true
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        onReady()
    end
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:SetScript("OnEvent", finish)
    C_Timer.After(maxWait, finish)
end

local function FindAndWithdrawTreatise(itemID, profName, onDone)
    local function done() if onDone then onDone() end end

    if IsItemInBags(itemID) then
        DevLog("  " .. profName .. " treatise already in bags — skipping")
        return false
    end
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if not tabIDs or #tabIDs == 0 then
        DevLog("  No warband bank tabs found via C_Bank.FetchPurchasedBankTabIDs")
        return false
    end
    DevLog("  Warband bank tabs: " .. #tabIDs)
    for tabNum, bagIndex in ipairs(tabIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagIndex)
        DevLog("  Tab " .. tabNum .. " (bagIndex=" .. tostring(bagIndex) .. "): " .. numSlots .. " slots")
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagIndex, slot)
            if info then
                DevLog("    Slot " .. slot .. ": itemID=" .. tostring(info.itemID) .. " (want " .. itemID .. ")")
                if info.itemID == itemID then
                    local stackCount = info.stackCount or 1
                    DevLog("    Match — stack=" .. stackCount .. ", taking 1")
                    ClearCursor()
                    if stackCount > 1 then
                        C_Container.SplitContainerItem(bagIndex, slot, 1)
                    else
                        C_Container.PickupContainerItem(bagIndex, slot)
                    end

                    -- Wait for cursor to actually hold the item before placing. SplitContainerItem
                    -- is async; placing too early strands the item in the warband tab with its slot
                    -- locked, which then blocks the next withdrawal until the bank is reopened.
                    WaitFor(CursorHasItem, function(ok)
                        if not ok then
                            DevLog("    Cursor never picked up item — aborting this withdrawal")
                            ClearCursor()
                            done()
                            return
                        end
                        local destBag, destSlot = FindEmptyBagSlot()
                        if not destBag then
                            DevLog("    No empty bag slot — clearing cursor")
                            ClearCursor()
                            done()
                            return
                        end
                        DevLog("    Placing into bag=" .. destBag .. " slot=" .. destSlot)
                        C_Container.PickupContainerItem(destBag, destSlot)
                        print(LuckyGrabbag.PREFIX .. " Withdrawn " .. profName .. " treatise.")
                        -- Wait for bag state to settle before allowing the next withdrawal to
                        -- scan the warband tab, otherwise the tab data can be stale.
                        WaitForBagUpdate(done)
                    end, 0.05, 1.0)
                    return true
                end
            end
        end
    end
    DevLog("  itemID " .. itemID .. " not found in any Warband Bank tab")
    return false
end

local function WithdrawEligibleTreatises()
    DevLog("Scanning for eligible treatises")
    local skillLines = GetCharacterSkillLines()

    -- Build a queue of eligible treatises to avoid cursor race conditions
    -- when multiple treatises need withdrawing.
    local queue = {}
    for _, treatise in ipairs(TREATISES) do
        if skillLines[treatise.skillLineID] and IsPlayerSpell(treatise.midnightSpellID) then
            DevLog("Checking " .. treatise.name .. " (itemID=" .. treatise.itemID .. " questID=" .. treatise.questID .. ")")
            if not MeetsItemRequirements(treatise.itemID) then
                DevLog("  Skipping " .. treatise.name .. " — unmet item requirements (skill too low)")
            elseif not IsEligibleThisWeek(treatise.questID, treatise.name) then
                DevLog("  Skipping " .. treatise.name .. " — already used this week")
            else
                table.insert(queue, treatise)
            end
        end
    end

    -- Process one treatise at a time; each withdrawal's onDone callback starts the next.
    local function processNext()
        if #queue == 0 then return end
        local treatise = table.remove(queue, 1)
        local withdrawn = FindAndWithdrawTreatise(treatise.itemID, treatise.name, processNext)
        if not withdrawn then
            processNext()  -- nothing to wait for, move on immediately
        end
    end
    processNext()
end

-- Returns true if the given itemID is a treatise the character can use.
-- The character must have learned the Midnight expansion version of the profession.
function LuckyGrabbag.Treatise:CanCharacterUse(itemID)
    for _, treatise in ipairs(TREATISES) do
        if treatise.itemID == itemID then
            local known = IsPlayerSpell(treatise.midnightSpellID)
            if not known then
                DevLog("CanCharacterUse: " .. treatise.name .. " itemID=" .. itemID .. " known=false")
                return false
            end
            local meetsReqs = MeetsItemRequirements(itemID)
            DevLog("CanCharacterUse: " .. treatise.name .. " itemID=" .. itemID .. " meetsReqs=" .. tostring(meetsReqs))
            return meetsReqs
        end
    end
    -- Not a treatise item — assume usable (shouldn't be called for non-treatises)
    return true
end

-- Returns true if the given itemID is a treatise whose weekly quest is already completed.
-- Used by UseItems to hide buttons for treatises that can't be used again this week.
function LuckyGrabbag.Treatise:IsUsedThisWeek(itemID)
    for _, treatise in ipairs(TREATISES) do
        if treatise.itemID == itemID then
            local completed = C_QuestLog.IsQuestFlaggedCompleted(treatise.questID)
            DevLog("IsUsedThisWeek: " .. treatise.name .. " itemID=" .. itemID .. " questID=" .. treatise.questID .. " completed=" .. tostring(completed))
            return completed
        end
    end
    DevLog("IsUsedThisWeek: itemID=" .. tostring(itemID) .. " not found in TREATISES table")
    return false
end

function LuckyGrabbag.Treatise:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:SetScript("OnEvent", function()
        DevLog("BANKFRAME_OPENED received")
        C_Timer.After(0.2, function()
            DevLog("Timer fired — showTreatise=" .. tostring(db.showTreatise))
            if db.showTreatise then
                WithdrawEligibleTreatises()
            end
        end)
    end)
end
