-- Lucky's Grab-bag: Item ID line at the bottom of item tooltips.
-- Only shown when devMode is enabled.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ItemIDTip = {}

local db

function LuckyGrabbag.ItemIDTip:Init(database)
    db = database

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not (db and db.devMode) then return end
        local itemID = data and data.id
        if not itemID then return end
        tooltip:AddLine("Item ID: " .. itemID, 0.6, 0.6, 0.6)
    end)
end
