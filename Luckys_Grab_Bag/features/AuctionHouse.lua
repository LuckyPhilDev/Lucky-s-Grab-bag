-- Lucky's Grab-bag: Auction House enhancement buttons (CraftSim Quickbuy + TestFlight Buy Next)
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.Quickbuy = {
    requires = { addon = "CraftSim", minVersion = "19.7.0" },
}

LuckyGrabbag.TestflightBuy = {
    requires = { addon = "TestFlight", minVersion = "5.07" },
}

local db
local quickbuyButton
local testflightButton
local ahContainer
local auctionHouseOpen = false

-- ─── Container ───────────────────────────────────────────────────────────────

local function CreateContainer()
    if ahContainer then return end

    ahContainer = CreateFrame("Frame", "LGB_AHButtonsParent", UIParent) ---@diagnostic disable-line: undefined-global
    ahContainer:SetSize(1, 1)
    ahContainer:SetFrameStrata("MEDIUM")
    LuckyGrabbag.EnableGroupDrag(ahContainer, AuctionHouseFrame, "ahButtonPos", 5, 0) ---@diagnostic disable-line: undefined-global
end

-- ─── Quickbuy ────────────────────────────────────────────────────────────────

local function OnQuickbuyClick()
    local handler = SlashCmdList["CRAFTSIM"]
    if handler then
        handler("Quickbuy")
    else
        print("|cffff0000Lucky's Grab-bag:|r CraftSim is not loaded.")
    end
end

local function CreateQuickbuyButton()
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

-- ─── TestFlight ──────────────────────────────────────────────────────────────

local function OnTestflightClick()
    if TestFlight and TestFlight.GUI and TestFlight.GUI.Auctionator then ---@diagnostic disable-line: undefined-global
        TestFlight.GUI.Auctionator:BuyButtonOnClick() ---@diagnostic disable-line: undefined-global
    else
        print("|cffff0000Lucky's Grab-bag:|r TestFlight is not loaded.")
    end
end

local function CreateTestflightButton()
    if testflightButton then return end
    CreateContainer()

    testflightButton = LuckyGrabbag.CreateIconButton({
        parent  = ahContainer,
        texture = "Interface\\Icons\\INV_Misc_Coin_18",
        tooltip = function() GameTooltip:SetText("TestFlight Buy Next") end,
    })
    testflightButton:SetPushedTexture("Interface\\Icons\\INV_Misc_Coin_18")
    testflightButton:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8, 1)
    testflightButton:SetScript("OnClick", OnTestflightClick)

    ahContainer:RegisterDraggable(testflightButton)
end

local function AnchorTestflightButton()
    testflightButton:ClearAllPoints()
    if quickbuyButton and quickbuyButton:IsShown() then
        testflightButton:SetPoint("TOPLEFT", quickbuyButton, "BOTTOMLEFT", 0, -5)
    else
        testflightButton:SetPoint("TOPLEFT", ahContainer, "TOPLEFT", 0, 0)
    end
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function LuckyGrabbag.TestflightBuy:ApplySetting()
    local req = LuckyGrabbag.TestflightBuy.requires
    local depOk = LuckyDeps:Check(req.addon, req.minVersion)
    if auctionHouseOpen and db.showTestflightBuy and depOk then
        CreateTestflightButton()
        AnchorTestflightButton()
        testflightButton:Show()
    elseif testflightButton then
        testflightButton:Hide()
    end
end

function LuckyGrabbag.Quickbuy:ApplySetting()
    local req = LuckyGrabbag.Quickbuy.requires
    local depOk = LuckyDeps:Check(req.addon, req.minVersion)
    if auctionHouseOpen and db.showQuickbuy and depOk then
        CreateQuickbuyButton()
        quickbuyButton:Show()
    elseif quickbuyButton then
        quickbuyButton:Hide()
    end
    LuckyGrabbag.TestflightBuy:ApplySetting()
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

-- ─── Init ────────────────────────────────────────────────────────────────────

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

-- TestflightBuy:Init is a no-op since both features share `db` via Quickbuy:Init,
-- but we keep it so the entry point's Init loop stays consistent.
function LuckyGrabbag.TestflightBuy:Init(database)
    -- db already set by Quickbuy:Init
end
