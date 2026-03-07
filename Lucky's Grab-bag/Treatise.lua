-- Lucky's Grab-bag: Thalassian Treatise auto-withdrawal
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Treatise = {}

-- skillLineID: stable WoW profession IDs (same across expansions, sourced from WeeklyKnowledge)
-- questID: weekly quest completed when the treatise is used (sourced from Wowhead spell data)
local TREATISES = {
    { name = "Alchemy",        skillLineID = 171, itemID = 245755, questID = 95127 },
    { name = "Blacksmithing",  skillLineID = 164, itemID = 245763, questID = 95128 },
    { name = "Enchanting",     skillLineID = 333, itemID = 245759, questID = 95129 },
    { name = "Engineering",    skillLineID = 202, itemID = 245809, questID = 83728  },
    { name = "Herbalism",      skillLineID = 182, itemID = 245761, questID = 95130 },
    { name = "Inscription",    skillLineID = 773, itemID = 245757, questID = 95131 },
    { name = "Jewelcrafting",  skillLineID = 755, itemID = 245760, questID = 95133 },
    { name = "Leatherworking", skillLineID = 165, itemID = 245758, questID = 95134 },
    { name = "Mining",         skillLineID = 186, itemID = 245762, questID = 95135 },
    { name = "Skinning",       skillLineID = 393, itemID = 245828, questID = 95136 },
    { name = "Tailoring",      skillLineID = 197, itemID = 245756, questID = 95137 },
}

local db

local PREFIX = "|cff00cc00Lucky:|r"
local DEV    = "|cffaaaaaa[Treatise]|r"

local function DevLog(msg)
    if db.devMode then
        print(PREFIX .. " " .. DEV .. " " .. msg)
    end
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

local function FindAndWithdrawTreatise(itemID, profName)
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
                    C_Timer.After(0.1, function()
                        local destBag, destSlot = FindEmptyBagSlot()
                        if destBag then
                            DevLog("    Placing into bag=" .. destBag .. " slot=" .. destSlot)
                            C_Container.PickupContainerItem(destBag, destSlot)
                            print(PREFIX .. " Withdrawn " .. profName .. " treatise.")
                        else
                            DevLog("    No empty bag slot — clearing cursor")
                            ClearCursor()
                        end
                    end)
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
    for _, treatise in ipairs(TREATISES) do
        if skillLines[treatise.skillLineID] then
            DevLog("Checking " .. treatise.name .. " (itemID=" .. treatise.itemID .. " questID=" .. treatise.questID .. ")")
            if IsEligibleThisWeek(treatise.questID, treatise.name) then
                FindAndWithdrawTreatise(treatise.itemID, treatise.name)
            else
                DevLog("  Skipping " .. treatise.name .. " — already used this week")
            end
        end
    end
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
