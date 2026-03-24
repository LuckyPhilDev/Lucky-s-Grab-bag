-- Lucky's Grab-bag: TestFlight Buy Next button
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.TestflightBuy = {
    requires = { addon = "TestFlight", minVersion = "5.07" },
}

local db
local buyButton

local function OnClick()
    if TestFlight and TestFlight.GUI and TestFlight.GUI.Auctionator then ---@diagnostic disable-line: undefined-global
        TestFlight.GUI.Auctionator:BuyButtonOnClick() ---@diagnostic disable-line: undefined-global
    else
        print("|cffff0000Lucky's Grab-bag:|r TestFlight is not loaded.")
    end
end

local function CreateButton()
    if buyButton then return end

    local container = LuckyGrabbag.Quickbuy:GetContainer()
    buyButton = LuckyGrabbag.CreateIconButton({
        parent  = container,
        texture = "Interface\\Icons\\INV_Misc_Coin_18",
        tooltip = function() GameTooltip:SetText("TestFlight Buy Next") end,
    })
    buyButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Coin_18")
    buyButton:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8, 1)
    buyButton:SetScript("OnClick", OnClick)

    container:RegisterDraggable(buyButton)
end

local function AnchorButton()
    buyButton:ClearAllPoints()
    local quickbuyButton = LuckyGrabbag.Quickbuy:GetButton()
    if quickbuyButton and quickbuyButton:IsShown() then
        buyButton:SetPoint("TOPLEFT", quickbuyButton, "BOTTOMLEFT", 0, -5)
    else
        buyButton:SetPoint("TOPLEFT", LuckyGrabbag.Quickbuy:GetContainer(), "TOPLEFT", 0, 0)
    end
end

function LuckyGrabbag.TestflightBuy:ApplySetting()
    local auctionHouseOpen = LuckyGrabbag.Quickbuy:IsAuctionHouseOpen()
    local req = LuckyGrabbag.TestflightBuy.requires
    local depOk = LuckyGrabbag.Dependencies.Check(req.addon, req.minVersion)
    if auctionHouseOpen and db.showTestflightBuy and depOk then
        CreateButton()
        AnchorButton()
        buyButton:Show()
    elseif buyButton then
        buyButton:Hide()
    end
end

function LuckyGrabbag.TestflightBuy:Init(database)
    db = database
end
