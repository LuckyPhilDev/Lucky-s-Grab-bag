LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.StockistHandover = {}

local Data  = LuckyGrabbag.ReagentMainsData
local Utils = LuckyGrabbag.AutoDepositUtils
local S     = LuckyGrabbag.Strings.stockistHandover

local db

local function TrueKeys(set)
    local keys = {}
    for key, on in pairs(type(set) == "table" and set or {}) do
        if on == true then keys[key] = true end
    end
    return keys
end

-- One set per category for every character, with its mains and the excluded
-- characters unticked, which is exactly who Reagent Mains left alone.
local function HandOverReagents()
    if not db.reagentMainsEnabled then return false end
    local excluded = TrueKeys(db.reagentExcludedAlts)
    for _, category in ipairs(Data.CategoryOrder) do
        local mains = db.reagentMains[category]
        local everyoneKeeps = type(mains) == "table" and mains[Data.ALL_SENTINEL]
        if not everyoneKeeps then
            local skip = TrueKeys(mains)
            for charKey in pairs(excluded) do skip[charKey] = true end
            WarbandStorage:ImportStandardSet(category, {
                everyCharacter = true,
                skip = skip,
                currentExpansionOnly = db.reagentMainsCurrentExpOnly,
            })
        end
    end
    return true
end

-- Grab-bag's own settings stay in place, so switching Stockist off brings
-- these features straight back as they were.
local function HandOver()
    if db.bankMovedToStockist or not Utils.StockistOwnsBank() then return end
    db.bankMovedToStockist = true

    local moved = HandOverReagents()
    if db.warboundDepositLumber then
        WarbandStorage:ImportStandardSet("lumber", { everyCharacter = true })
        moved = true
    end
    if db.showTreatise then
        WarbandStorage:ImportStandardSet("treatise", { everyCharacter = true })
        moved = true
    end

    local ids = {}
    for itemID in pairs(TrueKeys(db.warboundItemWhitelist)) do ids[#ids + 1] = itemID end
    if #ids > 0 then
        table.sort(ids)
        -- A switched-off whitelist still moves, used by nobody, so it is not lost.
        WarbandStorage:ImportDepositList(S.whitelistSet, ids, db.warboundAutoDepositEnabled == true)
        moved = true
    end

    if moved then print(LuckyGrabbag.PREFIX .. " " .. S.moved) end
end

function LuckyGrabbag.StockistHandover:Init(database)
    db = database
    -- Warband Stockist loads after this addon, so its API only exists by login.
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", HandOver)
end
