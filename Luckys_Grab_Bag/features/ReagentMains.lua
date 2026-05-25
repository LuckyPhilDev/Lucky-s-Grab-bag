-- Lucky's Grab-bag: Reagent Mains
-- When the warband bank opens, deposit reagents whose category is assigned
-- to a different character. Items with no main are deposited by everyone.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ReagentMains = {}

local Feature = LuckyGrabbag.ReagentMains
local Data    = LuckyGrabbag.ReagentMainsData
local Utils   = LuckyGrabbag.AutoDepositUtils

local db
local popup

local function DevLog(msg)
    if LuckyGrabbag.DevLog then LuckyGrabbag.DevLog("ReagentMains", msg) end
end

-- ---------------------------------------------------------------------------
-- Bag scanning + deposit pipeline (delegated to AutoDepositUtils)
-- ---------------------------------------------------------------------------

local function CharKeeps(set, charKey)
    if type(set) ~= "table" then return false end
    if set[Data.ALL_SENTINEL] then return true end
    return set[charKey] == true
end

local function DepositUnmatchedReagents()
    if not db.reagentMainsEnabled then return end

    local charKey = LuckyRoster:GetKey()
    if (db.reagentExcludedAlts or {})[charKey] then
        DevLog("Character is excluded from reagent deposit")
        return
    end
    local mains   = db.reagentMains or {}
    local inventory = Utils.ScanInventory()

    local queue = {}
    for itemID, count in pairs(inventory) do
        local cat = Data:Classify(itemID)
        if cat then
            local expOk = true
            if db.reagentMainsCurrentExpOnly then
                local isCurrent = Data:IsCurrentExpansion(itemID)
                expOk = (isCurrent ~= false)  -- nil (unknown) passes through
            end
            if expOk and not CharKeeps(mains[cat], charKey) then
                DevLog(("Queueing %d of item %d (cat=%s)"):format(count, itemID, cat))
                table.insert(queue, { itemID = itemID, amount = count })
            end
        end
    end

    if #queue > 0 then
        DevLog(("Depositing %d unmatched reagent stack(s)"):format(#queue))
        Utils.ProcessQueue(queue, 1)
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

    local SR = LuckyGrabbag.Strings.reagentMains

    -- Excluded characters row
    local excludedRow = CreateFrame("Frame", nil, body)
    excludedRow:SetHeight(28)
    excludedRow:SetPoint("TOPLEFT", detectBtn, "BOTTOMLEFT", 0, -8)
    excludedRow:SetPoint("RIGHT", -14, 0)

    local excludedLbl = excludedRow:CreateFontString(nil, "OVERLAY")
    excludedLbl:SetFont(R_FONT, 12, "")
    excludedLbl:SetTextColor(R.text[1], R.text[2], R.text[3])
    excludedLbl:SetPoint("LEFT", 10, 0)
    excludedLbl:SetText(SR.excludedLabel)

    local excludedDd = CreateFrame("Frame", nil, excludedRow, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(excludedDd, 180)
    excludedDd:SetPoint("LEFT", excludedRow, "LEFT", 130, 0)
    excludedDd:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SR.excludedTooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    excludedDd:SetScript("OnLeave", GameTooltip_Hide)
    f.excludedDd = excludedDd

    -- Column header
    local headerRow = CreateFrame("Frame", nil, body)
    headerRow:SetHeight(22)
    headerRow:SetPoint("TOPLEFT", excludedRow, "BOTTOMLEFT", 0, -10)
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

    -- Refresh excluded characters dropdown
    db.reagentExcludedAlts = db.reagentExcludedAlts or {}
    local excluded = db.reagentExcludedAlts
    UIDropDownMenu_Initialize(popup.excludedDd, function(_, level)
        for _, ck in ipairs(LuckyRoster:GetKeys()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text             = LuckyRoster:FormatName(ck)
            info.checked          = excluded[ck] == true
            info.keepShownOnClick = true
            info.isNotRadio       = true
            info.func             = function(_, _, _, checked)
                db.reagentExcludedAlts = db.reagentExcludedAlts or {}
                db.reagentExcludedAlts[ck] = checked or nil
                Feature:RefreshPopup()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local excludedKeys = {}
    for ck in pairs(excluded) do table.insert(excludedKeys, ck) end
    local SR = LuckyGrabbag.Strings.reagentMains
    if #excludedKeys == 0 then
        UIDropDownMenu_SetText(popup.excludedDd, SR.ddNone)
    elseif #excludedKeys > 2 then
        UIDropDownMenu_SetText(popup.excludedDd, string.format(SR.ddMultiCharsFmt, #excludedKeys))
    else
        table.sort(excludedKeys)
        local names = {}
        for _, ck in ipairs(excludedKeys) do table.insert(names, ColoredShortName(ck)) end
        UIDropDownMenu_SetText(popup.excludedDd, table.concat(names, ", "))
    end
end

function Feature:OpenPopup()
    BuildPopup()
    popup:Show()
    self:RefreshPopup()
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Diagnostic: /grabbag-reagent <itemID>
-- ---------------------------------------------------------------------------

local SUBCLASS_NAMES = {
    [4]  = "Jewelcrafting",
    [5]  = "Cloth",
    [6]  = "Leather",
    [7]  = "Metal & Stone",
    [8]  = "Cooking",
    [9]  = "Herb",
    [10] = "Elemental",
    [11] = "Other",
    [12] = "Enchanting",
    [13] = "Inscription",
    [14] = "Optional Reagents",
    [15] = "Finishing Reagents",
    [16] = "Optional Reagents (new)",
}

local function CountInBags(itemID)
    local total = 0
    local locations = {}
    for _, bag in ipairs(Utils.GetAllPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                total = total + (info.stackCount or 1)
                table.insert(locations, { bag = bag, slot = slot, count = info.stackCount or 1 })
            end
        end
    end
    return total, locations
end

local function ColorYes(b) return b and "|cff40ff40yes|r" or "|cffff4040no|r" end

local function Diagnose(itemIDStr)
    local itemID = tonumber(itemIDStr)
    if not itemID then
        print(LuckyGrabbag.PREFIX .. " Usage: /grabbag-reagent <itemID>")
        return
    end

    local prefix = LuckyGrabbag.PREFIX .. " |cffffd100Reagent diagnostic|r"
    local name, link, _, _, _, itemType, itemSubType, _, _, _, _, classID, subclassID = GetItemInfo(itemID)

    if classID == nil then
        print(prefix .. ": item " .. itemID .. " not in client cache. Hover the item in your bags then re-run.")
        return
    end

    print(prefix .. " for " .. (link or name or ("item:" .. itemID)))
    local expID = select(15, GetItemInfo(itemID))
    print(("  Type: %s / %s  (classID=%s, subclassID=%s%s)"):format(
        tostring(itemType), tostring(itemSubType), tostring(classID), tostring(subclassID),
        SUBCLASS_NAMES[subclassID] and (" → " .. SUBCLASS_NAMES[subclassID]) or ""
    ))
    print(("  Expansion ID: %s  (current: %s)  Current-exp filter: %s"):format(
        tostring(expID),
        tostring(GetExpansionLevel and GetExpansionLevel() or "?"),
        db.reagentMainsCurrentExpOnly and ColorYes(expID == (GetExpansionLevel and GetExpansionLevel())) or "off"
    ))

    if classID ~= 7 then
        print("  |cffff4040Not a Tradegoods item|r (classID 7 required). Will be ignored by reagent deposit.")
        return
    end

    -- Classify (bypass cache so result is fresh)
    local matchedCat
    for cat, def in pairs(Data.Categories) do
        for _, sc in ipairs(def.subclassIDs) do
            if sc == subclassID then matchedCat = cat; break end
        end
        if matchedCat then break end
    end

    if not matchedCat then
        print(("  |cffff4040No category maps to subclass %s.|r Add %s to ReagentMainsData.Categories to track it."):format(
            tostring(subclassID), tostring(subclassID)
        ))
        return
    end
    print(("  Category: |cffffd100%s|r"):format(matchedCat))

    -- Char keeps?
    local charKey = LuckyRoster and LuckyRoster:GetKey() or "?"
    local set = (db.reagentMains or {})[matchedCat]
    local kept = CharKeeps(set, charKey)
    local setDesc
    if type(set) ~= "table" then
        setDesc = "(no main set — every char keeps these)"
    elseif set[Data.ALL_SENTINEL] then
        setDesc = "ALL chars"
    else
        local keys = {}
        for ck in pairs(set) do table.insert(keys, ck) end
        setDesc = #keys > 0 and table.concat(keys, ", ") or "(empty set)"
    end
    print(("  Mains for %s: %s"):format(matchedCat, setDesc))
    print(("  Current char (%s) keeps this category? %s"):format(charKey, ColorYes(kept)))
    if type(set) ~= "table" then
        print("  |cffff4040No main configured for this category|r → CharKeeps returns false → would never deposit. Set a main in the popup.")
    end

    -- Inventory
    local total, locs = CountInBags(itemID)
    print(("  In bags: %d (in %d stack%s)"):format(total, #locs, #locs == 1 and "" or "s"))
    if total == 0 then
        print("  |cffff4040Nothing to deposit.|r")
    end

    -- Bank-allowed check per stack
    if #locs > 0 then
        local allowedCount, blockedCount = 0, 0
        for _, l in ipairs(locs) do
            local loc = ItemLocation:CreateFromBagAndSlot(l.bag, l.slot)
            local ok = C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc)
            if ok then allowedCount = allowedCount + 1 else blockedCount = blockedCount + 1 end
        end
        print(("  Warband-bank allowed: %d stack(s) yes, %d stack(s) no"):format(allowedCount, blockedCount))
        if blockedCount > 0 then
            print("  |cffff4040Some/all stacks are not allowed in the warband bank|r (e.g. soulbound). Those will be skipped.")
        end
    end

    -- Bank state
    local bankOpen = (BankFrame and BankFrame:IsShown()) or false
    print(("  Warband bank open: %s"):format(ColorYes(bankOpen)))
    if bankOpen then
        local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
        if type(tabIDs) ~= "table" or #tabIDs == 0 then
            print("  |cffff4040No purchased warband bank tabs found.|r")
        else
            local stackBag, stackSlot = Utils.FindStackableBankSlot(itemID)
            local emptyBag, emptySlot = Utils.FindEmptyBankSlot()
            print(("  Stackable bank slot found: %s%s"):format(
                ColorYes(stackBag ~= nil),
                stackBag and (" (bag " .. stackBag .. ", slot " .. stackSlot .. ")") or ""
            ))
            print(("  Empty bank slot found: %s%s"):format(
                ColorYes(emptyBag ~= nil),
                emptyBag and (" (bag " .. emptyBag .. ", slot " .. emptySlot .. ")") or ""
            ))
            if not stackBag and not emptyBag then
                print("  |cffff4040Bank is full and has no stackable slot for this item.|r")
            end
        end
    else
        print("  (Open the warband bank to test slot finding.)")
    end

    -- Feature toggle
    print(("  Feature enabled (db.reagentMainsEnabled): %s"):format(ColorYes(db.reagentMainsEnabled and true or false)))
    local isExcluded = (db.reagentExcludedAlts or {})[charKey] == true
    print(("  Character excluded from all deposits: %s"):format(ColorYes(not isExcluded)))

    -- Final verdict
    local expFilter = db.reagentMainsCurrentExpOnly
        and (expID ~= (GetExpansionLevel and GetExpansionLevel())) or false
    local wouldDeposit = (not kept) and total > 0 and (db.reagentMainsEnabled == true) and not expFilter and not isExcluded
    print(("  → Would auto-deposit on bank open? %s"):format(ColorYes(wouldDeposit)))
end

SLASH_LGBREAGENT1 = "/grabbag-reagent"
SLASH_LGBREAGENT2 = "/gbreagent"
SlashCmdList["LGBREAGENT"] = Diagnose

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
