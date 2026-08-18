-- Lucky's Grab-bag: Per-spec Omnium Folio rune memory.
-- The Omnium Folio (Runes of Power) tree is shared across specializations, so
-- switching spec silently keeps whatever runes the previous spec used. This
-- records the runes picked while in each spec and restores them on spec switch.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.OmniumFolio = {}

local TREE_ID = 1186 -- Runes of Power (Omnium Folio)

local db, charDB
local lastSpecID
-- Blizzard may fire TRAIT_CONFIG_UPDATED for this config during a spec change;
-- snapshotting then would write the old spec's runes into the new spec's slot
-- before we get a chance to restore. Suppressed while a restore is pending.
local restoring = false

local DevLog = LuckyGrabbag.Logger("OmniumFolio")

local function CurrentSpecID()
    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex) or nil
end

local function ReadSelections(configID)
    local selections = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(TREE_ID)) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.ID == nodeID and nodeInfo.activeEntry then
            selections[nodeID] = nodeInfo.activeEntry.entryID
        end
    end
    return selections
end

local function Snapshot()
    local configID = C_Traits.GetConfigIDByTreeID(TREE_ID)
    local specID = CurrentSpecID()
    if not configID or not specID then return end
    charDB.omniumFolioBySpec[specID] = ReadSelections(configID)
    DevLog("Saved rune snapshot for spec " .. specID)
end

local function RuneName(configID, entryID)
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

local function Restore(specID)
    local configID = C_Traits.GetConfigIDByTreeID(TREE_ID)
    if not configID then return end

    local saved = charDB.omniumFolioBySpec[specID]
    if not saved then
        -- First visit to this spec: adopt the current runes as its baseline.
        Snapshot()
        return
    end
    if C_Traits.ConfigHasStagedChanges(configID) then
        DevLog("Skipping restore: config has staged changes")
        return
    end

    local S = LuckyGrabbag.Strings.omniumFolio
    local restoredNames = {}
    for nodeID, entryID in pairs(saved) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.ID == nodeID
            and (not nodeInfo.activeEntry or nodeInfo.activeEntry.entryID ~= entryID)
            and HasEntry(nodeInfo, entryID)
            and C_Traits.SetSelection(configID, nodeID, entryID)
        then
            table.insert(restoredNames, RuneName(configID, entryID) or S.unknownRune)
        end
    end
    if #restoredNames == 0 then
        DevLog("No rune changes needed for spec " .. specID)
        return
    end

    if C_Traits.CommitConfig(configID) then
        local _, specName = GetSpecializationInfoByID(specID)
        print(LuckyGrabbag.PREFIX .. " " .. string.format(
            S.restored, specName or "", table.concat(restoredNames, ", ")))
    else
        C_Traits.RollbackConfig(configID)
        print(LuckyGrabbag.PREFIX .. " " .. S.restoreFailed)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if not db or not db.omniumFolioPerSpec then return end
    if event == "PLAYER_ENTERING_WORLD" then
        lastSpecID = CurrentSpecID()
        Snapshot()
    elseif event == "TRAIT_CONFIG_UPDATED" then
        if not restoring and arg1 and arg1 == C_Traits.GetConfigIDByTreeID(TREE_ID) then
            Snapshot()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if arg1 ~= "player" then return end
        local specID = CurrentSpecID()
        if not specID or specID == lastSpecID then return end
        lastSpecID = specID
        restoring = true
        -- Next frame: let the spec change settle before touching the config.
        C_Timer.After(0, function()
            Restore(specID)
            restoring = false
        end)
    end
end)

-- Called from the settings panel so enabling mid-session seeds the current spec.
function LuckyGrabbag.OmniumFolio:ApplySetting()
    if not db or not db.omniumFolioPerSpec then return end
    lastSpecID = CurrentSpecID()
    Snapshot()
end

function LuckyGrabbag.OmniumFolio:Init(database, characterDatabase)
    db = database
    charDB = characterDatabase
    charDB.omniumFolioBySpec = charDB.omniumFolioBySpec or {}
end
