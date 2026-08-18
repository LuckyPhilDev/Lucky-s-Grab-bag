-- Lucky's Grab-bag: Auto-repair gear at vendors
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AutoRepair = {}

local db

local DevLog = LuckyGrabbag.Logger("AutoRepair")

local FormatCost = LuckyUtils.FormatMoney

local function TryRepair()
    if not db.autoRepair then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost == 0 then
        DevLog("Nothing to repair (cost=" .. tostring(cost) .. " canRepair=" .. tostring(canRepair) .. ")")
        return
    end

    local useGuild = db.autoRepairUseGuildFunds and CanGuildBankRepair()
    RepairAllItems(useGuild)

    local S = LuckyGrabbag.Strings.autoRepair
    local source = useGuild and S.guildFunds or S.personalFunds
    print(LuckyGrabbag.PREFIX .. " " .. string.format(S.repaired, FormatCost(cost), source))
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
