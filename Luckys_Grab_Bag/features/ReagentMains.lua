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

local function CharKeeps(set, charKey)
    if type(set) ~= "table" then return false end
    if set[Data.ALL_SENTINEL] then return true end
    return set[charKey] == true
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
            if not CharKeeps(mains[cat], charKey) then
                DevLog(("Queueing %d of item %d (cat=%s)"):format(count, itemID, cat))
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
            if db.reagentMains[cat] == nil and type(val) == "string" then
                db.reagentMains[cat] = { [val] = true }
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

local Rich = LuckySettings.Rich
local R = Rich.Theme
local R_FONT = Rich.Font

local function BuildPopup()
    if popup then return popup end

    local f = CreateFrame("Frame", "LuckyGrabbagReagentMainsPopup", UIParent)
    f:SetSize(540, 480)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    Rich.FillBg(f, R.bg)
    -- Escape closes
    table.insert(UISpecialFrames, "LuckyGrabbagReagentMainsPopup")

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
        db.reagentMainsPopupPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    local titleL = titleBar:CreateFontString(nil, "OVERLAY")
    titleL:SetFont(R_FONT, 16, "")
    titleL:SetPoint("LEFT", 14, 0)
    titleL:SetText(LuckyGrabbag.Strings.reagentMains.title)
    titleL:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])

    local titleR = titleBar:CreateFontString(nil, "OVERLAY")
    titleR:SetFont(R_FONT, 11, "")
    titleR:SetPoint("RIGHT", -40, 0)
    titleR:SetText(LuckyGrabbag.Strings.reagentMains.subtitle)
    titleR:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])

    -- Close button
    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Restore saved position
    local saved = db.reagentMainsPopupPos
    f:ClearAllPoints()
    if saved and saved.point then
        f:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Content body inset
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Description
    local desc = body:CreateFontString(nil, "OVERLAY")
    desc:SetFont(R_FONT, 12, "")
    desc:SetTextColor(R.text[1], R.text[2], R.text[3])
    desc:SetSpacing(3)
    desc:SetPoint("TOPLEFT", 14, -14)
    desc:SetPoint("TOPRIGHT", -14, -14)
    desc:SetJustifyH("LEFT")
    desc:SetText(LuckyGrabbag.Strings.reagentMains.description)
    desc:SetWordWrap(true)
    desc:SetHeight(34)

    -- Detect button
    local detectBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    detectBtn:SetSize(150, 22)
    detectBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    detectBtn:SetText(LuckyGrabbag.Strings.reagentMains.detectButton)
    detectBtn:SetScript("OnClick", function()
        LuckyRoster:Refresh()
        Feature:RefreshPopup()
    end)
    detectBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(LuckyGrabbag.Strings.reagentMains.detectTooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    detectBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Column header
    local headerRow = CreateFrame("Frame", nil, body)
    headerRow:SetHeight(22)
    headerRow:SetPoint("TOPLEFT", detectBtn, "BOTTOMLEFT", 0, -14)
    headerRow:SetPoint("RIGHT", -14, 0)
    Rich.FillBg(headerRow, R.bg3)
    Rich.EdgeRule(headerRow, "BOTTOM", R.border)

    local function makeHeaderText(parent, text, x)
        local t = parent:CreateFontString(nil, "OVERLAY")
        t:SetFont(R_FONT, 10, "")
        t:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])
        t:SetPoint("LEFT", parent, "LEFT", x, 0)
        t:SetText(string.upper(text))
        return t
    end
    local SR = LuckyGrabbag.Strings.reagentMains
    makeHeaderText(headerRow, SR.headerCategory,    10)
    makeHeaderText(headerRow, SR.headerMain,        140)
    makeHeaderText(headerRow, SR.headerProfessions, 310)

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
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
        bg:SetColorTexture(R.bg2[1], R.bg2[2], R.bg2[3], 0.5)
    end

    local catLabel = row:CreateFontString(nil, "OVERLAY")
    catLabel:SetFont(R_FONT, 12, "")
    catLabel:SetTextColor(R.text[1], R.text[2], R.text[3])
    catLabel:SetPoint("LEFT", row, "LEFT", 10, 0)
    catLabel:SetWidth(120)
    catLabel:SetJustifyH("LEFT")
    catLabel:SetText(LuckyGrabbag.Strings.reagentCategories[catKey] or catKey)

    local hintText = row:CreateFontString(nil, "OVERLAY")
    hintText:SetFont(R_FONT, 11, "")
    hintText:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    hintText:SetPoint("LEFT", row, "LEFT", 310, 0)
    hintText:SetWidth(160)
    hintText:SetJustifyH("LEFT")

    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 150)
    dd:SetPoint("LEFT", row, "LEFT", 120, 0)
    row.dropdown = dd
    row.hint     = hintText
    row.catKey   = catKey

    return row
end

local function ShortName(charKey)
    return charKey:match("^(.-)%-") or charKey
end

local function ColoredShortName(charKey)
    local short = ShortName(charKey)
    local class = LuckyRoster:GetClass(charKey)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, short)
    end
    return short
end

local function DropdownDisplay(set)
    local SR = LuckyGrabbag.Strings.reagentMains
    if type(set) ~= "table" then return SR.ddNone end
    if set[Data.ALL_SENTINEL] then return SR.ddAllShort end
    local keys = {}
    for ck in pairs(set) do table.insert(keys, ck) end
    if #keys == 0 then return SR.ddNone end
    table.sort(keys)
    if #keys > 3 then
        return string.format(SR.ddMultiCharsFmt, #keys)
    end
    local names = {}
    for _, ck in ipairs(keys) do table.insert(names, ColoredShortName(ck)) end
    return table.concat(names, ", ")
end

local function GetOrCreateSet(catKey)
    db.reagentMains[catKey] = db.reagentMains[catKey] or {}
    if type(db.reagentMains[catKey]) ~= "table" then
        db.reagentMains[catKey] = {}
    end
    return db.reagentMains[catKey]
end

local function SetEmpty(set)
    if type(set) ~= "table" then return true end
    return next(set) == nil
end

local function RefreshRow(row, suggestions)
    local catKey  = row.catKey
    local mains   = db.reagentMains or {}
    local current = mains[catKey]

    UIDropDownMenu_Initialize(row.dropdown, function(_, level)
        local set      = type(current) == "table" and current or nil
        local hasAll   = set and set[Data.ALL_SENTINEL] or false
        local isEmpty  = SetEmpty(set)

        local SR = LuckyGrabbag.Strings.reagentMains
        local none = UIDropDownMenu_CreateInfo()
        none.text                  = SR.ddNone
        none.checked               = isEmpty
        none.keepShownOnClick      = false
        none.notCheckable          = false
        none.func                  = function()
            db.reagentMains[catKey] = nil
            Feature:RefreshPopup()
        end
        UIDropDownMenu_AddButton(none, level)

        local all = UIDropDownMenu_CreateInfo()
        all.text                   = SR.ddAllOption
        all.checked                = hasAll
        all.keepShownOnClick       = false
        all.func                   = function()
            db.reagentMains[catKey] = { [Data.ALL_SENTINEL] = true }
            Feature:RefreshPopup()
        end
        UIDropDownMenu_AddButton(all, level)

        for _, ck in ipairs(LuckyRoster:GetKeys()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text             = LuckyRoster:FormatName(ck)
            info.checked          = set and set[ck] == true or false
            info.keepShownOnClick = true
            info.isNotRadio       = true
            info.func             = function(_, _, _, checked)
                local s = GetOrCreateSet(catKey)
                s[Data.ALL_SENTINEL] = nil  -- selecting individuals clears "All"
                s[ck] = checked or nil
                if SetEmpty(s) then db.reagentMains[catKey] = nil end
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

    -- Migrate legacy single-value entries → multi-select set table.
    for cat, val in pairs(db.reagentMains) do
        if type(val) == "string" then
            db.reagentMains[cat] = { [val] = true }
        end
    end

    ImportFromStockist()

    LuckyRoster:RegisterCallback(function() Feature:RefreshPopup() end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:SetScript("OnEvent", function()
        DevLog("BANKFRAME_OPENED received")
        C_Timer.After(0.2, DepositUnmatchedReagents)
    end)
end
