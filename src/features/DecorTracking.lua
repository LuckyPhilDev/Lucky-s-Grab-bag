-- Lucky's Grab-bag: Housing decor shopping list.
-- Blizzard's content tracker holds 15 collectables and no quantities, which a
-- blueprint blows through immediately. This keeps its own list of how many of
-- each decor piece a blueprint wants, works out what is still outstanding from
-- what you own, and flags those pieces when a vendor sells them.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DecorTracking = {}

local Feature = LuckyGrabbag.DecorTracking

local DECOR_TRACKING = Enum.ContentTrackingType.Decor
local DECOR_ENTRY = Enum.HousingCatalogEntryType.Decor
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local WAYPOINT_ATLAS = "waypoint-mappin-minimap-untracked"
local BUYBACK_ITEM_COUNT = 12 -- the buyback tab reuses the merchant item buttons, and shows more of them
local ROW_HEIGHT = 26

local Rich = LuckySettings.Rich
local R = Rich.Theme
local R_FONT = Rich.Font

local db
local trackButton
local buyAllButton
local buyAllContainer
local window

local DevLog = LuckyGrabbag.Logger("DecorTracking")

local function Print(msg)
    print(LuckyGrabbag.PREFIX .. " " .. msg)
end

local function S()
    return LuckyGrabbag.Strings.decorTracking
end

-------------------------------------------------------------------------------
-- The list
-------------------------------------------------------------------------------

local function EntryInfo(recordID)
    return C_HousingCatalog.GetCatalogEntryInfoByRecordID(DECOR_ENTRY, recordID)
end

--- What a blueprint can actually draw on, matching the count Blizzard shows in
--- the blueprint list. Copies already placed in a house are in use, and dyed
--- copies are not eligible, so neither counts however many you own.
local function AvailableCount(recordID)
    local info = EntryInfo(recordID)
    if not info then return 0 end

    local entryID = { recordID = info.recordID, entryType = info.entryType }
    local dyed = 0
    for _, variant in ipairs(C_HousingCatalog.GetAllVariantInfosForEntry(entryID) or {}) do
        if variant.entryVariantID.variantIdentifier ~= 0 then
            dyed = dyed + variant.numStored
        end
    end

    return math.max(0, info.totalNumStored - dyed) + info.remainingRedeemable
end

local function StillNeeded(recordID, required)
    return math.max(0, required - AvailableCount(recordID))
end

--- recordIDs on the list, ordered by name so the window and chat agree.
local function SortedRecordIDs()
    local ids = {}
    for recordID in pairs(db.decorList) do
        ids[#ids + 1] = recordID
    end
    table.sort(ids, function(a, b)
        local infoA, infoB = EntryInfo(a), EntryInfo(b)
        return (infoA and infoA.name or tostring(a)) < (infoB and infoB.name or tostring(b))
    end)
    return ids
end

local function OutstandingCount()
    local count = 0
    for recordID, required in pairs(db.decorList) do
        if StillNeeded(recordID, required) > 0 then
            count = count + 1
        end
    end
    return count
end

-------------------------------------------------------------------------------
-- Blueprint content list: the Track Missing button
-------------------------------------------------------------------------------

--- Decor the open blueprint wants, as recordID -> how many it places.
local function BlueprintDecorRequirements()
    local list = HousingBlueprintContentListFrame
    local contentInfo = list and list.blueprintContentInfo
    if not contentInfo or not contentInfo.contentGroups then return {} end

    local required = {}
    for _, group in ipairs(contentInfo.contentGroups) do
        for _, entry in ipairs(group.entries) do
            local isMissingDecor = entry.contentType == Enum.HousingBlueprintContentType.Decor
                and not entry.invalid
                and entry.numMissing > 0
            if isMissingDecor then
                required[entry.recordID] = math.max(required[entry.recordID] or 0, entry.total)
            end
        end
    end
    return required
end

local function TrackMissing()
    local added, raised = 0, 0

    -- Two blueprints wanting the same piece take the larger requirement, not the
    -- sum: you furnish one house at a time, and the pieces move between them.
    for recordID, required in pairs(BlueprintDecorRequirements()) do
        local current = db.decorList[recordID]
        if not current then
            db.decorList[recordID] = required
            added = added + 1
        elseif required > current then
            db.decorList[recordID] = required
            raised = raised + 1
        end
    end

    DevLog(string.format("Added %d, raised %d", added, raised))

    if added > 0 then
        PlaySound(SOUNDKIT.CONTENT_TRACKING_START_TRACKING)
        Print(added == 1 and S().addedOne or string.format(S().addedMany, added))
    elseif raised > 0 then
        Print(string.format(S().raisedCounts, raised))
    else
        Print(S().nothingMissing)
    end

    Feature:OpenList()
end

local function UpdateTrackButton()
    if not trackButton then return end

    local list = HousingBlueprintContentListFrame
    local show = db.blueprintTrackMissing and list:HasTargetHouse()
    trackButton:SetShown(show)
    if show then
        trackButton:SetEnabled(next(BlueprintDecorRequirements()) ~= nil)
    end
end

local function CreateTrackButton()
    local list = HousingBlueprintContentListFrame

    trackButton = CreateFrame("Button", "LGB_TrackMissingDecorButton", list, "UIPanelButtonTemplate")
    trackButton:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -10, 10)
    trackButton:SetHeight(list.BottomCloseButton:GetHeight())
    trackButton:SetText(S().trackMissing)
    trackButton:SetWidth(trackButton:GetTextWidth() + 24)
    trackButton:SetScript("OnClick", TrackMissing)
    trackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().trackMissing)
        GameTooltip:AddLine(S().trackMissingTooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    trackButton:SetScript("OnLeave", GameTooltip_Hide)

    hooksecurefunc(list, "ShowBlueprintContents", UpdateTrackButton)
    list:HookScript("OnShow", UpdateTrackButton)
    UpdateTrackButton()

    DevLog("Track Missing button created")
end

-------------------------------------------------------------------------------
-- Blizzard's tracker, one piece at a time
-------------------------------------------------------------------------------

local function StopBlizzardTracking(recordID)
    if not C_ContentTracking.IsTracking(DECOR_TRACKING, recordID) then return end

    C_ContentTracking.StopTracking(DECOR_TRACKING, recordID, Enum.ContentTrackingStopType.Manual)
    PlaySound(SOUNDKIT.CONTENT_TRACKING_STOP_TRACKING)
end

local function StartBlizzardTracking(recordID)
    if C_ContentTracking.IsTracking(DECOR_TRACKING, recordID) then return true end

    local err = C_ContentTracking.StartTracking(DECOR_TRACKING, recordID)
    if err == Enum.ContentTrackingError.MaxTracked then
        Print(string.format(S().blizzardFull, Constants.ContentTrackingConsts.MaxTrackedCollectableSources))
        return false
    elseif err then
        Print(S().blizzardUntrackable)
        return false
    end

    PlaySound(SOUNDKIT.CONTENT_TRACKING_START_TRACKING)
    return true
end

--- Tracks the piece, points the waypoint arrow at it and opens the map where
--- it can be found.
local function ShowOnMap(recordID)
    if not ContentTrackingUtil.IsContentTrackingEnabled() then
        Print(CONTENT_TRACKING_DISABLED_TOOLTIP_PROMPT)
        return
    end

    if not StartBlizzardTracking(recordID) then return end

    local ignoreWaypoint = true
    local result, mapID = C_ContentTracking.GetBestMapForTrackable(DECOR_TRACKING, recordID, ignoreWaypoint)
    if result == Enum.ContentTrackingResult.DataPending then
        Print(S().locationPending)
        return
    end
    if result ~= Enum.ContentTrackingResult.Success or not mapID then
        Print(S().locationUnknown)
        return
    end

    C_SuperTrack.SetSuperTrackedContent(DECOR_TRACKING, recordID)
    OpenWorldMap(mapID)
end

-------------------------------------------------------------------------------
-- The shopping list window
-------------------------------------------------------------------------------

local function BuildWindow()
    if window then return window end

    local f = CreateFrame("Frame", "LuckyGrabbagDecorListWindow", UIParent)
    f:SetSize(460, 440)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    Rich.FillBg(f, R.bg)
    table.insert(UISpecialFrames, "LuckyGrabbagDecorListWindow")

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(40)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    Rich.FillBg(titleBar, R.bg2)
    Rich.EdgeRule(titleBar, "BOTTOM", R.border)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        db.decorListPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(R_FONT, 16, "")
    title:SetPoint("LEFT", 14, 0)
    title:SetText(S().listTitle)
    title:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])

    local subtitle = titleBar:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(R_FONT, 11, "")
    subtitle:SetPoint("RIGHT", -40, 0)
    subtitle:SetText(S().listSubtitle)
    subtitle:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    local saved = db.decorListPos
    f:ClearAllPoints()
    if saved and saved.point then
        f:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", 0, 0)

    local desc = body:CreateFontString(nil, "OVERLAY")
    desc:SetFont(R_FONT, 12, "")
    desc:SetTextColor(R.text[1], R.text[2], R.text[3])
    desc:SetSpacing(3)
    desc:SetPoint("TOPLEFT", 14, -14)
    desc:SetPoint("TOPRIGHT", -14, -14)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetHeight(32)
    desc:SetText(S().listDescription)

    local headerRow = CreateFrame("Frame", nil, body)
    headerRow:SetHeight(22)
    headerRow:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    headerRow:SetPoint("RIGHT", -14, 0)
    Rich.FillBg(headerRow, R.bg3)
    Rich.EdgeRule(headerRow, "BOTTOM", R.border)

    local function HeaderText(text, x, justify)
        local t = headerRow:CreateFontString(nil, "OVERLAY")
        t:SetFont(R_FONT, 10, "")
        t:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
        t:SetPoint("LEFT", headerRow, "LEFT", x, 0)
        t:SetJustifyH(justify or "LEFT")
        t:SetText(string.upper(text))
        return t
    end
    HeaderText(S().headerDecor, 10)
    HeaderText(S().headerAvailable, 260)

    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)

    local rowParent = CreateFrame("Frame", nil, scroll)
    rowParent:SetSize(400, 1)
    scroll:SetScrollChild(rowParent)

    local emptyText = body:CreateFontString(nil, "OVERLAY")
    emptyText:SetFont(R_FONT, 12, "")
    emptyText:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    emptyText:SetPoint("TOPLEFT", scroll, "TOPLEFT", 10, -14)
    emptyText:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -10, -14)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetWordWrap(true)
    emptyText:SetText(S().listEmpty)

    local clearAll = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    clearAll:SetSize(90, 22)
    clearAll:SetPoint("BOTTOMRIGHT", -14, 12)
    clearAll:SetText(S().clearAll)
    clearAll:SetScript("OnClick", function()
        wipe(db.decorList)
        Feature:Refresh()
    end)

    local clearCollected = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    clearCollected:SetSize(130, 22)
    clearCollected:SetPoint("RIGHT", clearAll, "LEFT", -6, 0)
    clearCollected:SetText(S().clearCollected)
    clearCollected:SetScript("OnClick", function()
        for recordID, required in pairs(db.decorList) do
            if StillNeeded(recordID, required) == 0 then
                db.decorList[recordID] = nil
            end
        end
        Feature:Refresh()
    end)

    f.rowParent      = rowParent
    f.rows           = {}
    f.emptyText      = emptyText
    f.clearAll       = clearAll
    f.clearCollected = clearCollected

    window = f
    return f
end

local function BuildRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(400, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(R.bg2[1], R.bg2[2], R.bg2[3], 0.5)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(R_FONT, 12, "")
    row.name:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.name:SetWidth(240)
    row.name:SetJustifyH("LEFT")

    row.available = row:CreateFontString(nil, "OVERLAY")
    row.available:SetFont(R_FONT, 12, "")
    row.available:SetPoint("LEFT", row, "LEFT", 260, 0)
    row.available:SetWidth(60)
    row.available:SetJustifyH("LEFT")

    row.pin = CreateFrame("Button", nil, row)
    row.pin:SetSize(18, 18)
    row.pin:SetPoint("RIGHT", row, "RIGHT", -34, 0)
    row.pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.pin.icon = row.pin:CreateTexture(nil, "ARTWORK")
    row.pin.icon:SetAllPoints()
    row.pin.icon:SetAtlas(WAYPOINT_ATLAS)
    row.pin:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            StopBlizzardTracking(self.recordID)
        else
            ShowOnMap(self.recordID)
        end
        Feature:Refresh()
    end)
    row.pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().pinTooltipTitle)
        GameTooltip:AddLine(S().pinTooltip, 1, 1, 1, true)
        if C_ContentTracking.IsTracking(DECOR_TRACKING, self.recordID) then
            GameTooltip:AddLine(S().pinUntrackTooltip, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    row.pin:SetScript("OnLeave", GameTooltip_Hide)

    row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.remove:SetSize(24, 24)
    row.remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.remove:SetScript("OnClick", function(self)
        db.decorList[self.recordID] = nil
        Feature:Refresh()
    end)

    return row
end

local function RefreshWindow()
    if not window or not window:IsShown() then return end

    local ids = SortedRecordIDs()
    window.emptyText:SetShown(#ids == 0)
    window.clearAll:SetEnabled(#ids > 0)
    window.clearCollected:SetEnabled(#ids > OutstandingCount())

    for index, recordID in ipairs(ids) do
        local row = window.rows[index]
        if not row then
            row = BuildRow(window.rowParent, index)
            window.rows[index] = row
        end

        local required = db.decorList[recordID]
        local available = AvailableCount(recordID)
        local needed = math.max(0, required - available)
        local info = EntryInfo(recordID)

        row.name:SetText(info and info.name or S().unknownDecor)
        row.available:SetText(string.format("%d/%d", math.min(available, required), required))

        local nameColor = needed > 0 and R.text or R.textDim
        local availableColor = needed > 0 and R.accentLight or R.textDim
        row.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
        row.available:SetTextColor(availableColor[1], availableColor[2], availableColor[3])

        row.stripe:SetShown(index % 2 == 0)
        row.pin.recordID = recordID
        row.remove.recordID = recordID

        local isTracked = C_ContentTracking.IsTracking(DECOR_TRACKING, recordID)
        row.pin.icon:SetVertexColor(isTracked and 0.2 or 0.5, isTracked and 1 or 0.5, isTracked and 0.2 or 0.5)
        row.pin:SetShown(needed > 0)

        row:Show()
    end

    for index = #ids + 1, #window.rows do
        window.rows[index]:Hide()
    end

    window.rowParent:SetHeight(math.max(1, #ids * ROW_HEIGHT))
end

function Feature:OpenList()
    BuildWindow()
    window:Show()
    Feature:Refresh()
end

-------------------------------------------------------------------------------
-- Vendors
-------------------------------------------------------------------------------

--- How many of the decor this merchant slot grants you still need, or 0.
local function NeededAtMerchantIndex(index)
    local link = GetMerchantItemLink(index)
    if not link then return 0 end

    local entryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(link)
    local required = entryInfo and db.decorList[entryInfo.recordID]
    if not required then return 0 end

    return StillNeeded(entryInfo.recordID, required)
end

local function DecorGlow(button)
    if not button.lgbDecorGlow then
        local glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(GLOW_TEXTURE)
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(0.1, 1, 0.1)
        glow:SetPoint("CENTER")
        glow:SetSize(button:GetWidth() * 1.6, button:GetHeight() * 1.6)
        button.lgbDecorGlow = glow

        local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
        count:SetTextColor(1, 0.82, 0)
        button.lgbDecorCount = count
    end
    return button.lgbDecorGlow
end

local function SetGlow(button, needed)
    -- Only build the textures for a button that actually needs them.
    if needed == 0 and not button.lgbDecorGlow then return end

    DecorGlow(button):SetShown(needed > 0)
    button.lgbDecorCount:SetShown(needed > 0)
    if needed > 0 then
        button.lgbDecorCount:SetText("x" .. needed)
    end
end

local BUY_THROTTLE = 0.5 -- seconds between purchases, below this the server reports the item busy
local BUY_ALL_CONFIRM_COST = 500 * 10000 -- 500 gold, over this Buy All asks first
local buyQueue = {}
local buyTicker

local function StopBuying()
    if buyTicker then
        buyTicker:Cancel()
        buyTicker = nil
    end
end

--- How many items to buy in total: what you still need, rounded up to whole
--- stacks, capped by the vendor's remaining stock and what you can pay.
local function PurchaseQuantity(index, needed)
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info then return 0 end

    local stackCount = info.stackCount or 1
    local quantity = math.ceil(needed / stackCount) * stackCount

    -- numAvailable is -1 for unlimited stock.
    if info.numAvailable and info.numAvailable >= 0 then
        quantity = math.min(quantity, info.numAvailable * stackCount)
    end

    -- Extended-cost items are priced in currency or items rather than gold, and
    -- the confirmation popup is where the player finds out if they can pay.
    if info.price and info.price > 0 then
        quantity = math.min(quantity, math.floor(GetMoney() / (info.price / stackCount)))
    end

    return quantity
end

local function StackSizeAt(index)
    return math.max(GetMerchantItemMaxStack(index) or 1, 1)
end

--- BuyMerchantItem only buys one stack per call, and calls sent back to back
--- fail with "Item is busy", so orders go out as a spaced run of stack-sized
--- purchases. Spacing and approach follow BuyEmAll.
local function ProcessBuyQueue()
    local job = buyQueue[1]
    if not job or not MerchantFrame:IsShown() then
        wipe(buyQueue)
        StopBuying()
        return
    end

    local amount = math.min(job.remaining, job.perCall)
    BuyMerchantItem(job.index, amount)
    job.remaining = job.remaining - amount
    if job.remaining < 1 then table.remove(buyQueue, 1) end
    if #buyQueue == 0 then StopBuying() end
end

local function QueuePurchase(index, quantity, perCall)
    buyQueue[#buyQueue + 1] = { index = index, remaining = quantity, perCall = perCall }
    if buyTicker then return end

    ProcessBuyQueue() -- the first purchase goes out now, the rest are spaced
    if #buyQueue > 0 then
        buyTicker = C_Timer.NewTicker(BUY_THROTTLE, ProcessBuyQueue)
    end
end

local function TryAutoBuy(button)
    local index = button:GetID()
    local needed = NeededAtMerchantIndex(index)
    if needed == 0 then return end

    local quantity = PurchaseQuantity(index, needed)
    if quantity < 1 then
        Print(S().cannotAfford)
        return
    end

    local perCall = StackSizeAt(index)
    local link = GetMerchantItemLink(index)

    DevLog(string.format("Auto-buying %d at merchant index %d, %d per call", quantity, index, perCall))
    Print(string.format(S().buying, quantity, link or ""))

    if link and link:match("currency") then
        -- Currencies have no stacks to break the order into.
        BuyMerchantItem(index, quantity)
    elseif quantity <= perCall then
        -- Fits in one purchase, so hand it to the button's own stack-split
        -- handler and keep the confirmations that buying by hand would raise.
        button.SplitStack(button, quantity)
    else
        QueuePurchase(index, quantity, perCall)
    end
end

-------------------------------------------------------------------------------
-- Buy All at the vendor
-------------------------------------------------------------------------------

--- Everything this vendor sells that is on the list, across every page, with
--- what the gold-priced part of it would cost.
local function NeededPurchases()
    local purchases, goldCost, hasOtherCost = {}, 0, false

    for index = 1, GetMerchantNumItems() do
        local needed = NeededAtMerchantIndex(index)
        if needed > 0 then
            local quantity = PurchaseQuantity(index, needed)
            local info = quantity > 0 and C_MerchantFrame.GetItemInfo(index)
            if info then
                purchases[#purchases + 1] = {
                    index = index,
                    quantity = quantity,
                    perCall = StackSizeAt(index),
                }
                -- Price is per stack, and quantity is always whole stacks.
                goldCost = goldCost + (info.price or 0) * math.floor(quantity / (info.stackCount or 1))
                hasOtherCost = hasOtherCost or info.hasExtendedCost
            end
        end
    end

    return purchases, goldCost, hasOtherCost
end

local function RunPurchases(purchases)
    for _, purchase in ipairs(purchases) do
        QueuePurchase(purchase.index, purchase.quantity, purchase.perCall)
    end
end

StaticPopupDialogs["LUCKYGB_DECOR_BUY_ALL"] = {
    text         = "%s",
    button1      = YES,
    button2      = NO,
    OnAccept     = function(dialog) RunPurchases(dialog.data or {}) end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

local function BuyAllNeeded()
    local purchases, goldCost, hasOtherCost = NeededPurchases()
    if #purchases == 0 then return end

    if goldCost <= BUY_ALL_CONFIRM_COST then
        RunPurchases(purchases)
        return
    end

    local message = string.format(S().buyAllConfirm, #purchases, GetMoneyString(goldCost, true))
    if hasOtherCost then
        message = message .. "\n" .. S().buyAllOtherCost
    end

    local dialog = StaticPopup_Show("LUCKYGB_DECOR_BUY_ALL", message)
    if dialog then dialog.data = purchases end
end

local function AutoBuyEnabled()
    return db.highlightTrackedDecor and db.decorAutoBuy
end

local function AddBuyHintToTooltip(button)
    if not AutoBuyEnabled() or MerchantFrame.selectedTab ~= 1 then return end

    local needed = NeededAtMerchantIndex(button:GetID())
    if needed == 0 then return end

    GameTooltip:AddLine(string.format(S().vendorBuyHint, needed), 0.1, 1, 0.1)
    GameTooltip:Show()
end

local function HookMerchantButtons()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button and not button.lgbAutoBuyHooked then
            button:HookScript("OnClick", function(self, mouseButton)
                local altOnly = IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()
                if mouseButton == "RightButton" and altOnly
                    and AutoBuyEnabled() and MerchantFrame.selectedTab == 1
                then
                    TryAutoBuy(self)
                end
            end)
            button.lgbAutoBuyHooked = true
        end
    end
end

local function CreateBuyAllButton()
    if buyAllButton then return buyAllButton end

    buyAllContainer = CreateFrame("Frame", "LGB_DecorBuyAllParent", UIParent)
    buyAllContainer:SetSize(1, 1)
    buyAllContainer:SetFrameStrata("HIGH")
    LuckyGrabbag.EnableGroupDrag(buyAllContainer, MerchantFrame, "decorBuyAllPos", 5, -50)

    buyAllButton = CreateFrame("Button", "LGB_DecorBuyAllButton", buyAllContainer, "UIPanelButtonTemplate")
    buyAllButton:SetPoint("TOPLEFT", buyAllContainer, "TOPLEFT", 0, 0)
    buyAllButton:SetHeight(24)
    buyAllButton:SetText(S().buyAll)
    buyAllButton:SetWidth(buyAllButton:GetTextWidth() + 26)
    buyAllButton:SetScript("OnClick", BuyAllNeeded)
    buyAllButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().buyAll)
        GameTooltip:AddLine(S().buyAllTooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    buyAllButton:SetScript("OnLeave", GameTooltip_Hide)

    buyAllContainer:RegisterDraggable(buyAllButton)
    buyAllButton:Hide()

    return buyAllButton
end

--- Only worth showing when this vendor actually stocks something on the list.
local function UpdateBuyAllButton()
    local purchases, goldCost = NeededPurchases()
    local wanted = AutoBuyEnabled()
        and MerchantFrame:IsShown()
        and MerchantFrame.selectedTab == 1
        and #purchases > 0

    if not wanted then
        if buyAllButton then buyAllButton:Hide() end
        return
    end

    CreateBuyAllButton()
    -- Everything here may be paid for in currency rather than gold.
    buyAllButton:SetText(goldCost > 0
        and string.format(S().buyAllWithCost, GetMoneyString(goldCost, true))
        or S().buyAll)
    buyAllButton:SetWidth(buyAllButton:GetTextWidth() + 26)
    buyAllContainer:RestorePosition() -- re-anchor, the merchant window may have moved
    buyAllButton:Show()
end

local function ClearMerchantHighlights()
    for i = 1, BUYBACK_ITEM_COUNT do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then SetGlow(button, 0) end
    end
    UpdateBuyAllButton()
end

local function RefreshMerchantHighlights()
    if not db.highlightTrackedDecor or MerchantFrame.selectedTab ~= 1 then
        ClearMerchantHighlights()
        return
    end

    local numItems = GetMerchantNumItems()
    for i = 1, BUYBACK_ITEM_COUNT do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
            local needed = 0
            if i <= MERCHANT_ITEMS_PER_PAGE and index <= numItems then
                needed = NeededAtMerchantIndex(index)
            end
            SetGlow(button, needed)
        end
    end

    UpdateBuyAllButton()
end

-------------------------------------------------------------------------------

--- Everything that reads the list: the window, the vendor glows, the button.
function Feature:Refresh()
    UpdateTrackButton()
    RefreshWindow()
    if MerchantFrame:IsShown() then RefreshMerchantHighlights() end
end

Feature.ApplySetting = Feature.Refresh

function Feature:Init(database)
    db = database
    db.decorList = db.decorList or {}

    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", RefreshMerchantHighlights)
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", ClearMerchantHighlights)
    hooksecurefunc("MerchantItemButton_OnEnter", AddBuyHintToTooltip)
    HookMerchantButtons()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("CONTENT_TRACKING_UPDATE")
    eventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
    eventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_HousingBlueprint" then CreateTrackButton() end
        elseif event == "MERCHANT_CLOSED" then
            UpdateBuyAllButton()
        else
            Feature:Refresh()
        end
    end)

    -- The blueprint UI is load-on-demand, so it may already be up.
    if C_AddOns.IsAddOnLoaded("Blizzard_HousingBlueprint") then
        CreateTrackButton()
    end
end
