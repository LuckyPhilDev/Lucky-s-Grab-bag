-- Lucky's Grab-bag: Automatic combat logging for raids and Mythic+
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AutoCombatLog = {}

local MYTHIC_PLUS_DIFFICULTY = 8

-- difficultyID -> db key for the per-difficulty raid toggles.
local RAID_DIFFICULTY_KEYS = {
    [17] = "autoCombatLogLFR",
    [14] = "autoCombatLogNormalRaid",
    [15] = "autoCombatLogHeroicRaid",
    [16] = "autoCombatLogMythicRaid",
}

local db
local weEnabledLogging = false
local userSuppressed = false  -- user turned logging off mid-instance; respect it until they leave

local DevLog = LuckyGrabbag.Logger("AutoCombatLog")

-- Journal instance IDs for the newest Encounter Journal tier, i.e. the current
-- raids. Built lazily and cached for the session; nil when journal data is
-- unavailable, in which case the season check is skipped (fail open).
local currentTierRaids
local function GetCurrentTierRaids()
    if currentTierRaids then return currentTierRaids end
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return nil end
    local numTiers = EJ_GetNumTiers()
    if not numTiers or numTiers == 0 then return nil end

    local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    EJ_SelectTier(numTiers)
    local set = {}
    for i = 1, 50 do
        local id = EJ_GetInstanceByIndex(i, true)
        if not id then break end
        set[id] = true
    end
    if savedTier and savedTier > 0 and savedTier ~= numTiers then
        EJ_SelectTier(savedTier)
    end

    if not next(set) then return nil end
    currentTierRaids = set
    return set
end

local function GetJournalInstanceID()
    if not EJ_GetInstanceForMap then return nil end
    local instanceMapID = select(8, GetInstanceInfo())
    if instanceMapID then
        local ok, ej = pcall(EJ_GetInstanceForMap, instanceMapID)
        if ok and type(ej) == "number" and ej > 0 then return ej end
    end
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if uiMapID then
        local ok, ej = pcall(EJ_GetInstanceForMap, uiMapID)
        if ok and type(ej) == "number" and ej > 0 then return ej end
    end
    return nil
end

-- Whether the current instance should be logged. Returns the localized
-- difficulty name for the chat message when it should.
local function GetDesiredState()
    if not db.autoCombatLog then return false end
    local _, instanceType, difficultyID, difficultyName = GetInstanceInfo()

    -- Mythic+ keys only exist in the current season, so no season check needed.
    if difficultyID == MYTHIC_PLUS_DIFFICULTY then
        if db.autoCombatLogMythicPlus then return true, difficultyName end
        return false
    end

    if instanceType == "raid" then
        if not db.autoCombatLogRaids then return false end
        local key = RAID_DIFFICULTY_KEYS[difficultyID]
        if not key or not db[key] then return false end

        if db.autoCombatLogCurrentSeasonOnly then
            local currentRaids = GetCurrentTierRaids()
            if currentRaids then
                local journalID = GetJournalInstanceID()
                if journalID and not currentRaids[journalID] then
                    DevLog("Raid is not in the current tier; not logging")
                    return false
                end
                -- Unresolvable journal ID fails open so current raids are never missed.
            else
                DevLog("Journal tier data unavailable; skipping season check")
            end
        end
        return true, difficultyName
    end

    return false
end

local function UpdateLogging()
    if not db then return end
    local want, label = GetDesiredState()
    local active = LoggingCombat()
    local S = LuckyGrabbag.Strings

    if want and weEnabledLogging and not active then
        -- The user switched logging off mid-instance; don't fight them.
        weEnabledLogging = false
        userSuppressed = true
        DevLog("User disabled logging manually; suppressed until they leave")
        return
    end

    if want and not active and not userSuppressed then
        LoggingCombat(true)
        weEnabledLogging = true
        print(S.addon.prefix .. " " .. string.format(S.autoCombatLog.started, label))
        DevLog("Logging enabled")
    elseif not want then
        userSuppressed = false
        if active and weEnabledLogging then
            LoggingCombat(false)
            weEnabledLogging = false
            print(S.addon.prefix .. " " .. S.autoCombatLog.stopped)
            DevLog("Logging disabled")
        end
    end
end

function LuckyGrabbag.AutoCombatLog:ApplySetting()
    UpdateLogging()
end

function LuckyGrabbag.AutoCombatLog:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:SetScript("OnEvent", function(_, event)
        UpdateLogging()
        if event == "PLAYER_ENTERING_WORLD" then
            -- Difficulty and journal data can settle a moment after a load screen.
            C_Timer.After(2, UpdateLogging)
        end
    end)
end
