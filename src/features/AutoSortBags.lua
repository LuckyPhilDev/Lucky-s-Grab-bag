-- luacheck: globals IsUsingGamepad
-- Lucky's Grab-bag: Sort bags after auto-selling junk and when leaving a vendor
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AutoSortBags = {}

local db

local DevLog = LuckyGrabbag.Logger("AutoSortBags")

local eventFrame

local function ShouldSort()
    if not db.autoSortBags then return false end
    if db.autoSortBagsForeverOnly and not LuckyUtils.IsForever() then return false end
    if db.autoSortBagsControllerOnly and not (IsUsingGamepad and IsUsingGamepad()) then return false end
    return true
end

local function SortBags()
    if not ShouldSort() then return end

    local sort = (C_Container and C_Container.SortBags) or _G.SortBags
    if not sort then
        DevLog("No bag sort API on this client")
        return
    end

    sort()
    DevLog("Sorted bags")
end

-- Sold items stay locked until the server confirms the sale, so wait for the bag update.
function LuckyGrabbag.AutoSortBags:SortAfterSell()
    if not ShouldSort() then return end
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
end

function LuckyGrabbag.AutoSortBags:Init(database)
    db = database
    DevLog("Init called")

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(self, event)
        DevLog("Event: " .. event)
        self:UnregisterEvent("BAG_UPDATE_DELAYED")
        SortBags()
    end)
end
