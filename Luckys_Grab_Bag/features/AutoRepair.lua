-- Lucky's Grab-bag: Auto-repair gear at vendors
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AutoRepair = {}

local db

local function DevLog(msg)
    LuckyGrabbag.DevLog("AutoRepair", msg)
end

local function FormatCost(copper)
    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, cop)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

local function TryRepair()
    if not db.autoRepair then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost == 0 then
        DevLog("Nothing to repair (cost=" .. tostring(cost) .. " canRepair=" .. tostring(canRepair) .. ")")
        return
    end

    local useGuild = db.autoRepairUseGuildFunds and CanGuildBankRepair()
    RepairAllItems(useGuild)

    local source = useGuild and "guild funds" or "personal funds"
    print(LuckyGrabbag.PREFIX .. " Repaired all items (" .. FormatCost(cost) .. " from " .. source .. ")")
    DevLog("Repaired for " .. FormatCost(cost) .. " from " .. source)
end

function LuckyGrabbag.AutoRepair:Init(database)
    db = database
    DevLog("Init called")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:SetScript("OnEvent", function(_, event)
        DevLog("Event: " .. event)
        TryRepair()
    end)
end
