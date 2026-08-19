-- Lucky's Grab-bag: Warbound Auto-Deposit
-- When the warband bank opens, deposit warbound armor, weapons, tokens, and whitelisted items.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.WarboundAutoDeposit = {}

local Feature = LuckyGrabbag.WarboundAutoDeposit
local Utils   = LuckyGrabbag.AutoDepositUtils

local db
local popup

local DevLog = LuckyGrabbag.Logger("WarboundAutoDeposit")

-- Lumber sits in classID 7 (Tradeskill) under the catch-all "Other" subclass (11),
-- which holds far more than lumber, so we also require the name to contain "Lumber".
local LUMBER_CLASS_ID   = 7
local LUMBER_NAME_MATCH = "lumber"

-- ---------------------------------------------------------------------------
-- Hand-over to Warband Stockist
-- ---------------------------------------------------------------------------

-- Warbound gear deposit moved to Warband Stockist. A Stockist version that has
-- the feature defines this function; when it is installed, the gear and token
-- rules here stand down and only the whitelist and lumber rules keep running.
-- Older or absent Stockist leaves this addon behaving exactly as before.
local function StockistOwnsWarbound()
    return (WarbandStorage and WarbandStorage.DepositWarboundItems) ~= nil
end

-- One-time copy of the deposit toggles into Stockist's settings, so the
-- feature stays on for users who had it on here. Runs at the bank because
-- both addons are guaranteed fully loaded there. Never overwrites a Stockist
-- config the user already enabled themselves.
local function MigrateSettingsToStockist()
    if db.warboundMovedToStockist or not StockistOwnsWarbound() then return end
    db.warboundMovedToStockist = true

    WarbandStockistDB.warboundDeposit = WarbandStockistDB.warboundDeposit or {}
    local cfg = WarbandStockistDB.warboundDeposit
    if db.warboundAutoDepositEnabled and not cfg.enabled then
        cfg.enabled = true
        cfg.armor   = db.warboundDepositArmor
        cfg.weapons = db.warboundDepositWeapons
        cfg.tokens  = db.warboundDepositTokens
        print(LuckyGrabbag.PREFIX .. " Warbound gear deposit has moved to Warband Stockist. Your settings were carried over; find them on the Warbound tab in Warband Stockist's settings.")
    end
end

-- ---------------------------------------------------------------------------
-- Deposit logic
-- ---------------------------------------------------------------------------

-- An item instance only counts as warbound if it is already bound to the
-- account or is "Warbound until equipped". Unbound BoE copies are neither,
-- even though the bank would accept them.
local function IsInstanceWarbound(bag, slot, info)
    if info.isBound then return true end
    return C_Item.IsBoundToAccountUntilEquip(ItemLocation:CreateFromBagAndSlot(bag, slot))
end

local function DepositWarboundItems()
    -- Lumber is a standalone reagent toggle that runs independently of the
    -- warbound gear/whitelist feature, so either can trigger this pass.
    local warbound = db.warboundAutoDepositEnabled
    if not warbound and not db.warboundDepositLumber then return end

    local anyTypeEnabled = warbound and not StockistOwnsWarbound()
        and (db.warboundDepositArmor or db.warboundDepositWeapons or db.warboundDepositTokens)
    -- itemID → "warbound" (gear/token rules, deposit warbound copies only)
    --        or true (whitelist/lumber, deposit every copy)
    local toDeposit = {}

    -- One pass: find which itemIDs to deposit.
    -- Use C_Bank.IsItemAllowedInBankType for accurate warbound detection (requires an
    -- ItemLocation, so we must scan per-slot rather than using the aggregated inventory).
    for _, bag in ipairs(Utils.GetAllPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not toDeposit[info.itemID] then
                local itemID = info.itemID

                -- Whitelist always wins regardless of type toggles
                if warbound and db.warboundItemWhitelist and db.warboundItemWhitelist[itemID] then
                    toDeposit[itemID] = true
                    DevLog(("Queueing whitelisted itemID %d"):format(itemID))
                elseif anyTypeEnabled or db.warboundDepositLumber then
                    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    -- IsItemAllowedInBankType only means "not soulbound", so grey vendor
                    -- trash passes it. Poor-quality items share classID 15/0 with tier
                    -- tokens, so the type rules must also exclude them; only the explicit
                    -- whitelist above may auto-deposit junk.
                    -- Unbound BoE gear also passes it, so the gear/token rules further
                    -- require the instance to be explicitly warbound.
                    local isWarbound = IsInstanceWarbound(bag, slot, info)
                    local name, _, quality, _, _, _, _, _, _, _, _, classID, subclassID = GetItemInfo(itemID)
                    if quality and quality > Enum.ItemQuality.Poor
                        and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc) then
                        if anyTypeEnabled and isWarbound and db.warboundDepositArmor and classID == 4 then
                            toDeposit[itemID] = "warbound"
                            DevLog(("Queueing warbound armor itemID %d"):format(itemID))
                        elseif anyTypeEnabled and isWarbound and db.warboundDepositWeapons and classID == 2 then
                            toDeposit[itemID] = "warbound"
                            DevLog(("Queueing warbound weapon itemID %d"):format(itemID))
                        elseif anyTypeEnabled and isWarbound and db.warboundDepositTokens and classID == 15 and subclassID == 0 then
                            toDeposit[itemID] = "warbound"
                            DevLog(("Queueing warbound token itemID %d"):format(itemID))
                        elseif db.warboundDepositLumber and classID == LUMBER_CLASS_ID
                            and name and name:lower():find(LUMBER_NAME_MATCH, 1, true) then
                            toDeposit[itemID] = true
                            DevLog(("Queueing lumber itemID %d"):format(itemID))
                        end
                    end
                end
            end
        end
    end

    -- Build queue with full stack counts from inventory. Amounts may overcount
    -- filtered copies; the deposit loop simply runs out of eligible stacks.
    local inventory = Utils.ScanInventory()
    local queue = {}
    for itemID, rule in pairs(toDeposit) do
        local count = inventory[itemID] or 0
        if count > 0 then
            table.insert(queue, {
                itemID = itemID,
                amount = count,
                slotFilter = rule == "warbound" and IsInstanceWarbound or nil,
            })
        end
    end

    if #queue > 0 then
        DevLog(("Depositing %d warbound/whitelisted item type(s)"):format(#queue))
        Utils.ProcessQueue(queue, 1)
    end
end

-- ---------------------------------------------------------------------------
-- Whitelist popup
-- ---------------------------------------------------------------------------

local Rich = LuckySettings.Rich
local R = Rich.Theme
local R_FONT = Rich.Font

local function HandleItemDrop()
    local infoType, itemID = GetCursorInfo()
    if infoType ~= "item" then return end
    ClearCursor()
    if itemID then
        db.warboundItemWhitelist[itemID] = true
        Feature:RefreshPopup()
        DevLog(("Added itemID %d to whitelist via drag"):format(itemID))
    end
end

local function BuildPopup()
    if popup then return popup end

    local f = CreateFrame("Frame", "LuckyGrabbagWarboundWhitelistPopup", UIParent)
    f:SetSize(540, 480)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    Rich.FillBg(f, R.bg)
    table.insert(UISpecialFrames, "LuckyGrabbagWarboundWhitelistPopup")

    -- Title bar (drag handle)
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
        db.warboundWhitelistPopupPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    local titleL = titleBar:CreateFontString(nil, "OVERLAY")
    titleL:SetFont(R_FONT, 16, "")
    titleL:SetPoint("LEFT", 14, 0)
    titleL:SetText("Whitelist")
    titleL:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])

    -- Close button
    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Restore saved position
    local saved = db.warboundWhitelistPopupPos
    f:ClearAllPoints()
    if saved and saved.point then
        f:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Content body
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    body:EnableMouse(true)
    body:SetScript("OnReceiveDrag", HandleItemDrop)
    body:SetScript("OnMouseDown", HandleItemDrop)

    -- Description
    local desc = body:CreateFontString(nil, "OVERLAY")
    desc:SetFont(R_FONT, 12, "")
    desc:SetTextColor(R.text[1], R.text[2], R.text[3])
    desc:SetSpacing(3)
    desc:SetPoint("TOPLEFT", 14, -14)
    desc:SetPoint("TOPRIGHT", -14, -14)
    desc:SetJustifyH("LEFT")
    desc:SetText("Add item links or IDs to always auto-deposit them, or drag an item here from your bags. Right-click to remove.")
    desc:SetWordWrap(true)
    desc:SetHeight(34)

    -- Input row for adding items
    local inputRow = CreateFrame("Frame", nil, body)
    inputRow:SetHeight(28)
    inputRow:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    inputRow:SetPoint("RIGHT", -14, 0)

    local inputLbl = inputRow:CreateFontString(nil, "OVERLAY")
    inputLbl:SetFont(R_FONT, 12, "")
    inputLbl:SetTextColor(R.text[1], R.text[2], R.text[3])
    inputLbl:SetPoint("LEFT", 10, 0)
    inputLbl:SetText("Add:")

    local inputEdit = CreateFrame("EditBox", nil, inputRow, "InputBoxTemplate")
    inputEdit:SetSize(300, 24)
    inputEdit:SetPoint("LEFT", inputLbl, "RIGHT", 10, -2)
    inputEdit:SetAutoFocus(false)
    f.inputEdit = inputEdit

    local addBtn = CreateFrame("Button", nil, inputRow, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22)
    addBtn:SetPoint("LEFT", inputEdit, "RIGHT", 6, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local text = inputEdit:GetText()
        if text == "" then return end

        local itemID
        -- Try to extract itemID from item link (|cffxxxxxx|Hitem:ITEMID:...|h...)
        itemID = tonumber(text:match("|Hitem:(%d+)"))
        -- If that fails, try parsing as plain number
        if not itemID then itemID = tonumber(text) end

        if itemID then
            db.warboundItemWhitelist[itemID] = true
            inputEdit:SetText("")
            Feature:RefreshPopup()
            DevLog(("Added itemID %d to whitelist"):format(itemID))
        else
            print(LuckyGrabbag.PREFIX .. " Could not parse item link or ID.")
        end
    end)
    f.addBtn = addBtn

    -- Whitelist items list
    local headerRow = CreateFrame("Frame", nil, body)
    headerRow:SetHeight(22)
    headerRow:SetPoint("TOPLEFT", inputRow, "BOTTOMLEFT", 0, -10)
    headerRow:SetPoint("RIGHT", -14, 0)
    Rich.FillBg(headerRow, R.bg3)
    Rich.EdgeRule(headerRow, "BOTTOM", R.border)

    local headerText = headerRow:CreateFontString(nil, "OVERLAY")
    headerText:SetFont(R_FONT, 10, "")
    headerText:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
    headerText:SetPoint("LEFT", headerRow, "LEFT", 10, 0)
    headerText:SetText("WHITELISTED ITEMS (right-click to remove)")

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    scroll:SetScript("OnReceiveDrag", HandleItemDrop)
    scroll:SetScript("OnMouseDown", HandleItemDrop)

    local itemParent = CreateFrame("Frame", nil, scroll)
    itemParent:SetSize(480, 1)
    scroll:SetScrollChild(itemParent)
    itemParent:EnableMouse(true)
    itemParent:SetScript("OnReceiveDrag", HandleItemDrop)
    itemParent:SetScript("OnMouseDown", HandleItemDrop)

    f.itemParent = itemParent
    f.items = {}

    popup = f
    return f
end

local function BuildItemRow(parent, itemID, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(480, 26)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    local itemText = link or (name or ("Item " .. itemID))

    -- Icon
    local iconTex = row:CreateTexture(nil, "OVERLAY")
    iconTex:SetSize(24, 24)
    iconTex:SetPoint("LEFT", 10, 0)
    if icon then iconTex:SetTexture(icon) end
    row.icon = iconTex

    -- Item name (clickable)
    local itemLabel = row:CreateFontString(nil, "OVERLAY")
    itemLabel:SetFont(R_FONT, 12, "")
    itemLabel:SetTextColor(R.text[1], R.text[2], R.text[3])
    itemLabel:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
    itemLabel:SetWidth(350)
    itemLabel:SetJustifyH("LEFT")
    itemLabel:SetText(itemText)
    row.label = itemLabel

    row.itemID = itemID

    row:SetScript("OnReceiveDrag", HandleItemDrop)

    return row
end

function Feature:RefreshPopup()
    if not popup then return end

    db.warboundItemWhitelist = db.warboundItemWhitelist or {}

    local existing = popup.items
    local y = -4
    local i = 0

    -- Sort by itemID for consistency
    local sortedIDs = {}
    for itemID in pairs(db.warboundItemWhitelist) do
        table.insert(sortedIDs, itemID)
    end
    table.sort(sortedIDs)

    for _, itemID in ipairs(sortedIDs) do
        i = i + 1
        local row = existing[i]
        if not row then
            row = BuildItemRow(popup.itemParent, itemID, y)
            existing[i] = row
            -- Right-click to remove; any click while holding an item deposits it
            row:SetScript("OnMouseDown", function(self, button)
                if button == "RightButton" then
                    db.warboundItemWhitelist[self.itemID] = nil
                    Feature:RefreshPopup()
                    DevLog(("Removed itemID %d from whitelist"):format(self.itemID))
                else
                    HandleItemDrop()
                end
            end)
        else
            row.itemID = itemID
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", popup.itemParent, "TOPLEFT", 0, y)
            local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
            if row.icon then row.icon:SetTexture(icon or "") end
            if row.label then row.label:SetText(link or name or ("Item " .. itemID)) end
        end
        y = y - 28
    end

    -- Hide leftover rows
    for j = i + 1, #existing do existing[j]:Hide() end

    popup.itemParent:SetHeight(math.max(-y + 8, 1))
end

function Feature:OpenPopup()
    BuildPopup()
    popup:Show()
    self:RefreshPopup()
end

-- ---------------------------------------------------------------------------
-- Diagnostics: identify item classification (used to find new deposit types)
-- ---------------------------------------------------------------------------

-- Scans player bags and prints each item's name, itemID, and class/subclass
-- (both the numeric IDs the deposit logic uses and their localized names).
-- Pass a filter string to only show items whose name contains it, e.g.
--   /grabbag-iteminfo lumber
local function DiagnoseItems(filter)
    filter = filter and filter:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if filter == "" then filter = nil end

    local P = LuckyGrabbag.PREFIX
    print(P .. " Item classification" .. (filter and (" matching '" .. filter .. "'") or " (all bag items)") .. ":")

    local seen = {}
    local shown = 0
    for _, bag in ipairs(Utils.GetAllPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not seen[info.itemID] then
                local name, link, _, _, _, itemType, itemSubType, _, _, _, _, classID, subclassID = GetItemInfo(info.itemID)
                if name and (not filter or name:lower():find(filter, 1, true)) then
                    seen[info.itemID] = true
                    shown = shown + 1
                    print(("  %s |cffaaaaaaid=%d  classID=%s (%s)  subclassID=%s (%s)|r"):format(
                        link or name,
                        info.itemID,
                        tostring(classID), tostring(itemType),
                        tostring(subclassID), tostring(itemSubType)
                    ))
                end
            end
        end
    end

    if shown == 0 then
        print("  |cffff4040No matching items found in your bags.|r"
            .. (filter and " (Item info may not be cached yet; try again.)" or ""))
    end
end

SLASH_LGBITEMINFO1 = "/grabbag-iteminfo"
SLASH_LGBITEMINFO2 = "/gbiteminfo"
SlashCmdList["LGBITEMINFO"] = DiagnoseItems

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function Feature:Init(database)
    db = database
    db.warboundItemWhitelist = db.warboundItemWhitelist or {}

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:SetScript("OnEvent", function()
        DevLog("BANKFRAME_OPENED received")
        MigrateSettingsToStockist()
        C_Timer.After(0.2, DepositWarboundItems)
    end)
end
