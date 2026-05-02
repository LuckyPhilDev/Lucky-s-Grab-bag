-- Lucky's Grab-bag: Reagent Mains
-- When the warband bank opens, deposit reagents whose category is assigned
-- to a different character. Items with no main are deposited by everyone.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ReagentMains = {}

local Feature = LuckyGrabbag.ReagentMains
local Data    = LuckyGrabbag.ReagentMainsData

local db
local popup

-- Deposit pacing — same values as Warband Stockist's bank pipeline.
local pickupDelay  = 0.1
local placeDelay   = 0.05
local depositDelay = 0.1
local perItemDelay = 0.25

local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

local function DevLog(msg)
    if LuckyGrabbag.DevLog then LuckyGrabbag.DevLog("ReagentMains", msg) end
end

-- ---------------------------------------------------------------------------
-- Bag scanning + deposit pipeline
-- ---------------------------------------------------------------------------

local function GetAllPlayerBagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do table.insert(ids, bag) end
    local ok = pcall(function() return C_Container.GetContainerNumSlots(REAGENT_BAG) end)
    if ok then
        local slots = C_Container.GetContainerNumSlots(REAGENT_BAG)
        if type(slots) == "number" and slots > 0 then
            table.insert(ids, REAGENT_BAG)
        end
    end
    return ids
end

local function ScanInventory()
    local inventory = {}  -- itemID → total count in player bags
    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                inventory[info.itemID] = (inventory[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return inventory
end

local function FindStackableBankSlot(itemID)
    local function slotMax(bag, slot)
        if ItemLocation and ItemLocation.CreateFromBagAndSlot then
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if loc and C_Item.DoesItemExist(loc) then
                local m = C_Item.GetItemMaxStackSize(loc)
                if m and m > 0 then return m end
            end
        end
        return select(8, C_Item.GetItemInfo(itemID))
    end
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if type(tabIDs) ~= "table" then return nil, nil end
    for _, bagID in ipairs(tabIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID == itemID then
                local maxStack = slotMax(bagID, slot)
                if maxStack and (info.stackCount or 0) < maxStack then
                    return bagID, slot
                end
            end
        end
    end
    return nil, nil
end

local function FindEmptyBankSlot()
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if type(tabIDs) ~= "table" then return nil, nil end
    for _, bankBag in ipairs(tabIDs) do
        local freeSlots = C_Container.GetContainerFreeSlots(bankBag)
        if freeSlots and #freeSlots > 0 then
            return bankBag, freeSlots[1]
        end
    end
    return nil, nil
end

local function TryDepositItem(itemID, amountToDeposit, callback)
    local bagSlots = {}

    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc) then
                    table.insert(bagSlots, { bag = bag, slot = slot, count = info.stackCount })
                end
            end
        end
    end

    local function depositNext(index, remaining)
        if index > #bagSlots or remaining <= 0 then
            if callback then callback() end
            return
        end

        local entry = bagSlots[index]
        local bag, slot, stackCount = entry.bag, entry.slot, entry.count
        local toMove = math.min(stackCount, remaining)

        C_Timer.After(pickupDelay, function()
            ClearCursor()
            local lockInfo = select(3, C_Container.GetContainerItemInfo(bag, slot))
            if lockInfo == true then
                depositNext(index + 1, remaining)
                return
            end

            if toMove < stackCount then
                C_Container.SplitContainerItem(bag, slot, toMove)
                C_Timer.After(placeDelay, function()
                    if GetCursorInfo() ~= "item" then
                        C_Timer.After(perItemDelay, function() depositNext(index + 1, remaining) end)
                        return
                    end
                    local destBag, destSlot = FindStackableBankSlot(itemID)
                    if not destBag then destBag, destSlot = FindEmptyBankSlot() end
                    if destBag and destSlot then
                        C_Container.PickupContainerItem(destBag, destSlot)
                        C_Timer.After(perItemDelay, function() depositNext(index + 1, remaining - toMove) end)
                    else
                        C_Container.PickupContainerItem(bag, slot)
                        C_Timer.After(perItemDelay, function() depositNext(index + 1, remaining) end)
                    end
                end)
            else
                C_Container.PickupContainerItem(bag, slot)
                C_Timer.After(depositDelay, function()
                    local destBag, destSlot = FindStackableBankSlot(itemID)
                    if not destBag then destBag, destSlot = FindEmptyBankSlot() end
                    if destBag and destSlot then
                        C_Container.PickupContainerItem(destBag, destSlot)
                    else
                        ClearCursor()
                    end
                    C_Timer.After(perItemDelay, function() depositNext(index + 1, remaining - toMove) end)
                end)
            end
        end)
    end

    depositNext(1, amountToDeposit)
end

local function ProcessQueue(queue, index)
    if index > #queue then return end
    local entry = queue[index]
    TryDepositItem(entry.itemID, entry.amount, function()
        C_Timer.After(perItemDelay, function() ProcessQueue(queue, index + 1) end)
    end)
end

local function DepositUnmatchedReagents()
    if not db.reagentMainsEnabled then return end

    local charKey = LuckyRoster:GetKey()
    local mains   = db.reagentMains or {}
    local inventory = ScanInventory()

    local queue = {}
    for itemID, count in pairs(inventory) do
        local cat = Data:Classify(itemID)
        if cat then
            local mainChar = mains[cat]
            local allKeep  = (mainChar == Data.ALL_SENTINEL)
            if not allKeep and (mainChar == nil or mainChar ~= charKey) then
                DevLog(("Queueing %d of item %d (cat=%s, main=%s)"):format(
                    count, itemID, cat, tostring(mainChar)))
                table.insert(queue, { itemID = itemID, amount = count })
            end
        end
    end

    if #queue > 0 then
        DevLog(("Depositing %d unmatched reagent stack(s)"):format(#queue))
        ProcessQueue(queue, 1)
    end
end

-- ---------------------------------------------------------------------------
-- One-time import from Warband Stockist
-- ---------------------------------------------------------------------------

local function ImportFromStockist()
    if db.reagentMainsImported then return end
    if type(WarbandStockistDB) ~= "table" then return end

    if type(WarbandStockistDB.reagentMains) == "table" then
        db.reagentMains = db.reagentMains or {}
        for cat, val in pairs(WarbandStockistDB.reagentMains) do
            if db.reagentMains[cat] == nil then
                db.reagentMains[cat] = val
            end
        end
    end

    if WarbandStockistDB.reagentAutoDeposit ~= nil and db.reagentMainsEnabled == false then
        db.reagentMainsEnabled = WarbandStockistDB.reagentAutoDeposit and true or false
    end

    db.reagentMainsImported = true
    DevLog("Imported reagent mains config from Warband Stockist")
end

-- ---------------------------------------------------------------------------
-- Configure popup
-- ---------------------------------------------------------------------------

local function FormatCharShort(charKey)
    if not charKey then return "" end
    local label = LuckyRoster:FormatName(charKey) or charKey
    return label
end

local function BuildPopup()
    if popup then return popup end

    local f = LuckyUI.CreatePanel("LuckyGrabbagReagentMainsPopup", UIParent, 520, 460)
    f:SetFrameStrata("DIALOG")
    LuckyUI.CreateHeader(f, "Reagent Mains")
    f:Hide()

    LuckyUI.EnableDrag(f, {
        db      = db,
        key     = "reagentMainsPopupPos",
        default = { "CENTER", "CENTER", 0, 0 },
    })

    -- Description
    local desc = f:CreateFontString(nil, "OVERLAY")
    desc:SetFont(LuckyUI.BODY_FONT, 11)
    desc:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
    desc:SetPoint("TOPLEFT", 12, -42)
    desc:SetPoint("TOPRIGHT", -12, -42)
    desc:SetJustifyH("LEFT")
    desc:SetText("Choose which character keeps each reagent category. When the warband bank is opened, this character deposits reagents that belong to someone else.")
    desc:SetWordWrap(true)
    desc:SetHeight(32)

    -- Detect button
    local detectBtn = LuckyUI.CreateButton(f, "Detect Professions", 150, 22, "secondary")
    detectBtn:SetPoint("TOPLEFT", 12, -84)
    detectBtn:SetScript("OnClick", function()
        LuckyRoster:Refresh()
        Feature:RefreshPopup()
    end)
    detectBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Re-scan the current character's professions and refresh hints.", 1, 1, 1)
        GameTooltip:Show()
    end)
    detectBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Header row
    local headerRow = CreateFrame("Frame", nil, f)
    headerRow:SetPoint("TOPLEFT", 12, -114)
    headerRow:SetPoint("TOPRIGHT", -12, -114)
    headerRow:SetHeight(20)
    local hbg = headerRow:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(LuckyUI.C.bgInput[1], LuckyUI.C.bgInput[2], LuckyUI.C.bgInput[3], 0.6)

    local function makeHeaderText(parent, text, x)
        local t = parent:CreateFontString(nil, "OVERLAY")
        t:SetFont(LuckyUI.BODY_FONT, 11)
        t:SetTextColor(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3])
        t:SetPoint("LEFT", parent, "LEFT", x, 0)
        t:SetText(text)
        return t
    end
    makeHeaderText(headerRow, "CATEGORY",   8)
    makeHeaderText(headerRow, "MAIN",       130)
    makeHeaderText(headerRow, "PROFESSIONS", 290)

    -- Scroll area for rows
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)

    local rowParent = CreateFrame("Frame", nil, scroll)
    rowParent:SetSize(480, 1)
    scroll:SetScrollChild(rowParent)

    f.rowParent = rowParent
    f.rows = {}

    popup = f
    return f
end

local function BuildRow(parent, catKey, catDef, yOffset, alt)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(480, 30)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    if alt then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, 0.03)
    end

    local catLabel = row:CreateFontString(nil, "OVERLAY")
    catLabel:SetFont(LuckyUI.BODY_FONT, 12)
    catLabel:SetTextColor(LuckyUI.C.textLight[1], LuckyUI.C.textLight[2], LuckyUI.C.textLight[3])
    catLabel:SetPoint("LEFT", row, "LEFT", 8, 0)
    catLabel:SetWidth(110)
    catLabel:SetJustifyH("LEFT")
    catLabel:SetText(catDef.name)

    local hintText = row:CreateFontString(nil, "OVERLAY")
    hintText:SetFont(LuckyUI.BODY_FONT, 11)
    hintText:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
    hintText:SetPoint("LEFT", row, "LEFT", 290, 0)
    hintText:SetWidth(180)
    hintText:SetJustifyH("LEFT")

    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 140)
    dd:SetPoint("LEFT", row, "LEFT", 110, 0)
    row.dropdown = dd
    row.hint     = hintText
    row.catKey   = catKey

    return row
end

local function DropdownDisplay(val)
    if val == nil then return "None" end
    if val == Data.ALL_SENTINEL then return "All" end
    return LuckyRoster:FormatName(val) or val
end

local function RefreshRow(row, suggestions)
    local catKey  = row.catKey
    local mains   = db.reagentMains or {}
    local current = mains[catKey]

    UIDropDownMenu_Initialize(row.dropdown, function(_, level)
        local none = UIDropDownMenu_CreateInfo()
        none.text    = "None"
        none.checked = (current == nil)
        none.func    = function()
            db.reagentMains[catKey] = nil
            Feature:RefreshPopup()
        end
        UIDropDownMenu_AddButton(none, level)

        local all = UIDropDownMenu_CreateInfo()
        all.text    = "All (everyone keeps)"
        all.checked = (current == Data.ALL_SENTINEL)
        all.func    = function()
            db.reagentMains[catKey] = Data.ALL_SENTINEL
            Feature:RefreshPopup()
        end
        UIDropDownMenu_AddButton(all, level)

        for _, ck in ipairs(LuckyRoster:GetKeys()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = LuckyRoster:FormatName(ck)
            info.checked = (current == ck)
            info.func    = function()
                db.reagentMains[catKey] = ck
                Feature:RefreshPopup()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(row.dropdown, DropdownDisplay(current))

    local suggested = suggestions[catKey]
    if suggested then
        local profNames = LuckyRoster:GetProfessionNames(suggested)
        local short = suggested:match("^(.-)%-") or suggested
        if profNames then
            row.hint:SetText(short .. " (" .. profNames .. ")")
        else
            row.hint:SetText(short)
        end
    else
        row.hint:SetText("")
    end
end

function Feature:RefreshPopup()
    if not popup then return end

    db.reagentMains = db.reagentMains or {}
    local suggestions = Data:GetSuggestions()

    -- Build/reuse rows
    local existing = popup.rows
    local y = -4
    local i = 0
    for _, catKey in ipairs(Data.CategoryOrder) do
        i = i + 1
        local row = existing[i]
        if not row then
            row = BuildRow(popup.rowParent, catKey, Data.Categories[catKey], y, (i % 2 == 0))
            existing[i] = row
        else
            row.catKey = catKey
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", popup.rowParent, "TOPLEFT", 0, y)
        end
        RefreshRow(row, suggestions)
        y = y - 32
    end
    -- Hide leftover rows if category list ever shrinks
    for j = i + 1, #existing do existing[j]:Hide() end

    popup.rowParent:SetHeight(-y + 8)
end

function Feature:OpenPopup()
    BuildPopup()
    popup:Show()
    self:RefreshPopup()
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function Feature:Init(database)
    db = database
    db.reagentMains = db.reagentMains or {}

    ImportFromStockist()

    LuckyRoster:RegisterCallback(function() Feature:RefreshPopup() end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:SetScript("OnEvent", function()
        DevLog("BANKFRAME_OPENED received")
        C_Timer.After(0.2, DepositUnmatchedReagents)
    end)
end
