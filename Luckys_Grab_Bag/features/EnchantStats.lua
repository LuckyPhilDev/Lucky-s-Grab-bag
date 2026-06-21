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

local function DevLog(msg)
    LuckyGrabbag.DevLog("EnchantStats", msg)
end

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
    MaybeLogUnmapped(itemID, name)

    local short, _, color = Data:Resolve(itemID, name)
    if short then
        local fs = GetBagBadge(button)
        fs:SetText(short)
        fs:SetTextColor(color[1], color[2], color[3])
        fs:Show()
    elseif button.luckyEnchantBadge then
        button.luckyEnchantBadge:Hide()
    end
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
    if db.showEnchantBadges then
        ForEachBagButton(UpdateButton)
    else
        ForEachBagButton(function(button)
            if button.luckyEnchantBadge then button.luckyEnchantBadge:Hide() end
        end)
    end
end

-- Bag frames copy ContainerFrameMixin's methods onto each instance when they're
-- created, so a hook on the mixin table never fires for them. Hook the live
-- frames' own Update instead (the approach maintained bag addons use), falling
-- back to the global updater on clients that still expose it. This is what makes
-- badges appear on bag-open; BAG_UPDATE_DELAYED only fires when contents change.
local function OnContainerUpdate(frame)
    if db.showEnchantBadges then
        ForEachButtonIn(frame, UpdateButton)
    end
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
-- character in FontString text), giving "Haste | Item Name".
local function StatMarkup(label, color)
    return ("|cff%02x%02x%02x%s|r || "):format(
        color[1] * 255, color[2] * 255, color[3] * 255, label)
end

local function HookAHCells()
    if ahHooked then return end
    if not (AuctionHouseTableCellItemDisplayMixin
        and AuctionHouseTableCellItemDisplayMixin.UpdateDisplay) then
        DevLog("AH cell mixin not found")
        return
    end
    ahHooked = true
    hooksecurefunc(AuctionHouseTableCellItemDisplayMixin, "UpdateDisplay", function(cell, itemKey, itemKeyInfo)
        if not (db.showEnchantBadges and db.enchantBadgesAH) then return end
        local itemID = itemKey and itemKey.itemID
        local name = itemKeyInfo and itemKeyInfo.itemName
        MaybeLogUnmapped(itemID, name)
        local _, long, color = Data:Resolve(itemID, name)
        if not (long and cell.Text) then return end
        cell.Text:SetText(StatMarkup(long, color) .. (cell.Text:GetText() or ""))
    end)
    DevLog("AH cells hooked")
end

-- Re-draw the open browse list so a settings change takes effect immediately.
local function RefreshAH()
    local list = AuctionHouseFrame
        and AuctionHouseFrame.BrowseResultsFrame
        and AuctionHouseFrame.BrowseResultsFrame.ItemList
    if list and list:IsShown() and list.RefreshScrollFrame then
        list:RefreshScrollFrame()
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
end

local function RefreshBaganator()
    if baganatorReady and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

function EnchantStats:ApplySetting()
    UpdateAllBags()
    RefreshAH()
    RefreshBaganator()
end

function EnchantStats:Init(database)
    db = database

    HookBagFrames()

    local bagEvents = CreateFrame("Frame")
    bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
    bagEvents:RegisterEvent("ADDON_LOADED")
    bagEvents:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            if name == "Baganator" then RegisterBaganator() end
        else
            UpdateAllBags()
        end
    end)

    RegisterBaganator() -- in case Baganator is already loaded

    -- The Auction House UI is load-on-demand, so hook it the first time it opens.
    local ahEvents = CreateFrame("Frame")
    ahEvents:RegisterEvent("AUCTION_HOUSE_SHOW")
    ahEvents:SetScript("OnEvent", HookAHCells)
end
