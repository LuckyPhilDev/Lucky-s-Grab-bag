-- Lucky's Grab-bag: CraftSim Quickbuy button
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Quickbuy = {
    requires = { addon = "CraftSim", minVersion = "19.7.0" },
}

local db
local quickbuyButton
local auctionHouseOpen = false

local function OnQuickbuyClick()
    local handler = SlashCmdList["CRAFTSIM"]
    if handler then
        handler("Quickbuy")
    else
        print("|cffff0000Lucky's Grab-bag:|r CraftSim is not loaded.")
    end
end

local function CreateButton()
    if quickbuyButton then return end

    quickbuyButton = LuckyGrabbag.CreateIconButton({
        parent  = AuctionHouseFrame, ---@diagnostic disable-line: undefined-global
        texture = "Interface\\Icons\\INV_Misc_Coin_01",
        tooltip = function() GameTooltip:SetText("CraftSim Quickbuy") end,
    })
    quickbuyButton:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 5, 0) ---@diagnostic disable-line: undefined-global
    quickbuyButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Coin_01")
    quickbuyButton:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8, 1)
    quickbuyButton:SetScript("OnClick", OnQuickbuyClick)
end

function LuckyGrabbag.Quickbuy:ApplySetting()
    local req = LuckyGrabbag.Quickbuy.requires
    local depOk = LuckyGrabbag.Dependencies.Check(req.addon, req.minVersion)
    if auctionHouseOpen and db.showQuickbuy and depOk then
        CreateButton()
        quickbuyButton:Show()
    elseif quickbuyButton then
        quickbuyButton:Hide()
    end
end

function LuckyGrabbag.Quickbuy:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            auctionHouseOpen = true
            LuckyGrabbag.Quickbuy:ApplySetting()
        elseif event == "AUCTION_HOUSE_CLOSED" then
            auctionHouseOpen = false
            if quickbuyButton then quickbuyButton:Hide() end
        end
    end)
end
