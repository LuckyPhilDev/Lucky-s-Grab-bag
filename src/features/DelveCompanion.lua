-- Lucky's Grab-bag: Per-spec delve companion loadout memory.
-- The companion's role and curios are shared across specializations, and the
-- game sometimes hands the loadout back empty on entering a delve. This records
-- what each spec runs and puts it back.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveCompanion = {}

local DelveCompanion = LuckyGrabbag.DelveCompanion

-- The companion config arrives with the instance, so a sync fired on the
-- zone-in event reads an empty tree unless it waits.
local SYNC_DELAY = 2

local db, charDB
local syncing = false
local blockedByCombat = false

local DevLog = LuckyGrabbag.Logger("DelveCompanion")

local function SelectionNodeIDs()
    local ids = {}
    local function add(nodeID)
        if nodeID and nodeID ~= 0 then ids[#ids + 1] = nodeID end
    end
    add(C_DelvesUI.GetRoleNodeForCompanion())
    add(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat))
    add(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility))
    add(C_DelvesUI.GetFlavorNodeForCompanion())
    return ids
end

-- Node and entry IDs belong to one companion's tree, so the tree is part of the
-- key: a new season's companion gets its own memory instead of inheriting one
-- whose IDs mean nothing to it.
local function Context()
    local treeID = C_DelvesUI.GetTraitTreeForCompanion()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not treeID or treeID == 0 or not specID then return end

    local configID = C_Traits.GetConfigIDByTreeID(treeID)
    if not configID then return end
    return configID, treeID .. ":" .. specID, specID
end

local function ChoiceName(configID, entryID)
    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
    local defInfo = entryInfo and entryInfo.definitionID
        and C_Traits.GetDefinitionInfo(entryInfo.definitionID)
    if not defInfo then return nil end
    local spellID = defInfo.spellID or defInfo.overriddenSpellID
    return (spellID and C_Spell.GetSpellLink(spellID)) or defInfo.overrideName
end

local function HasEntry(nodeInfo, entryID)
    for _, id in ipairs(nodeInfo.entryIDs) do
        if id == entryID then return true end
    end
    return false
end

function DelveCompanion.Snapshot()
    local configID, key = Context()
    if not configID then return end

    charDB.delveCompanionBySpec[key] = charDB.delveCompanionBySpec[key] or {}
    local saved = charDB.delveCompanionBySpec[key]
    for _, nodeID in ipairs(SelectionNodeIDs()) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        local activeEntry = nodeInfo and nodeInfo.activeEntry
        -- An empty slot is what the bug looks like, so it never clears a memory.
        if activeEntry and activeEntry.entryID then
            saved[nodeID] = activeEntry.entryID
        end
    end
end

function DelveCompanion.Restore()
    local configID, key, specID = Context()
    if not configID then return end

    local saved = charDB.delveCompanionBySpec[key]
    if not saved or not next(saved) then return end
    if C_Traits.ConfigHasStagedChanges(configID) then
        DevLog("Skipping restore: config has staged changes")
        return
    end

    local S = LuckyGrabbag.Strings.delveCompanion
    local restored = {}
    for nodeID, entryID in pairs(saved) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.ID == nodeID
            and (not nodeInfo.activeEntry or nodeInfo.activeEntry.entryID ~= entryID)
            and HasEntry(nodeInfo, entryID)
            and C_Traits.SetSelection(configID, nodeID, entryID)
        then
            table.insert(restored, ChoiceName(configID, entryID) or S.unknownChoice)
        end
    end
    if #restored == 0 then
        DevLog("Companion loadout already matches spec " .. specID)
        return
    end

    if C_Traits.IsReadyForCommit() and C_Traits.CommitConfig(configID) then
        local _, specName = GetSpecializationInfoByID(specID)
        print(LuckyGrabbag.PREFIX .. " " .. string.format(
            S.restored, specName or "", table.concat(restored, ", ")))
    else
        C_Traits.RollbackConfig(configID)
        print(LuckyGrabbag.PREFIX .. " " .. S.restoreFailed)
    end
end

local function Sync()
    if syncing then return end
    if InCombatLockdown() then
        blockedByCombat = true
        return
    end
    syncing = true
    C_Timer.After(SYNC_DELAY, function()
        DelveCompanion.Restore()
        DelveCompanion.Snapshot()
        syncing = false
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if not db or not db.delveCompanionPerSpec then return end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then return end
    if event == "TRAIT_CONFIG_UPDATED" and arg1 ~= (Context()) then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if not blockedByCombat then return end
        blockedByCombat = false
    end
    Sync()
end)

-- Called from the settings panel so enabling mid-session seeds the current spec.
function DelveCompanion:ApplySetting()
    if not db or not db.delveCompanionPerSpec then return end
    Sync()
end

function DelveCompanion:Init(database, characterDatabase)
    db = database
    charDB = characterDatabase
    charDB.delveCompanionBySpec = charDB.delveCompanionBySpec or {}
end
