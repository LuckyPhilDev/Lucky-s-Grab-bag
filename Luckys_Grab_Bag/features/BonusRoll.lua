-- Lucky's Grab-bag: Bonus Roll auto-dismiss
-- Hooks BonusRollFrame:OnShow. When the popup appears in content the user
-- has chosen not to keep it for, clicks the Pass button to dismiss cleanly.
-- All settings are per-character (stored in LuckyGrabbagCharDB).

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.BonusRoll = {}
local BR = LuckyGrabbag.BonusRoll

local charDB

-- Maps detected context → per-character "keep popup here" flag
local KEEP_KEYS = {
    mythicplus = "bonusRollKeepInMythicPlus",
    raidLFR    = "bonusRollKeepInLFR",
    raidNormal = "bonusRollKeepInNormalRaid",
    raidHeroic = "bonusRollKeepInHeroicRaid",
    raidMythic = "bonusRollKeepInMythicRaid",
    delve      = "bonusRollKeepInDelve",
    dungeon    = "bonusRollKeepInDungeon",
    hunts      = "bonusRollKeepInHunts",
}

-- Raid difficulty IDs → context key. Anything raid-typed not listed here
-- (e.g. timewalking ID 33, legacy IDs) falls through to raidNormal.
local RAID_DIFFICULTY_TO_CONTEXT = {
    [17] = "raidLFR",
    [7]  = "raidLFR",     -- legacy LFR
    [14] = "raidNormal",
    [15] = "raidHeroic",
    [16] = "raidMythic",
}

-- Known delve difficulty IDs in The War Within. Wider range used as fallback.
local DELVE_DIFFICULTY_IDS = {
    [208] = true, [215] = true, [216] = true, [217] = true,
    [218] = true, [219] = true, [220] = true,
}

local function detectContext()
    local _, instanceType, difficultyID = GetInstanceInfo()

    if difficultyID == 8 then return "mythicplus" end
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level and level > 0 then return "mythicplus" end
    end

    if instanceType == "raid" then
        return RAID_DIFFICULTY_TO_CONTEXT[difficultyID] or "raidNormal"
    end
    if DELVE_DIFFICULTY_IDS[difficultyID] then return "delve" end
    if instanceType == "party" then return "dungeon" end

    return "hunts"
end

local function clickPass()
    local btn = BonusRollFrame
        and BonusRollFrame.PromptFrame
        and BonusRollFrame.PromptFrame.PassButton
    if btn then
        btn:Click("LeftButton")
    elseif BonusRollFrame and BonusRollFrame.Hide then
        BonusRollFrame:Hide()
    end
end

local RAID_CONTEXTS = {
    raidLFR = true, raidNormal = true, raidHeroic = true, raidMythic = true,
}

local function onBonusRollShow()
    if not charDB or not charDB.bonusRollAutoDismiss then return end
    local ctx = detectContext()
    local keepKey = KEEP_KEYS[ctx]

    -- Raid contexts: master raid toggle gates the per-difficulty keep flags.
    if RAID_CONTEXTS[ctx] then
        if charDB.bonusRollKeepInRaids and charDB[keepKey] then return end
    elseif keepKey and charDB[keepKey] then
        return
    end

    -- Defer one frame so the prompt is fully constructed before clicking.
    C_Timer.After(0, clickPass)
end

local hooked = false
local function tryHook()
    if hooked then return true end
    if not BonusRollFrame then return false end
    BonusRollFrame:HookScript("OnShow", onBonusRollShow)
    hooked = true
    return true
end

function BR:Init(characterDB)
    charDB = characterDB

    -- BonusRollFrame lives in Blizzard_UIPanels_Game (typically loaded at login,
    -- but treat as on-demand to be safe).
    if not tryHook() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(_, _, name)
            if name == "Blizzard_UIPanels_Game" or tryHook() then
                if hooked then f:UnregisterEvent("ADDON_LOADED") end
            end
        end)
    end
end
