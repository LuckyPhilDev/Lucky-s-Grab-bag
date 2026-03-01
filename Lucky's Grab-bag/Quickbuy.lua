-- Lucky's Grab-bag: CraftSim Quickbuy button
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Quickbuy = {}

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

    local button = CreateFrame("Button", nil, UIParent)
    quickbuyButton = button
    button:SetSize(42, 42)
    button:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 5, 0)

    button:SetNormalTexture("Interface\\Icons\\INV_Misc_Coin_01")
    button:SetPushedTexture("Interface\\Icons\\INV_Misc_Coin_01")
    button:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:GetHighlightTexture():SetBlendMode("ADD") ---@diagnostic disable-line: param-type-mismatch

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("CraftSim Quickbuy")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", OnQuickbuyClick)
end

function LuckyGrabbag.Quickbuy:ApplySetting()
    if auctionHouseOpen and db.showQuickbuy then
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
