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

-- Fast-path raid difficulty IDs → context key. IDs not listed here are
-- classified at runtime from the game's own difficulty flags (see
-- classifyRaidContext), so a newly added difficulty still reads correctly.
local RAID_DIFFICULTY_TO_CONTEXT = {
    [17] = "raidLFR",
    [7]  = "raidLFR",     -- legacy LFR
    [14] = "raidNormal",
    [15] = "raidHeroic",
    [16] = "raidMythic",
    [233] = "raidMythic",  -- Mythic - Flexible Raiding (added 12.0.7)
}

-- Known delve difficulty IDs in The War Within. Wider range used as fallback.
local DELVE_DIFFICULTY_IDS = {
    [208] = true, [215] = true, [216] = true, [217] = true,
    [218] = true, [219] = true, [220] = true,
}

-- Resolve a raid difficulty to a context key. Tries the explicit table first,
-- then the difficulty's own display flags so a difficulty ID we've never seen
-- (e.g. the flexible Mythic added in 12.0.7) is still recognised as Mythic
-- instead of being misread as Normal. Returns nil when it can't be classified;
-- the caller treats an unidentified context as "don't auto-dismiss".
local function classifyRaidContext(difficultyID)
    local explicit = RAID_DIFFICULTY_TO_CONTEXT[difficultyID]
    if explicit then return explicit end

    local _, _, isHeroic, _, displayHeroic, displayMythic = GetDifficultyInfo(difficultyID)
    if displayMythic then return "raidMythic" end
    if isHeroic or displayHeroic then return "raidHeroic" end
    return nil
end

local function detectContext()
    local _, instanceType, difficultyID = GetInstanceInfo()

    if difficultyID == 8 then return "mythicplus" end
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level and level > 0 then return "mythicplus" end
    end

    if instanceType == "raid" then
        return classifyRaidContext(difficultyID)
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

local function getMythicPlusLevel()
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if type(level) == "number" and level > 0 then return level end
    end
    return 0
end

local function onBonusRollShow()
    if not charDB or not charDB.bonusRollAutoDismiss then return end

    local ctx = detectContext()

    -- Fail safe: if the context can't be identified, never auto-pass. Leaving an
    -- extra popup is harmless; passing a roll the player wanted is not.
    if not ctx then return end

    local keepKey = KEEP_KEYS[ctx]

    -- Raid contexts: master raid toggle gates the per-difficulty keep flags.
    if RAID_CONTEXTS[ctx] then
        if charDB.bonusRollKeepInRaids and charDB[keepKey] then return end
    elseif ctx == "mythicplus" then
        if charDB.bonusRollKeepInMythicPlus then
            local minLevel = charDB.bonusRollMythicPlusMinLevel or 1
            if getMythicPlusLevel() >= minLevel then return end
        end
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
