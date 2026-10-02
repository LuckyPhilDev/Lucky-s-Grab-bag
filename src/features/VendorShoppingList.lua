-- Lucky's Grab-bag: One-click buttons beside the vendor window for items on Auctionator shopping lists
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.VendorShoppingList = {}

local MAX_ROWS = 12
local ROW_HEIGHT = 26
local PANEL_WIDTH = 150
local PADDING = 8
local ICON_SIZE = ROW_HEIGHT - 2
local BUTTON_SIZE = 18

local db
local panel
local rows = {}

local DevLog = LuckyGrabbag.Logger("VendorShoppingList")

-- Auctionator keeps each list's entries as search strings: "name;category;...". Only
-- the name matters here, and an exact search wraps it in quotes.
local function SearchName(searchString)
    local name = searchString:match("^([^;]*)")
    return (name:gsub('^"(.*)"$', "%1")):lower()
end

-- Quantity is the last field of the search string; an entry typed in by hand has none.
local function SearchQuantity(searchString)
    return tonumber(searchString:match(";(%d+)$")) or 1
end

local function ShoppingListQuantities()
    local wanted = {}
    for _, list in ipairs(AUCTIONATOR_SHOPPING_LISTS or {}) do ---@diagnostic disable-line: undefined-global
        for _, entry in ipairs(list.items or {}) do
            local name = SearchName(entry)
            wanted[name] = (wanted[name] or 0) + SearchQuantity(entry)
        end
    end
    return wanted
end

local function MerchantItem(index)
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(index) ---@diagnostic disable-line: undefined-global
    if info then
        return info.name, info.texture, info.stackCount, info.hasExtendedCost, info.price
    end
    local name, texture, price, quantity, _, _, _, extendedCost = GetMerchantItemInfo(index) ---@diagnostic disable-line: undefined-global
    return name, texture, quantity, extendedCost, price
end

local function StacksToCover(needed, link, bundle)
    local stackSize = select(8, C_Item.GetItemInfo(link)) or bundle ---@diagnostic disable-line: undefined-global
    local stacks = math.ceil(needed / stackSize)
    return stacks, stacks * stackSize
end

-- The vendor sells in bundles, so a click can buy slightly more than the units asked for.
local function BundlesFor(units, bundle)
    return math.ceil(units / bundle)
end

local function Buy(index, units, bundle)
    local remaining = BundlesFor(units, bundle)
    local perCall = GetMerchantItemMaxStack(index) ---@diagnostic disable-line: undefined-global
    while remaining > 0 do
        local count = math.min(remaining, perCall)
        BuyMerchantItem(index, count) ---@diagnostic disable-line: undefined-global
        remaining = remaining - count
    end
end

local function HideTooltip()
    GameTooltip:Hide() ---@diagnostic disable-line: undefined-global
end

local function CreateBuyButton(row, icon, units, tooltip)
    local button = LuckyUI.CreateIconButton(row, {
        icon    = icon,
        size    = BUTTON_SIZE,
        tooltip = function(tip)
            tip:SetText(tooltip())
            tip:AddLine(GetMoneyString(BundlesFor(units(), row.bundle) * row.price), 1, 1, 1)
        end,
    })
    button:SetScript("OnClick", function() Buy(row.index, units(), row.bundle) end)
    return button
end

local function CreateRow(i)
    local S = LuckyGrabbag.Strings.vendorShoppingList
    local row = CreateFrame("Frame", nil, panel) ---@diagnostic disable-line: undefined-global
    row:SetSize(PANEL_WIDTH - PADDING * 2, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -PADDING - (i - 1) * ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

    local buyStack = CreateBuyButton(row, "layers",
        function() return row.stackUnits end,
        function()
            return (row.stacks == 1 and S.tooltipStack or S.tooltipStacks):format(row.stacks, row.stackUnits)
        end)
    buyStack:SetPoint("RIGHT")

    local buyNeeded = CreateBuyButton(row, "plus",
        function() return row.needed end,
        function() return S.tooltipNeeded:format(row.needed) end)
    buyNeeded:SetPoint("RIGHT", buyStack, "LEFT", -6, 0)

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT") ---@diagnostic disable-line: undefined-global
        GameTooltip:SetMerchantItem(self.index) ---@diagnostic disable-line: undefined-global
        GameTooltip:Show() ---@diagnostic disable-line: undefined-global
    end)
    row:SetScript("OnLeave", HideTooltip)
    return row
end

local function CreatePanel()
    panel = CreateFrame("Frame", "LGB_VendorShoppingList", UIParent, "BackdropTemplate") ---@diagnostic disable-line: undefined-global
    panel:SetWidth(PANEL_WIDTH)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.85)
    -- Sits below the Confirm Purchase and decor Buy All buttons, which share this edge.
    panel:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 5, -80) ---@diagnostic disable-line: undefined-global
    panel:Hide()
end

local function Refresh()
    if not db.vendorShoppingList or not MerchantFrame or not MerchantFrame:IsShown() then ---@diagnostic disable-line: undefined-global
        if panel then panel:Hide() end
        return
    end

    local wanted = ShoppingListQuantities()
    local shown = 0
    for index = 1, GetMerchantNumItems() do ---@diagnostic disable-line: undefined-global
        local name, texture, bundle, extendedCost, price = MerchantItem(index)
        local link = GetMerchantItemLink(index) ---@diagnostic disable-line: undefined-global
        if name and link and not extendedCost and wanted[name:lower()] and shown < MAX_ROWS then
            shown = shown + 1
            if not panel then CreatePanel() end
            rows[shown] = rows[shown] or CreateRow(shown)
            local row = rows[shown]
            row.index = index
            row.bundle = bundle or 1
            row.price = price or 0
            row.needed = wanted[name:lower()]
            row.stacks, row.stackUnits = StacksToCover(row.needed, link, row.bundle)
            row.icon:SetTexture(texture)
            row.text:SetText("x" .. row.needed)
            row:Show()
        end
    end

    for i = shown + 1, #rows do rows[i]:Hide() end

    if shown == 0 then
        if panel then panel:Hide() end
        return
    end
    panel:SetHeight(PADDING * 2 + shown * ROW_HEIGHT)
    panel:Show()
    DevLog("Showing %d shopping list items", shown)
end

local listListener

-- CraftSim deletes and rebuilds its list a moment after the craft queue changes, so
-- a refresh driven only by merchant and bag events can read the list mid-rebuild.
local function WatchShoppingLists()
    local events = Auctionator and Auctionator.Shopping and Auctionator.Shopping.Events
    if listListener or not events or not Auctionator.EventBus then return end
    listListener = { ReceiveEvent = Refresh }
    Auctionator.EventBus:Register(listListener, { events.ListItemChange, events.ListMetaChange })
end

function LuckyGrabbag.VendorShoppingList:ApplySetting()
    Refresh()
end

LuckyGrabbag.VendorShoppingList.requires = { addon = "Auctionator" }

function LuckyGrabbag.VendorShoppingList:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_UPDATE")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then
            if panel then panel:Hide() end
            return
        end
        WatchShoppingLists()
        Refresh()
    end)
end
