-- Lucky's Grab-bag: Bulk Buy, a port of BuyEmAll into Grab-bag, keeping its original window.
--
-- BuyEmAll has made bulk buying painless since 2006, by Cogwheel, Shinisuryu,
-- Jordy141 and contributors: https://www.curseforge.com/wow/addons/buyemall
-- Ported on 2026-10-15 from the community fork's v5.0.0
-- (https://github.com/EricaPomme/BuyEmAll), under the MIT License as it stood then:
--
-- MIT License
--
-- Copyright (c) 2006-2026 BuyEmAll contributors (Cogwheel, Shinisuryu, Jordy141, and contributors)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.BulkBuy = {}

local MONEY_TEXTURES = {
    "Interface\\MONEYFRAME\\UI-GoldIcon",
    "Interface\\MONEYFRAME\\UI-SilverIcon",
    "Interface\\MONEYFRAME\\UI-CopperIcon",
}
local NO_CURRENCY_CAP = 10000000
local NO_COST_CAP = 999999

local db
local frame
local originalOnModifiedClick
local order = {}

local DevLog = LuckyGrabbag.Logger("BulkBuy")

local function S() return LuckyGrabbag.Strings.bulkBuy end

local function IsUnique(itemID)
    local tooltip = C_TooltipInfo.GetItemByID(itemID)
    for _, line in ipairs(tooltip and tooltip.lines or {}) do
        if line.leftText == ITEM_UNIQUE then return true end
    end
    return false
end

local function FreeBagSpace(itemID)
    local family = C_Item.GetItemFamily(itemID) or 0
    local stackSize = select(8, C_Item.GetItemInfo(itemID)) or 1
    local isCraftingReagent = select(17, C_Item.GetItemInfo(itemID))

    local canFit = 0
    for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
        local freeSlots, bagType = C_Container.GetContainerNumFreeSlots(bag)
        freeSlots = freeSlots or 0
        local usable
        if bag == Enum.BagIndex.ReagentBag then
            usable = isCraftingReagent
        else
            usable = bagType == 0 or (bagType and bit.band(family, bagType) == bagType)
        end
        if usable then
            canFit = canFit + freeSlots * stackSize
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    canFit = canFit + stackSize - (info.stackCount or 0)
                end
            end
        end
    end
    return canFit, stackSize
end

local function IsCurrency(link)
    return link ~= nil and link:match("currency") ~= nil
end

-- Extended costs only sell in the vendor's bundle, so amounts snap up to a whole one.
local function RoundToBundle(amount)
    local remainder = amount % order.preset
    if remainder == 0 then return amount end
    return amount + order.preset - remainder
end

local function UpdateStackClick()
    local increase = (order.partialFit == 0 and order.stack or order.partialFit) - (order.split % order.stack)
    order.stackClick = order.split + (increase == 0 and order.stack or increase)
end

local function UpdateDisplay()
    frame.left:SetEnabled(order.split > (order.altMode and order.preset or 1))
    frame.right:SetEnabled(order.split < order.max)
    frame.maxButton:SetEnabled(order.split < order.max)

    UpdateStackClick()
    frame.stackButton:SetEnabled(order.max >= order.stackClick)

    if not order.altMode then
        local cost = math.ceil(order.split * order.price / order.preset)
        frame.costAmounts[1]:SetText(math.floor(cost / 10000))
        frame.costAmounts[2]:SetText(math.floor(cost / 100) % 100)
        frame.costAmounts[3]:SetText(cost % 100)
    else
        local bundles = RoundToBundle(order.split) / order.preset
        for i = 1, 3 do
            local price = order.altPrices[i]
            frame.costIcons[i]:SetTexture(order.altTextures[i])
            frame.costAmounts[i]:SetText(price and bundles * price or "")
        end
    end

    frame.amount:SetText(order.split)
end

local function SetSplit(amount)
    order.split = math.max(math.min(amount, order.max), order.altMode and order.preset or 1)
    UpdateDisplay()
end

local function Purchase(amount)
    frame:Hide()
    DevLog("Buying %d of merchant index %d", amount, order.itemIndex)
    if IsCurrency(order.itemLink) then
        BuyMerchantItem(order.itemIndex, amount)
    else
        LuckyGrabbag.QueueMerchantPurchase(order.itemIndex, amount, order.stack)
    end
end

local function VerifyPurchase(amount)
    if order.altMode then amount = RoundToBundle(amount) end
    if amount <= 0 then return end

    local overOneStack = amount > order.stack and amount > order.preset
    if overOneStack and db.bulkBuyConfirm then
        local dialog = StaticPopup_Show("LUCKYGB_BULK_BUY_CONFIRM", S().confirm:format(amount, order.itemName))
        if dialog then dialog.data = amount end
    else
        Purchase(amount)
    end
end

local TOOLTIP_LINES = {
    stack = {
        label = function() return S().stackPurchase end,
        field = "stackClick",
        { label = function() return S().stackSize end,    field = "stack" },
        { label = function() return S().partialStack end, field = "partialFit" },
    },
    max = {
        label = function() return S().maxPurchase end,
        field = "max",
        { label = function() return S().canAfford end, field = "afford" },
        { label = function() return S().canFit end,    field = "fit" },
        { label = function() return S().vendorHas end, field = "available", hidden = function() return order.available <= 1 end },
    },
}

local function ShowTooltip(button)
    local lines = TOOLTIP_LINES[button == frame.maxButton and "max" or "stack"]
    local total = order[lines.field]

    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(lines.label() .. "|cFFFFFFFF - |r" .. GREEN_FONT_COLOR_CODE .. total .. "|r")
    for _, line in ipairs(lines) do
        if not (line.hidden and line.hidden()) then
            local amount = order[line.field]
            local color = amount == total and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
            GameTooltip:AddDoubleLine(line.label(), amount, 1, 1, 1, color.r, color.g, color.b)
        end
    end
    GameTooltip:Show()
end

local function RefreshTooltip(button)
    if button:IsEnabled() then ShowTooltip(button) else GameTooltip:Hide() end
end

local function OnStackClick(button, mouseButton)
    if mouseButton == "RightButton" then
        SetSplit(order.split <= order.stack and 1 or order.split - order.stack)
    else
        SetSplit(order.stackClick)
    end
    RefreshTooltip(button)
end

local function Step(direction)
    SetSplit(order.split + direction * (order.altMode and order.preset or 1))
end

local function OnChar(_, text)
    local digit = tonumber(text)
    if not digit then return end

    local typed = (order.typing and order.split or 0) * 10 + digit
    if typed == 0 then return end
    order.typing = true
    SetSplit(typed)
end

local function OnKeyDown(self, key)
    if key == "BACKSPACE" or key == "DELETE" then
        if not order.typing or order.split == 1 then return end
        local trimmed = math.floor(order.split / 10)
        if trimmed <= 1 then order.typing = false end
        SetSplit(trimmed)
    elseif key == "ENTER" then
        VerifyPurchase(order.split)
    elseif key == "ESCAPE" then
        self:Hide()
    elseif key == "LEFT" or key == "DOWN" then
        Step(-1)
    elseif key == "RIGHT" or key == "UP" then
        Step(1)
    elseif key == "PRINTSCREEN" then
        Screenshot()
    end
end

local function CreateButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(78, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateArrow(parent, direction)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    local base = "Interface\\MoneyFrame\\Arrow-" .. direction
    button:SetNormalTexture(base .. "-Up")
    button:SetPushedTexture(base .. "-Down")
    button:SetDisabledTexture(base .. "-Disabled")
    return button
end

local function AddBackground(parent, width, height, point, top, bottom)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame2")
    tex:SetTexCoord(0, 0.671875, top, bottom)
    if width then tex:SetSize(width, height) end
    if point then tex:SetPoint(point) end
    return tex
end

-- Built to match Blizzard's stack split window, since it stands in for it.
local function CreateWindow()
    frame = CreateFrame("Frame", "LGB_BulkBuyFrame", UIParent)
    frame:SetSize(230, 134)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:Hide()

    local top = AddBackground(frame, 230, 14, "TOP", 0, 0.109375)
    local bottom = AddBackground(frame, 230, 20, "BOTTOM", 0.59375, 0.75)
    local middle = AddBackground(frame, nil, nil, nil, 0.109375, 0.59375)
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")

    local amountBox = frame:CreateTexture(nil, "BORDER")
    amountBox:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame")
    amountBox:SetTexCoord(0.10546875, 0.578125, 0.109375, 0.3671875)
    amountBox:SetSize(121, 33)
    amountBox:SetPoint("TOP", 1, -14)

    frame.amount = frame:CreateFontString(nil, "BORDER", "GameFontHighlight")
    frame.amount:SetJustifyH("RIGHT")
    frame.amount:SetPoint("RIGHT", amountBox, -12, 2)

    frame.left = CreateArrow(frame, "Left")
    frame.left:SetPoint("TOPRIGHT", amountBox, "TOP", -60, -8)
    frame.left:SetScript("OnClick", function() Step(-1) end)

    frame.right = CreateArrow(frame, "Right")
    frame.right:SetPoint("TOPLEFT", amountBox, "TOP", 63, -8)
    frame.right:SetScript("OnClick", function() Step(1) end)

    local okay = CreateButton(frame, OKAY, function() VerifyPurchase(order.split) end)
    okay:SetPoint("RIGHT", frame, "BOTTOM", -3, 30)

    local cancel = CreateButton(frame, CANCEL, function() frame:Hide() end)
    cancel:SetPoint("LEFT", frame, "BOTTOM", 5, 30)

    frame.stackButton = CreateButton(frame, S().stack, OnStackClick)
    frame.stackButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.stackButton:SetPoint("BOTTOM", okay, "TOP", 0, 2)

    frame.maxButton = CreateButton(frame, S().max, function(button)
        SetSplit(order.max)
        RefreshTooltip(button)
    end)
    frame.maxButton:SetPoint("BOTTOM", cancel, "TOP", 0, 2)

    for _, button in ipairs({ frame.stackButton, frame.maxButton }) do
        button:SetScript("OnEnter", ShowTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end

    local costRow = CreateFrame("Frame", nil, frame)
    costRow:SetSize(204, 24)
    costRow:SetPoint("TOP", 2, -45)
    frame.costIcons, frame.costAmounts = {}, {}
    for i = 1, 3 do
        local offset = (i - 1) * 68
        local icon = costRow:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 48 + offset, 0)
        frame.costIcons[i] = icon

        local amount = costRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        amount:SetSize(52, 20)
        amount:SetPoint("LEFT", -2 + offset, 0)
        frame.costAmounts[i] = amount
    end

    frame:SetScript("OnChar", OnChar)
    frame:SetScript("OnKeyDown", OnKeyDown)
    frame:SetScript("OnHide", function()
        for i = 1, 3 do
            frame.costIcons[i]:SetTexture(nil)
            frame.costAmounts[i]:SetText("")
        end
        StaticPopup_Hide("LUCKYGB_BULK_BUY_CONFIRM")
    end)
end

local function ShowWindow(anchor)
    if not frame then CreateWindow() end
    order.typing = false
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT")
    frame:Show()
    UpdateDisplay()
end

-- Opening on one item is no choice at all, so it falls back to Blizzard's single buy.
local function OpenOrBuyOne(button)
    if order.max <= 0 then return end
    if order.max == 1 then
        MerchantItemButton_OnClick(button, "LeftButton")
        return
    end
    order.split = order.altMode and order.preset or 1
    UpdateStackClick()
    ShowWindow(button)
end

local function AltCostAffordable(index, costIndex)
    local _, price, link = GetMerchantItemCostItem(index, costIndex)
    if not link or not price or price <= 0 then return NO_COST_CAP end

    local owned
    if IsCurrency(link) then
        owned = C_CurrencyInfo.GetCurrencyInfoFromLink(link).quantity
    else
        owned = C_Item.GetItemCount(tonumber(link:match("item:(%d+)")), true)
    end
    return math.floor(owned / price) * order.preset
end

local function OpenForAltCurrency(button)
    order.altMode = true
    order.altPrices, order.altTextures = {}, {}

    local costCount = GetMerchantItemCostInfo(order.itemIndex)
    order.afford = costCount > 0 and NO_COST_CAP or order.fit
    for i = 1, costCount do
        local texture, price = GetMerchantItemCostItem(order.itemIndex, i)
        order.altTextures[i], order.altPrices[i] = texture, price
        order.afford = math.min(order.afford, AltCostAffordable(order.itemIndex, i))
    end
    if order.itemID and IsUnique(order.itemID) then order.afford = 1 end

    order.max = math.min(order.fit, order.afford)
    if order.available > -1 then
        order.max = math.min(order.max, order.available * order.preset)
    end
    order.partialFit = order.fit % order.stack
    OpenOrBuyOne(button)
end

local function OpenForGold(button)
    for i = 1, 3 do frame.costIcons[i]:SetTexture(MONEY_TEXTURES[i]) end

    if order.itemID and IsUnique(order.itemID) then
        order.afford = 1
    elseif order.price <= 0 then
        order.afford = order.fit
    else
        order.afford = math.floor(GetMoney() / math.ceil(order.price / order.preset))
    end

    order.max = math.min(order.fit, order.afford)
    if order.available > -1 then
        order.max = math.min(order.max, order.available)
    end
    OpenOrBuyOne(button)
end

local function CurrencyRoom(link)
    local info = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
    if info.maxQuantity <= 0 then return NO_CURRENCY_CAP end
    return info.maxQuantity - info.quantity
end

local function ShouldHandle()
    return db.bulkBuy
        and not C_AddOns.IsAddOnLoaded("BuyEmAll")
        and MerchantFrame.selectedTab == 1
        and IsShiftKeyDown() and not IsControlKeyDown()
        and not GetCurrentKeyBoardFocus()
end

local function OnModifiedClick(button, mouseButton)
    if not ShouldHandle() then
        return originalOnModifiedClick(button, mouseButton)
    end

    local index = button:GetID()
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info then return end

    wipe(order)
    order.itemIndex = index
    order.itemName = info.name
    order.price = info.price or 0
    order.preset = math.max(info.stackCount or 1, 1)
    order.available = info.numAvailable
    order.itemLink = GetMerchantItemLink(index)
    order.altMode = false
    if not frame then CreateWindow() end

    if not order.itemLink then
        local dialog = StaticPopup_Show("LUCKYGB_BULK_BUY_CONFIRM_ONE", S().confirm:format(order.preset, order.itemName))
        if dialog then dialog.data = index end
        return
    end

    if IsCurrency(order.itemLink) then
        order.stack = order.preset
        order.partialFit = 0
        order.fit = CurrencyRoom(order.itemLink)
    else
        order.itemID = tonumber(order.itemLink:match("item:(%d+)"))
        order.fit, order.stack = FreeBagSpace(order.itemID)
        order.partialFit = order.fit % order.stack
    end

    DevLog("%s: fit %d, stack %d, price %d", order.itemName, order.fit, order.stack, order.price)
    if info.hasExtendedCost and order.price <= 0 then
        OpenForAltCurrency(button)
    else
        OpenForGold(button)
    end
end

StaticPopupDialogs["LUCKYGB_BULK_BUY_CONFIRM"] = {
    text         = "%s",
    button1      = YES,
    button2      = NO,
    OnAccept     = function(dialog) Purchase(dialog.data) end,
    timeout      = 0,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["LUCKYGB_BULK_BUY_CONFIRM_ONE"] = {
    text         = "%s",
    button1      = YES,
    button2      = NO,
    OnAccept     = function(dialog) BuyMerchantItem(dialog.data) end,
    timeout      = 0,
    hideOnEscape = true,
    preferredIndex = 3,
}

function LuckyGrabbag.BulkBuy:Init(database)
    db = database

    -- Replaced rather than hooked: a post-hook cannot stop Blizzard's stack splitter opening.
    -- luacheck: globals MerchantItemButton_OnModifiedClick
    originalOnModifiedClick = MerchantItemButton_OnModifiedClick
    MerchantItemButton_OnModifiedClick = OnModifiedClick

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function()
        if frame then frame:Hide() end
    end)
end
