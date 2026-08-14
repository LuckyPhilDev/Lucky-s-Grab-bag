-- Lucky's Grab-bag: Confirm Purchase button next to vendor window
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ConfirmPurchase = {}

local TICK_ICON = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local MERCHANT_ITEM_COUNT = 12

local db
local button
local container
local merchantOpen = false
local popupShown = false
local popupIsBagUse = false
local lastClickedMerchantButton
local lastClickedBag, lastClickedSlot
local lastClickedBagButton
local lastClickSource -- "merchant" or "bag"
local useContainerItemHooked = false

local function DevLog(msg)
    LuckyGrabbag.DevLog("ConfirmPurchase", msg)
end

-- StaticPopup names that fire from clicking an item in the player's bags
-- (vs the merchant frame). These need the same bag-overlay treatment.
local BAG_USE_POPUP_NAMES = {
    USE_NO_REFUND_CONFIRM = true,
    END_REFUND            = true,
    EQUIP_BIND            = true,
}

local function IsBagUsePopup(popup)
    return popup and popup.which and BAG_USE_POPUP_NAMES[popup.which] == true
end

local function CreateContainer()
    if container then return end

    container = CreateFrame("Frame", "LGB_ConfirmPurchaseParent", UIParent) ---@diagnostic disable-line: undefined-global
    container:SetSize(1, 1)
    container:SetFrameStrata("HIGH")
    LuckyGrabbag.EnableGroupDrag(container, MerchantFrame, "confirmPurchasePos", 5, 0) ---@diagnostic disable-line: undefined-global
end

local function OnClick()
    if StaticPopup1Button1 and StaticPopup1Button1:IsShown() and StaticPopup1Button1:IsEnabled() then ---@diagnostic disable-line: undefined-global
        StaticPopup1Button1:Click() ---@diagnostic disable-line: undefined-global
    end
end

local function CreateButton()
    if button then return end
    CreateContainer()

    button = LuckyGrabbag.CreateIconButton({
        parent  = container,
        name    = "LGB_ConfirmPurchaseButton",
        texture = TICK_ICON,
        tooltip = function() GameTooltip:SetText(LuckyGrabbag.Strings.confirmPurchase.tooltip) end,
    })
    button:SetFrameStrata("TOOLTIP")
    button:SetPushedTexture(TICK_ICON)
    button:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8, 1)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", OnClick)

    container:RegisterDraggable(button)
    button:Hide()
end

local function HookMerchantButtons()
    for i = 1, MERCHANT_ITEM_COUNT do
        local merchantBtn = _G["MerchantItem" .. i .. "ItemButton"] ---@diagnostic disable-line: undefined-global
        if merchantBtn and not merchantBtn._lgbConfirmHooked then
            merchantBtn:HookScript("OnMouseDown", function(self)
                lastClickedMerchantButton = self
                lastClickSource = "merchant"
                DevLog("Tracked click on " .. self:GetName())
            end)
            merchantBtn._lgbConfirmHooked = true
        end
    end
end

local function HookUseContainerItem()
    if useContainerItemHooked or not C_Container or not C_Container.UseContainerItem then ---@diagnostic disable-line: undefined-global
        DevLog("HookUseContainerItem skipped (hooked=" .. tostring(useContainerItemHooked) .. " api=" .. tostring(C_Container and C_Container.UseContainerItem) .. ")") ---@diagnostic disable-line: undefined-global
        return
    end
    hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot) ---@diagnostic disable-line: undefined-global
        lastClickedBag, lastClickedSlot = bag, slot
        lastClickedBagButton = nil
        lastClickSource = "bag"
        DevLog("UseContainerItem hook fired bag=" .. tostring(bag) .. " slot=" .. tostring(slot))
    end)
    useContainerItemHooked = true
    DevLog("UseContainerItem hook installed")
end

local function HookBagButtons()
    local hookedCount = 0
    local function hookFrame(frame, label)
        if not frame or not frame.Items then return end
        for _, btn in ipairs(frame.Items) do
            if not btn._lgbConfirmHooked then
                btn:HookScript("OnMouseDown", function(self)
                    lastClickedBagButton = self
                    if self.GetBagID then
                        lastClickedBag, lastClickedSlot = self:GetBagID(), self:GetID()
                    end
                    lastClickSource = "bag"
                    DevLog("Bag button mousedown " .. tostring(self:GetName()) ..
                        " bag=" .. tostring(self.GetBagID and self:GetBagID()) ..
                        " slot=" .. tostring(self:GetID()))
                end)
                btn._lgbConfirmHooked = true
                hookedCount = hookedCount + 1
            end
        end
    end
    hookFrame(ContainerFrameCombinedBags, "CombinedBags") ---@diagnostic disable-line: undefined-global
    for i = 1, 13 do
        hookFrame(_G["ContainerFrame" .. i], "ContainerFrame" .. i)
    end
    if hookedCount > 0 then DevLog("Hooked " .. hookedCount .. " new bag buttons") end
end

local function FindBagSlotByLink(link)
    if not link or not C_Container or not C_Container.GetContainerNumSlots then return end ---@diagnostic disable-line: undefined-global
    for bag = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0 ---@diagnostic disable-line: undefined-global
        for slot = 1, numSlots do
            if C_Container.GetContainerItemLink(bag, slot) == link then ---@diagnostic disable-line: undefined-global
                DevLog("Matched link in bag " .. bag .. " slot " .. slot)
                return bag, slot
            end
        end
    end
    DevLog("No bag slot matched link " .. tostring(link))
end

local function FindMouseoverBagButton()
    for _, focus in ipairs(GetMouseFoci()) do ---@diagnostic disable-line: undefined-global
        local frame = focus
        while frame do
            if frame.GetBagID and frame.GetID then
                local ok, b = pcall(frame.GetBagID, frame)
                if ok and b then
                    DevLog("FindMouseoverBagButton match name=" .. tostring(frame:GetName()) ..
                        " bag=" .. tostring(b) .. " slot=" .. tostring(frame:GetID()))
                    return frame, b, frame:GetID()
                end
            end
            frame = frame.GetParent and frame:GetParent()
        end
    end
    DevLog("FindMouseoverBagButton: no match")
end

local function FindBagButton(bag, slot)
    local function check(frame, label)
        if not frame or not frame:IsVisible() or not frame.Items then return end
        for _, btn in ipairs(frame.Items) do
            if btn.GetBagID and btn:IsVisible() then
                if btn:GetBagID() == bag and btn:GetID() == slot then
                    DevLog("FindBagButton match in " .. label .. " name=" .. tostring(btn:GetName()))
                    return btn
                end
            end
        end
    end
    local btn = check(ContainerFrameCombinedBags, "CombinedBags") ---@diagnostic disable-line: undefined-global
    if btn then return btn end
    for i = 1, 13 do
        btn = check(_G["ContainerFrame" .. i], "ContainerFrame" .. i)
        if btn then return btn end
    end

    -- Fallback: the button under the cursor (handles third-party bag addons like Bagnon, ElvUI).
    local mouseBtn, mouseBag, mouseSlot = FindMouseoverBagButton()
    if mouseBtn and mouseBag == bag and mouseSlot == slot then
        DevLog("FindBagButton mouseover match name=" .. tostring(mouseBtn:GetName()))
        return mouseBtn
    end

    DevLog("FindBagButton: no visible match for bag=" .. tostring(bag) .. " slot=" .. tostring(slot))
end

local function GetOverlayTarget()
    DevLog("GetOverlayTarget source=" .. tostring(lastClickSource) ..
        " bag=" .. tostring(lastClickedBag) ..
        " slot=" .. tostring(lastClickedSlot) ..
        " bagBtn=" .. tostring(lastClickedBagButton and lastClickedBagButton:GetName()))
    if lastClickSource == "bag" then
        if lastClickedBagButton and lastClickedBagButton:IsVisible() then
            DevLog("Using cached bag button")
            return lastClickedBagButton
        end
        if lastClickedBag then
            local b = FindBagButton(lastClickedBag, lastClickedSlot)
            if b and b:IsVisible() then return b end
            DevLog("bag target unavailable (b=" .. tostring(b) .. ")")
        end
    elseif lastClickSource == "merchant" and lastClickedMerchantButton and lastClickedMerchantButton:IsVisible() then
        return lastClickedMerchantButton
    end
end

local function AnchorButton()
    button:ClearAllPoints()
    local target = (not db.confirmPurchaseOnSide) and GetOverlayTarget() or nil
    if target then
        button:SetPoint("CENTER", target, "CENTER", 0, 0)
        DevLog("Overlay anchor on " .. (target:GetName() or "bag item"))
    elseif merchantOpen then
        container:RestorePosition()
        button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        DevLog("Anchored next to MerchantFrame")
    else
        button:SetPoint("LEFT", StaticPopup1, "RIGHT", 5, 0) ---@diagnostic disable-line: undefined-global
        DevLog("Anchored next to StaticPopup1 (no merchant)")
    end
end

local function Refresh()
    if not db.showConfirmPurchase then
        if button then button:Hide() end
        return
    end

    local active = popupShown and (merchantOpen or popupIsBagUse)
    if active then
        CreateButton()
        AnchorButton()
        button:Show()
    elseif button then
        button:Hide()
    end
end

function LuckyGrabbag.ConfirmPurchase:ApplySetting()
    Refresh()
end

function LuckyGrabbag.ConfirmPurchase:Init(database)
    db = database

    HookUseContainerItem()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            merchantOpen = true
            HookMerchantButtons()
            HookBagButtons()
        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
            lastClickedMerchantButton = nil
            lastClickedBag, lastClickedSlot = nil, nil
            lastClickedBagButton = nil
            lastClickSource = nil
        end
        Refresh()
    end)

    StaticPopup1:HookScript("OnShow", function(self) ---@diagnostic disable-line: undefined-global
        popupShown = true
        popupIsBagUse = IsBagUsePopup(self)
        local which = self.which or "?"
        local data = self.data
        local dataDesc = "nil"
        if type(data) == "table" then
            local parts = {}
            for k, v in pairs(data) do
                table.insert(parts, tostring(k) .. "=" .. tostring(v))
            end
            dataDesc = "{" .. table.concat(parts, ", ") .. "}"
        elseif data ~= nil then
            dataDesc = tostring(data)
        end
        DevLog("StaticPopup1 shown which=" .. tostring(which) .. " isBagUse=" .. tostring(popupIsBagUse) .. " data=" .. dataDesc)

        if popupIsBagUse then
            -- Stale lastClicked data (set by previous UseContainerItem) would mislead FindBagButton.
            -- For bag-use popups, find the bag button currently under the cursor instead.
            lastClickedBagButton = nil
            lastClickedBag, lastClickedSlot = nil, nil
            lastClickSource = nil
            local btn, bag, slot = FindMouseoverBagButton()
            if btn then
                lastClickedBagButton = btn
                lastClickedBag, lastClickedSlot = bag, slot
                lastClickSource = "bag"
            end
        end

        local active = merchantOpen or popupIsBagUse
        if active and type(data) == "table" then
            local btn = data.button or data.itemButton
            if btn and btn.GetBagID then
                lastClickedBagButton = btn
                lastClickedBag, lastClickedSlot = btn:GetBagID(), btn:GetID()
                lastClickSource = "bag"
                DevLog("Extracted button from popup data: " .. tostring(btn:GetName()))
            else
                local bag = data.bag or data.bagID or data.containerID
                local slot = data.slot or data.slotIndex or data.containerSlot
                if not (bag and slot) and data.link then
                    bag, slot = FindBagSlotByLink(data.link)
                end
                if bag and slot then
                    lastClickedBag, lastClickedSlot = bag, slot
                    lastClickedBagButton = nil
                    lastClickSource = "bag"
                    DevLog("Resolved bag/slot " .. bag .. "/" .. slot)
                end
            end
        end

        if active then HookBagButtons() end
        Refresh()
    end)
    StaticPopup1:HookScript("OnHide", function() ---@diagnostic disable-line: undefined-global
        popupShown = false
        popupIsBagUse = false
        Refresh()
    end)

    DevLog("Initialized")
end
