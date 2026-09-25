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
local auctionHouseOpen = false

-- Shared with the other Lucky addons, so every Auction House button stacks in one column.
local function Column()
    return LuckyUI.SideColumn("AuctionHouse", AuctionHouseFrame) ---@diagnostic disable-line: undefined-global
end

local function AddPressedButton(order, texture, tooltip, onClick)
    local button = Column():AddButton({
        order   = order,
        texture = texture,
        tooltip = function(tip) tip:SetText(tooltip) end,
    })
    button:SetPushedTexture(texture)
    button:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8, 1)
    button:SetScript("OnClick", onClick)
    return button
end

-- ─── Quickbuy ────────────────────────────────────────────────────────────────

local function OnQuickbuyClick()
    local handler = SlashCmdList["CRAFTSIM"]
    if handler then
        handler("Quickbuy")
    else
        local S = LuckyGrabbag.Strings
        print(S.addon.errorPrefix .. " " .. S.auctionHouse.craftsimNotLoaded)
    end
end

-- ─── TestFlight ──────────────────────────────────────────────────────────────

function LuckyGrabbag.TestflightBuy:CanBuy()
    return TestFlight ~= nil and TestFlight.GUI ~= nil and TestFlight.GUI.Auctionator ~= nil ---@diagnostic disable-line: undefined-global
end

-- Advances Auctionator's purchase by one step: pick the row, buy it, confirm the
-- dialog. One step per click is Blizzard's rule, not TestFlight's choice.
function LuckyGrabbag.TestflightBuy:BuyNext()
    if not self:CanBuy() then return false end
    TestFlight.GUI.Auctionator:BuyButtonOnClick() ---@diagnostic disable-line: undefined-global
    return true
end

local function OnTestflightClick()
    if not LuckyGrabbag.TestflightBuy:BuyNext() then
        local S = LuckyGrabbag.Strings
        print(S.addon.errorPrefix .. " " .. S.auctionHouse.testflightNotLoaded)
    end
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function LuckyGrabbag.TestflightBuy:ApplySetting()
    local req = LuckyGrabbag.TestflightBuy.requires
    local depOk = LuckyDeps:Check(req.addon, req.minVersion)
    if auctionHouseOpen and db.showTestflightBuy and depOk then
        testflightButton = testflightButton or AddPressedButton(20, "Interface\\Icons\\INV_Misc_Coin_18",
            LuckyGrabbag.Strings.auctionHouse.testflightTooltip, OnTestflightClick)
        testflightButton:Show()
    elseif testflightButton then
        testflightButton:Hide()
    end
    LuckyGrabbag.QuestShopping:ApplySetting()
end

function LuckyGrabbag.Quickbuy:ApplySetting()
    local req = LuckyGrabbag.Quickbuy.requires
    local depOk = LuckyDeps:Check(req.addon, req.minVersion)
    if auctionHouseOpen and db.showQuickbuy and depOk then
        quickbuyButton = quickbuyButton or AddPressedButton(10, "Interface\\Icons\\INV_Misc_Coin_01",
            LuckyGrabbag.Strings.auctionHouse.quickbuyTooltip, OnQuickbuyClick)
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

function LuckyGrabbag.Quickbuy:GetColumn()
    return Column()
end

-- ─── Init ────────────────────────────────────────────────────────────────────

function LuckyGrabbag.Quickbuy:Init(database)
    db = database

    if db.ahButtonPos then
        LuckyUI.SeedSideColumnPosition("AuctionHouse", db.ahButtonPos)
        db.ahButtonPos = nil
    end

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
            LuckyGrabbag.TestflightBuy:ApplySetting()
        end
    end)
end

-- TestflightBuy:Init is a no-op since both features share `db` via Quickbuy:Init,
-- but we keep it so the entry point's Init loop stays consistent.
function LuckyGrabbag.TestflightBuy:Init(database)
    -- db already set by Quickbuy:Init
end
