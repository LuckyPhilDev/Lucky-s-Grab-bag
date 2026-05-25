-- Lucky's Grab-bag: Warbound Auto-Deposit
-- When the warband bank opens, deposit warbound armor, weapons, tokens, and whitelisted items.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.WarboundAutoDeposit = {}

local Feature = LuckyGrabbag.WarboundAutoDeposit
local Utils   = LuckyGrabbag.AutoDepositUtils

local db
local popup

local function DevLog(msg)
    if LuckyGrabbag.DevLog then LuckyGrabbag.DevLog("WarboundAutoDeposit", msg) end
end

-- ---------------------------------------------------------------------------
-- Item classification
-- ---------------------------------------------------------------------------

local function IsWarboundArmor(itemID)
    local classID, subclassID, bindType = select(12, GetItemInfo(itemID))
    if classID ~= 4 then return false end  -- 4 = Armor
    if bindType ~= 4 then return false end  -- 4 = Warbound
    return true
end

local function IsWarboundWeapon(itemID)
    local classID, subclassID, bindType = select(12, GetItemInfo(itemID))
    if classID ~= 2 then return false end  -- 2 = Weapon
    if bindType ~= 4 then return false end  -- 4 = Warbound
    return true
end

local function IsWarboundToken(itemID)
    local classID, subclassID = select(12, GetItemInfo(itemID))
    if classID ~= 15 then return false end  -- 15 = Miscellaneous
    if subclassID ~= 0 then return false end  -- subclass 0 = tokens
    return true
end

-- ---------------------------------------------------------------------------
-- Deposit logic
-- ---------------------------------------------------------------------------

local function DepositWarboundItems()
    if not db.warboundAutoDepositEnabled then return end

    local inventory = Utils.ScanInventory()
    local queue = {}

    for itemID, count in pairs(inventory) do
        local shouldDeposit = false

        -- Check warbound category toggles
        if db.warboundDepositArmor and IsWarboundArmor(itemID) then
            shouldDeposit = true
            DevLog(("Queueing %d of armor itemID %d"):format(count, itemID))
        elseif db.warboundDepositWeapons and IsWarboundWeapon(itemID) then
            shouldDeposit = true
            DevLog(("Queueing %d of weapon itemID %d"):format(count, itemID))
        elseif db.warboundDepositTokens and IsWarboundToken(itemID) then
            shouldDeposit = true
            DevLog(("Queueing %d of token itemID %d"):format(count, itemID))
        end

        -- Whitelist override: always deposit if in whitelist
        if db.warboundItemWhitelist and db.warboundItemWhitelist[itemID] then
            shouldDeposit = true
            DevLog(("Queueing %d of whitelisted itemID %d"):format(count, itemID))
        end

        if shouldDeposit then
            table.insert(queue, { itemID = itemID, amount = count })
        end
    end

    if #queue > 0 then
        DevLog(("Depositing %d warbound/whitelisted item stack(s)"):format(#queue))
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

    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
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
-- Init
-- ---------------------------------------------------------------------------

function Feature:Init(database)
    db = database
    db.warboundItemWhitelist = db.warboundItemWhitelist or {}

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:SetScript("OnEvent", function()
        DevLog("BANKFRAME_OPENED received")
        C_Timer.After(0.2, DepositWarboundItems)
    end)
end
