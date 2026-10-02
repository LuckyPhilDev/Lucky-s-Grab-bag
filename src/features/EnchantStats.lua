-- Lucky's Grab-bag: Enchant stat badges
--
-- Overlays a short code on enchant items so they're easy to tell apart at a
-- glance: secondary stats H, C, M, V; tertiaries Sp, Le, Av; primary stats
-- Str, Agi, Int (A/S for armor kits, Pri for any-primary); and weapon procs
-- with no stat (Shi shield, Heal, DoT). A "+" suffix marks the pricier
-- higher-stat version of a secondary-stat enchant. Two surfaces:
--   * Bags  - a corner badge on the item button.
--   * Auction House - a coloured tag in the browse-results list.
-- The enchant → code data lives in EnchantStatsData.lua.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.EnchantStats = {}

local EnchantStats = LuckyGrabbag.EnchantStats
local Data = LuckyGrabbag.EnchantStatsData
local db

local DevLog = LuckyGrabbag.Logger("EnchantStats")

-- Dev-mode helper: report enchants we don't recognise so the data table can be
-- extended in a later patch. Each itemID is logged at most once per session.
local logged = {}

-- Enchant items are named "Enchant <slot> - X" or, for leg enchants, end in
-- "Spellthread" / "Armor Kit".
local function IsEnchantName(name)
    return name and (name:find("^Enchant ")
        or name:find("Spellthread$") or name:find("Armor Kit$"))
end

local function MaybeLogUnmapped(itemID, name)
    if not (db and db.devMode) then return end
    if not itemID or logged[itemID] then return end
    name = name or C_Item.GetItemNameByID(itemID)
    if not IsEnchantName(name) then return end
    local key = Data:KeyFor(name)
    if Data.byName[key] or Data.ignoreNames[key] then return end
    logged[itemID] = true
    DevLog(("Unmapped enchant: [%d] %s"):format(itemID, name))
end

-- ---------------------------------------------------------------------------
-- Bag badges
-- ---------------------------------------------------------------------------

local function GetBagBadge(button)
    if button.luckyEnchantBadge then return button.luckyEnchantBadge end
    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
    fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    fs:SetDrawLayer("OVERLAY", 7)
    button.luckyEnchantBadge = fs
    return fs
end

local SLOT_ICON_SIZE = 18

local function GetSlotIcon(button)
    if button.luckyEnchantSlot then return button.luckyEnchantSlot end
    local icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(SLOT_ICON_SIZE, SLOT_ICON_SIZE)
    icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    button.luckyEnchantSlot = icon
    return icon
end

local function HideBadges(button)
    if button.luckyEnchantBadge then button.luckyEnchantBadge:Hide() end
    if button.luckyEnchantSlot then button.luckyEnchantSlot:Hide() end
end

local function ShowBadges(button, itemID, name)
    MaybeLogUnmapped(itemID, name)
    HideBadges(button)

    local short, _, color
    if db.showEnchantBadges then
        short, _, color = Data:Resolve(itemID, name)
    end
    if short then
        local fs = GetBagBadge(button)
        fs:SetText(short)
        fs:SetTextColor(color[1], color[2], color[3])
        fs:Show()
    end

    local slotTexture = db.showEnchantSlotIcons and Data:SlotIcon(itemID, name)
    if slotTexture then
        local icon = GetSlotIcon(button)
        icon:SetTexture(slotTexture)
        icon:Show()
    end
end

-- Combined-bags buttons carry their own bagID; separate per-bag buttons take it
-- from their parent ContainerFrame's id. GetBagID() isn't reliable on every
-- button, so derive it the way maintained bag addons do.
local function UpdateButton(button)
    local bag = button.bagID
    if bag == nil and button.GetBagID then bag = button:GetBagID() end
    if bag == nil then
        local parent = button.GetParent and button:GetParent()
        bag = parent and parent.GetID and parent:GetID()
    end
    local slot = button.GetID and button:GetID()
    if bag == nil or slot == nil then return end

    local info = C_Container.GetContainerItemInfo(bag, slot)
    local itemID = info and info.itemID
    local name = info and info.hyperlink and info.hyperlink:match("%[(.-)%]")
    ShowBadges(button, itemID, name)
end

-- The combined-bags frame keeps its item buttons in an Items array, but the
-- separate per-bag frames (Combine Bags off) don't have one; their buttons
-- are named globals instead ("ContainerFrame1Item1", "ContainerFrame1Item2", ...).
local function ForEachButtonIn(frame, fn)
    if not frame then return end
    if frame.Items then
        for _, button in ipairs(frame.Items) do
            fn(button)
        end
        return
    end
    local name = frame.GetName and frame:GetName()
    if not name then return end
    local i = 1
    local button = _G[name .. "Item" .. i]
    while button do
        fn(button)
        i = i + 1
        button = _G[name .. "Item" .. i]
    end
end

local function ForEachBagButton(fn)
    ForEachButtonIn(ContainerFrameCombinedBags, fn)
    for i = 1, 13 do
        ForEachButtonIn(_G["ContainerFrame" .. i], fn)
    end
end

local function UpdateAllBags()
    ForEachBagButton(UpdateButton)
end

-- Bag frames copy ContainerFrameMixin's methods onto each instance when they're
-- created, so a hook on the mixin table never fires for them. Hook the live
-- frames' own Update instead (the approach maintained bag addons use), falling
-- back to the global updater on clients that still expose it. This is what makes
-- badges appear on bag-open; BAG_UPDATE_DELAYED only fires when contents change.
local function OnContainerUpdate(frame)
    ForEachButtonIn(frame, UpdateButton)
end

local function HookBagFrames()
    if _G.ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", OnContainerUpdate)
        return
    end
    local function hook(frame)
        if frame and frame.Update then
            hooksecurefunc(frame, "Update", OnContainerUpdate)
        end
    end
    hook(ContainerFrameCombinedBags)
    for i = 1, 13 do hook(_G["ContainerFrame" .. i]) end
end

-- ---------------------------------------------------------------------------
-- Auction House
--
-- The browse-results list draws each item name through the shared cell mixin
-- AuctionHouseTableCellItemDisplayMixin:UpdateDisplay. Hooking it lets us
-- prefix the name with a coloured stat code, so the rewritten name appears on
-- first draw, on scroll (rows are recycled through the same call) and whenever
-- results refresh. The mixin lives in the load-on-demand AH UI, so we hook it
-- the first time the Auction House opens.
-- ---------------------------------------------------------------------------

local ahHooked = false

-- The trailing "||" renders as a single literal "|" (WoW's escape for a pipe
-- character in FontString text), giving "Haste | Item Name". Paired labels
-- (missives, gems) arrive already coloured per-stat, so they only need the
-- separator; single-stat labels are wrapped in their stat colour here.
local function StatMarkup(label, color)
    if label:find("|c", 1, true) then
        return label .. " || "
    end
    return ("|cff%02x%02x%02x%s|r || "):format(
        color[1] * 255, color[2] * 255, color[3] * 255, label)
end

function EnchantStats.WithoutQualityIcon(text, icon)
    if not icon or icon == "" then return text, false end
    local from, to = text:find(" " .. icon, 1, true)
    if not from then return text, false end
    return text:sub(1, from - 1) .. text:sub(to + 1), true
end

local QUALITY_LEAD_WIDTH = 20
-- Reserves room at the start of the name; the icon itself is drawn over it, so
-- every icon starts at the same place whatever the text beside it does.
local QUALITY_LEAD = ("|TInterface\\Common\\spacer:14:%d|t"):format(QUALITY_LEAD_WIDTH)

-- Anything else put at the start of a name belongs after the quality icon.
-- Returns the lead to keep in front, the rest of the text, and the lead's width.
function EnchantStats.QualityLead(cell, text)
    if cell.luckyQualitySide == "left" and text:sub(1, #QUALITY_LEAD) == QUALITY_LEAD then
        return QUALITY_LEAD, text:sub(#QUALITY_LEAD + 1), QUALITY_LEAD_WIDTH
    end
    return "", text, 0
end

local function LeftQualityIcon(cell)
    if not cell.luckyQualityLeft then
        cell.luckyQualityLeft = cell:CreateFontString(nil, "ARTWORK", "Number14FontWhite")
        cell.luckyQualityLeft:SetPoint("LEFT", cell.Text, "LEFT")
    end
    return cell.luckyQualityLeft
end

-- ExtraInfo is Blizzard's slot at the cell's right edge for the quality icon,
-- which it only shows once the name truncates.
local function PlaceQualityIcon(cell)
    if cell.luckyQualitySide == "right" then
        cell.Text:SetPoint("RIGHT", cell.ExtraInfo, "LEFT")
        cell.ExtraInfo:Show()
    elseif cell.luckyQualitySide == "left" then
        cell.Text:SetPoint("RIGHT", cell, "RIGHT", 1, 0)
        cell.ExtraInfo:Hide()
    end
end

local function ResetQualityIcon(cell)
    if cell.luckyQualityLeft then cell.luckyQualityLeft:Hide() end
    if not cell.luckyQualitySide then return end
    cell.luckyQualitySide = nil
    cell.Text:SetPoint("RIGHT", cell, "RIGHT", 1, 0)
    cell:HandleItemNameTruncation()
end

local function BrowseList()
    return AuctionHouseFrame
        and AuctionHouseFrame.BrowseResultsFrame
        and AuctionHouseFrame.BrowseResultsFrame.ItemList
end

-- Rebuilds the columns too, since the price column's width depends on the setting.
local function RefreshAH()
    local list = BrowseList()
    if not (list and list.tableBuilder and list.tableBuilderLayoutFunction) then return end
    list.tableBuilderLayoutDirty = true
    if list:IsShown() then
        list:UpdateTableBuilderLayout()
        list:RefreshScrollFrame()
    end
end

local PRICE_COLUMN_TRIM = 30

local priceColumnHooked = false

-- The table builder only exists once the browse list has been shown.
local function HookPriceColumn()
    if priceColumnHooked then return end
    local list = BrowseList()
    if not (list and list.tableBuilder) then return end
    priceColumnHooked = true
    hooksecurefunc(list.tableBuilder, "AddFixedWidthColumn", function(builder, _, padding, width, _, _, _, cellTemplate)
        if cellTemplate ~= "AuctionHouseTableCellMinPriceTemplate" then return end
        if db.ahQualityIcons == "off" then return end
        local columns = builder:GetColumns()
        columns[#columns]:SetFixedConstraints(width - PRICE_COLUMN_TRIM, padding)
    end)
    RefreshAH()
end

local function HookAHCells()
    if ahHooked then return end
    if not (AuctionHouseTableCellItemDisplayMixin
        and AuctionHouseTableCellItemDisplayMixin.UpdateDisplay) then
        DevLog("AH cell mixin not found")
        return
    end
    ahHooked = true
    hooksecurefunc(AuctionHouseTableCellItemDisplayMixin, "HandleItemNameTruncation", PlaceQualityIcon)
    hooksecurefunc(AuctionHouseTableCellItemDisplayMixin, "UpdateDisplay", function(cell, itemKey, itemKeyInfo)
        ResetQualityIcon(cell)
        if not cell.Text then return end
        local text = cell.Text:GetText() or ""

        -- Owned-auction cells carry a Prefix and rewrite Text and ExtraInfo straight after this.
        local side = db.ahQualityIcons
        local icon, found = cell.ExtraInfo:GetText(), false
        if side ~= "off" and not cell.Prefix then
            text, found = EnchantStats.WithoutQualityIcon(text, icon)
        end

        if db.showEnchantBadges and db.enchantBadgesAH then
            local itemID = itemKey and itemKey.itemID
            local name = itemKeyInfo and itemKeyInfo.itemName
            MaybeLogUnmapped(itemID, name)
            local _, long, color = Data:Resolve(itemID, name)
            if long then text = StatMarkup(long, color) .. text end
        end

        if found then
            cell.luckyQualitySide = side
            if side == "left" then
                text = QUALITY_LEAD .. text
                local left = LeftQualityIcon(cell)
                left:SetText(icon)
                left:Show()
            end
        end

        cell.Text:SetText(text)
        PlaceQualityIcon(cell)
    end)
    DevLog("AH cells hooked")
end

-- ---------------------------------------------------------------------------
-- Auctionator (third-party Shopping tab)
--
-- Auctionator draws its own results list, so the Blizzard cell hook never fires
-- there. Its name column is an item-key cell whose Populate sets the name text;
-- hook it the same way to prefix the coloured stat code. Rows are recycled
-- through Populate on scroll and refresh, so the tag stays in place.
--
-- The cells are built by a TableBuilder that copies the mixin's methods onto
-- each cell instance when it creates it. A hook applied after those cells exist
-- never reaches them, so hook the mixin at Auctionator's load, before the
-- Auction House UI ever builds its table.
-- ---------------------------------------------------------------------------

local auctionatorHooked = false

local function HookAuctionator()
    if auctionatorHooked then return end
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Auctionator")) then
        return  -- Auctionator not present; nothing to do
    end
    if not AuctionatorItemKeyCellTemplateMixin then
        DevLog("Auctionator loaded but item-key mixin not defined yet")
        return
    end
    if not AuctionatorItemKeyCellTemplateMixin.Populate then
        DevLog("Auctionator item-key mixin has no Populate")
        return
    end
    auctionatorHooked = true
    hooksecurefunc(AuctionatorItemKeyCellTemplateMixin, "Populate", function(cell, rowData)
        if not (db.showEnchantBadges and db.enchantBadgesAH) then return end
        local itemID = rowData.itemKey and rowData.itemKey.itemID
        local name = rowData.itemName or (rowData.itemLink and rowData.itemLink:match("%[(.-)%]"))
        MaybeLogUnmapped(itemID, name)
        local _, long, color = Data:Resolve(itemID, name)
        if not (long and cell.Text) then return end
        cell.Text:SetText(StatMarkup(long, color) .. (cell.Text:GetText() or ""))
    end)
    DevLog("Auctionator cells hooked")

    -- The Selling tab's bag buttons, and the big icon of the item being posted.
    if AuctionatorGroupsViewItemMixin and AuctionatorGroupsViewItemMixin.SetItemInfo then
        hooksecurefunc(AuctionatorGroupsViewItemMixin, "SetItemInfo", function(button, info)
            if info then
                ShowBadges(button, info.itemID, info.itemName)
            else
                HideBadges(button)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Baganator (third-party bags)
--
-- Baganator hides the default bags and draws its own, so the ContainerFrame
-- hook never fires for it. Register a corner widget through its public API
-- instead; Baganator calls onUpdate for each item button on its own refreshes.
-- ---------------------------------------------------------------------------

local baganatorReady = false

local function RegisterBaganator()
    if baganatorReady then return end
    if not (Baganator and Baganator.API and Baganator.API.RegisterCornerWidget) then return end
    baganatorReady = true

    Baganator.API.RegisterCornerWidget(
        "Enchant stat badge", "luckygrabbag_enchant_badge",
        function(widget, details)
            local itemID = details and details.itemID
            local name = details and details.itemLink and details.itemLink:match("%[(.-)%]")
            MaybeLogUnmapped(itemID, name)
            if not db.showEnchantBadges then return false end
            local short, _, color = Data:Resolve(itemID, name)
            if not short then return false end
            widget:SetText(short)
            widget:SetTextColor(color[1], color[2], color[3])
            return true
        end,
        function(itemButton)
            local text = itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
            text.sizeFont = true
            return text
        end,
        { corner = "bottom_left", priority = 1 }
    )

    Baganator.API.RegisterCornerWidget(
        "Enchant slot icon", "luckygrabbag_enchant_slot",
        function(widget, details)
            if not db.showEnchantSlotIcons then return false end
            local name = details and details.itemLink and details.itemLink:match("%[(.-)%]")
            local slotTexture = Data:SlotIcon(details and details.itemID, name)
            if not slotTexture then return false end
            widget:SetTexture(slotTexture)
            return true
        end,
        function(itemButton)
            local icon = itemButton:CreateTexture(nil, "OVERLAY")
            icon:SetSize(SLOT_ICON_SIZE, SLOT_ICON_SIZE)
            return icon
        end,
        { corner = "top_right", priority = 1 }
    )
end

local function RefreshBaganator()
    if baganatorReady and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

local PREVIEW_ITEMS = {
    { id = 244015, name = "Enchant Ring - Silvermoon's Alacrity",    count = 3 },
    { id = 245786, name = "Thalassian Missive of the Fireflash",     count = 12 },
    { id = 240857, name = "Deadly Peridot",                          count = 1 },
}
local PREVIEW_BUTTON_SIZE = 37
local PREVIEW_BUTTON_GAP = 6
local PREVIEW_INSET = 14

local previewButtons = {}

local function UpdatePreview()
    for i, button in ipairs(previewButtons) do
        ShowBadges(button, nil, PREVIEW_ITEMS[i].name)
    end
end

function EnchantStats:PreviewHeight()
    return PREVIEW_BUTTON_SIZE + 2 * PREVIEW_BUTTON_GAP
end

function EnchantStats:BuildPreview(parent, caption)
    local step = PREVIEW_BUTTON_SIZE + PREVIEW_BUTTON_GAP
    for i, item in ipairs(PREVIEW_ITEMS) do
        -- A real item button draws the icon, rarity border and quality icon itself.
        local button = CreateFrame("ItemButton", nil, parent)
        button:SetPoint("TOPLEFT", PREVIEW_INSET + (i - 1) * step, -PREVIEW_BUTTON_GAP)
        button:EnableMouse(false)
        button:SetItem(item.id)
        SetItemButtonCount(button, item.count)
        previewButtons[i] = button
    end
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetPoint("LEFT", previewButtons[#previewButtons], "RIGHT", 2 * PREVIEW_BUTTON_GAP, 0)
    label:SetText(caption)
    if db then UpdatePreview() end
end

function EnchantStats:ApplySetting()
    UpdateAllBags()
    UpdatePreview()
    RefreshAH()
    RefreshBaganator()
end

function EnchantStats:Init(database)
    db = database

    UpdatePreview()
    HookBagFrames()

    local bagEvents = CreateFrame("Frame")
    bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
    bagEvents:RegisterEvent("ADDON_LOADED")
    bagEvents:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            if name == "Baganator" then RegisterBaganator() end
            if name == "Auctionator" then HookAuctionator() end
        else
            UpdateAllBags()
        end
    end)

    RegisterBaganator()  -- in case Baganator is already loaded
    HookAuctionator()    -- in case Auctionator is already loaded

    -- The Auction House UI is load-on-demand, so hook it the first time it opens.
    -- Retry the Auctionator hook here too: by the time the AH is open Auctionator
    -- is fully loaded, covering any load-order case the ADDON_LOADED path missed.
    local ahEvents = CreateFrame("Frame")
    ahEvents:RegisterEvent("AUCTION_HOUSE_SHOW")
    ahEvents:SetScript("OnEvent", function()
        HookAHCells()
        HookPriceColumn()
        HookAuctionator()
    end)
end
