-- luacheck: globals LuckyGrabbag LuckyStrings LuckyDeps WarbandStorage CreateFrame print

-- Covers the one-time hand-over of Grab-bag's bank features to Warband
-- Stockist 2.0: which sets get created, for whom, and that it happens once.
--
-- Run from the addon root: lua tests/StockistHandoverTest.lua

LuckyStrings = { New = function(_, strings) return strings end }
LuckyGrabbag = { PREFIX = "[GB]" }

local stockistOn = true
LuckyDeps = { IsEnabled = function(_, addon, version)
    return stockistOn and addon == "Luckys_Warbank_Stockist" and version == "2.0.0"
end }

local loginHandlers = {}
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) table.insert(loginHandlers, fn) end,
    }
end

local printed = {}
print = function(line) table.insert(printed, line) end

local standard, lists
local function resetStockist()
    standard, lists = {}, {}
    WarbandStorage = {
        ImportStandardSet = function(_, kind, opts) standard[kind] = opts; return 1 end,
        ImportDepositList = function(_, name, ids, everyCharacter)
            table.insert(lists, { name = name, ids = ids, everyCharacter = everyCharacter })
            return 2
        end,
    }
end

dofile("src/Strings.lua")
dofile("src/AutoDepositUtils.lua")
dofile("src/features/ReagentMainsData.lua")
dofile("src/features/StockistHandover.lua")

local passed = 0
local function check(cond, label)
    if not cond then error(label, 2) end
    passed = passed + 1
end

local function login(db)
    resetStockist()
    printed = {}
    loginHandlers = {}
    LuckyGrabbag.StockistHandover:Init(db)
    loginHandlers[1]()
end

local db = {
    reagentMainsEnabled = true,
    reagentMainsCurrentExpOnly = true,
    reagentMains = {
        herb = { ["Herbalist-Area52"] = true, ["Retired-Area52"] = false },
        cloth = { [LuckyGrabbag.ReagentMainsData.ALL_SENTINEL] = true },
    },
    reagentExcludedAlts = { ["Bank-Area52"] = true },
    warboundDepositLumber = true,
    showTreatise = true,
    warboundAutoDepositEnabled = false,
    warboundItemWhitelist = { [900] = true, [800] = true },
}
login(db)

check(standard.herb and standard.herb.everyCharacter, "herbs for every character")
check(standard.herb.skip["Herbalist-Area52"], "the herb main keeps their herbs")
check(not standard.herb.skip["Retired-Area52"], "an unticked main is not a main")
check(standard.herb.skip["Bank-Area52"], "excluded characters keep everything")
check(standard.leather and standard.leather.skip["Bank-Area52"], "excluded characters skip every category")
check(standard.cloth == nil, "a category everyone keeps needs no set")
check(standard.herb.currentExpansionOnly == true, "current expansion carried")
check(standard.lumber and standard.lumber.everyCharacter, "lumber for everyone")
check(standard.treatise and standard.treatise.everyCharacter, "treatise for everyone")
check(#lists == 1 and lists[1].ids[1] == 800 and lists[1].ids[2] == 900, "whitelist carried, sorted")
check(lists[1].everyCharacter == false, "a switched-off whitelist reaches nobody")
check(db.bankMovedToStockist == true, "flagged")
check(#printed == 1, "one message")

login(db)
check(next(standard) == nil and #lists == 0, "hands over once")

local quiet = { reagentMains = {}, warboundItemWhitelist = {} }
login(quiet)
check(next(standard) == nil and #lists == 0, "nothing to move")
check(#printed == 0, "no message when nothing moved")
check(quiet.bankMovedToStockist == true, "still flagged")

stockistOn = false
local later = { reagentMainsEnabled = true, reagentMains = {}, warboundItemWhitelist = {} }
login(later)
check(next(standard) == nil, "no Stockist 2.0, no hand-over")
check(later.bankMovedToStockist == nil, "no flag without Stockist, so it runs once Stockist arrives")

io.write(string.format("%d StockistHandover tests passed\n", passed))
