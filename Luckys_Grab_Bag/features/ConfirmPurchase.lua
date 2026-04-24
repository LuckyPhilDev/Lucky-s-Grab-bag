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
local lastClickedMerchantButton

local function DevLog(msg)
    LuckyGrabbag.DevLog("ConfirmPurchase", msg)
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
        tooltip = function() GameTooltip:SetText("Confirm Purchase") end,
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
                DevLog("Tracked click on " .. self:GetName())
            end)
            merchantBtn._lgbConfirmHooked = true
        end
    end
end

local function AnchorButton()
    button:ClearAllPoints()
    if db.confirmPurchaseOverlay and lastClickedMerchantButton and lastClickedMerchantButton:IsVisible() then
        button:SetPoint("CENTER", lastClickedMerchantButton, "CENTER", 0, 0)
        DevLog("Overlay anchor on " .. lastClickedMerchantButton:GetName())
    else
        container:RestorePosition()
        button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        DevLog("Anchored next to MerchantFrame")
    end
end

local function Refresh()
    if not db.showConfirmPurchase then
        if button then button:Hide() end
        return
    end

    if merchantOpen and popupShown then
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

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            merchantOpen = true
            HookMerchantButtons()
        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
            lastClickedMerchantButton = nil
        end
        Refresh()
    end)

    StaticPopup1:HookScript("OnShow", function() ---@diagnostic disable-line: undefined-global
        popupShown = true
        Refresh()
    end)
    StaticPopup1:HookScript("OnHide", function() ---@diagnostic disable-line: undefined-global
        popupShown = false
        Refresh()
    end)

    DevLog("Initialized")
end
