-- Lucky's Grab-bag: CraftSim Quickbuy button
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Quickbuy = {
    requires = { addon = "CraftSim", minVersion = "19.7.0" },
}

local db
local quickbuyButton
local ahContainer
local auctionHouseOpen = false

local function CreateContainer()
    if ahContainer then return end

    ahContainer = CreateFrame("Frame", "LGB_AHButtonsParent", UIParent) ---@diagnostic disable-line: undefined-global
    ahContainer:SetSize(1, 1)
    ahContainer:SetFrameStrata("MEDIUM")
    LuckyGrabbag.EnableGroupDrag(ahContainer, AuctionHouseFrame, "ahButtonPos", 5, 0) ---@diagnostic disable-line: undefined-global
end

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
    CreateContainer()

    quickbuyButton = LuckyGrabbag.CreateIconButton({
        parent  = ahContainer,
        texture = "Interface\\Icons\\INV_Misc_Coin_01",
        tooltip = function() GameTooltip:SetText("CraftSim Quickbuy") end,
    })
    quickbuyButton:SetPoint("TOPLEFT", ahContainer, "TOPLEFT", 0, 0)
    quickbuyButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Coin_01")
    quickbuyButton:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8, 1)
    quickbuyButton:SetScript("OnClick", OnQuickbuyClick)

    ahContainer:RegisterDraggable(quickbuyButton)
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
    LuckyGrabbag.TestflightBuy:ApplySetting()
end

function LuckyGrabbag.Quickbuy:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            auctionHouseOpen = true
            if ahContainer then ahContainer:RestorePosition() end
            LuckyGrabbag.Quickbuy:ApplySetting()
        elseif event == "AUCTION_HOUSE_CLOSED" then
            auctionHouseOpen = false
            if quickbuyButton then quickbuyButton:Hide() end
            LuckyGrabbag.TestflightBuy:ApplySetting()
        end
    end)
end

function LuckyGrabbag.Quickbuy:IsAuctionHouseOpen()
    return auctionHouseOpen
end

function LuckyGrabbag.Quickbuy:GetButton()
    return quickbuyButton
end

function LuckyGrabbag.Quickbuy:GetContainer()
    CreateContainer()
    return ahContainer
end
