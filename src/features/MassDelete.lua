-- Lucky's Grab-bag: Delete a picked list of bag items in one run.
-- Blizzard limits DeleteCursorItem to one deletion per hardware event
-- (since 9.1.5), so the Delete button consumes one click per queued item
-- rather than looping the whole list from a single click.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.MassDelete = {}

local DELETE_POPUPS = {
    DELETE_ITEM            = true,
    DELETE_GOOD_ITEM       = true,
    DELETE_QUEST_ITEM      = true,
    DELETE_GOOD_QUEST_ITEM = true,
}

-- Extra height added to the delete popup so the Mass Delete button fits
-- inside it, centered beneath the stock buttons.
local POPUP_EXTRA = 32

local PANEL_WIDTH = 260
local TITLE_H     = 30
local HINT_H      = 34
local ROW_H       = 22
local FOOTER_H    = 44
local MAX_ROWS    = 12
local LAST_BAG    = 5 -- backpack, four bags, reagent bag

local Rich   = LuckySettings.Rich
local R      = Rich.Theme
local R_FONT = Rich.Font

local db
local panel, overflowText, deleteButton, openButton
local rows = {}
local queue = {} -- array of { bag, slot, link, icon, count }
local active, deleting, anchored = false, false, false
local bottomPinned = false
local deletedCount = 0

local function S() return LuckyGrabbag.Strings.massDelete end

local function DevLog(msg)
    LuckyGrabbag.DevLog("MassDelete", msg)
end

local function Say(msg)
    print(LuckyGrabbag.PREFIX .. " " .. msg)
end

-------------------------------------------------------------------------------
-- The queue
-------------------------------------------------------------------------------

local function IndexOf(bag, slot)
    for i, entry in ipairs(queue) do
        if entry.bag == bag and entry.slot == slot then return i end
    end
end

local function FindByLink(link, lockedOnly)
    if not link then return end
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink == link and (not lockedOnly or info.isLocked) then
                return bag, slot
            end
        end
    end
end

local function Add(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.hyperlink then return end
    table.insert(queue, {
        bag   = bag,
        slot  = slot,
        link  = info.hyperlink,
        icon  = info.iconFileID,
        count = info.stackCount or 1,
    })
    DevLog("Queued " .. info.hyperlink .. " (" .. bag .. "/" .. slot .. ")")
end

-------------------------------------------------------------------------------
-- The panel
-------------------------------------------------------------------------------

local Refresh

-- Re-anchor by the bottom edge at the current spot: height changes then move
-- the top edge only, which keeps the Delete button still under the cursor.
local function PinBottom()
    local left, bottom = panel:GetLeft(), panel:GetBottom()
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

local function BuildRow(index)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_WIDTH - 20, ROW_H)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -(TITLE_H + HINT_H + (index - 1) * ROW_H))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT")

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont(R_FONT, 11, "")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        table.remove(queue, self.index)
        Refresh()
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

local function BuildPanel()
    if panel then return end

    panel = CreateFrame("Frame", "LGB_MassDeletePanel", UIParent)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:Hide()
    Rich.FillBg(panel, R.bg)
    table.insert(UISpecialFrames, "LGB_MassDeletePanel")

    -- Escape or the close button lands here; a finished run has already
    -- cleared `active`, so this only tidies up an abandoned session.
    panel:SetScript("OnHide", function()
        if not active then return end
        active = false
        wipe(queue)
        DevLog("Cancelled")
    end)

    local titleBar = CreateFrame("Frame", nil, panel)
    titleBar:SetHeight(TITLE_H)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    Rich.FillBg(titleBar, R.bg2)
    Rich.EdgeRule(titleBar, "BOTTOM", R.border)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() panel:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        -- A drag is a deliberate placement: stop chasing the bag window and
        -- grow from wherever the bottom edge landed.
        anchored = true
        bottomPinned = true
        PinBottom()
    end)

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(R_FONT, 13, "")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(S().title)
    title:SetTextColor(R.accentLight[1], R.accentLight[2], R.accentLight[3])

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -2, 0)
    close:SetScript("OnClick", function() panel:Hide() end)

    local hint = panel:CreateFontString(nil, "OVERLAY")
    hint:SetFont(R_FONT, 11, "")
    hint:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    hint:SetPoint("TOPLEFT", 10, -(TITLE_H + 6))
    hint:SetPoint("TOPRIGHT", -10, -(TITLE_H + 6))
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(S().hint)

    overflowText = panel:CreateFontString(nil, "OVERLAY")
    overflowText:SetFont(R_FONT, 11, "")
    overflowText:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
    overflowText:SetJustifyH("LEFT")

    deleteButton = CreateFrame("Button", "LGB_MassDeleteButton", panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(PANEL_WIDTH - 24, 24)
    deleteButton:SetPoint("BOTTOM", 0, 10)
    deleteButton:SetScript("OnClick", function() LuckyGrabbag.MassDelete:DeleteNext() end)
    -- Every wheel notch is its own hardware event, so spinning the wheel over
    -- the button is the fastest deletion the client permits. The wheel is
    -- deliberately not on the panel: over the list it reads as scrolling.
    deleteButton:EnableMouseWheel(true)
    deleteButton:SetScript("OnMouseWheel", function() LuckyGrabbag.MassDelete:DeleteNext() end)
    deleteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().title)
        GameTooltip:AddLine(S().perClick, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    deleteButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The window the player's bag slots are drawn in, whatever addon draws it:
-- any visible button that answers GetBagID with a backpack bag sits inside
-- it, and its top-level ancestor is the window itself. No frame names to
-- guess, so Baganator, ElvUI, Bagnon and the default bags all resolve.
local function FindBagWindow()
    local frame = EnumerateFrames()
    while frame do
        if frame:IsVisible() and frame.GetBagID then
            local ok, bag = pcall(frame.GetBagID, frame)
            if ok and type(bag) == "number" and bag >= 0 and bag <= LAST_BAG then
                local top = frame
                local parent = top:GetParent()
                while parent and parent ~= UIParent do
                    top = parent
                    parent = top:GetParent()
                end
                return top
            end
        end
        frame = EnumerateFrames(frame)
    end
end

-- Tops level with the bag window while the list is being built, so it grows
-- downwards alongside the bags; the first delete pins the bottom edge
-- instead, so the button stops moving while the list melts from the top.
local function AnchorPanel()
    bottomPinned = false
    panel:ClearAllPoints()
    local window = FindBagWindow()
    if window then
        panel:SetPoint("TOPRIGHT", window, "TOPLEFT", -8, 0)
        -- The session lives with the bags: closing the window abandons the
        -- list through the panel's own OnHide cleanup. Hooks cannot be
        -- removed, so each window is hooked once and the handler checks the
        -- session instead.
        if not window._lgbMassDeleteHooked then
            window._lgbMassDeleteHooked = true
            window:HookScript("OnHide", function()
                if active then panel:Hide() end
            end)
        end
        DevLog("Anchored beside " .. (window:GetName() or "unnamed bag window"))
        return true
    end
    panel:SetPoint("TOP", UIParent, "CENTER", 260, 200)
    return false
end

Refresh = function()
    if not panel then return end

    local shown = math.min(#queue, MAX_ROWS)
    for i = 1, shown do
        local row = rows[i] or BuildRow(i)
        rows[i] = row
        local entry = queue[i]
        row.index = i
        row.link = entry.link
        row.icon:SetTexture(entry.icon)
        row.text:SetText(entry.count > 1 and (entry.link .. " x" .. entry.count) or entry.link)
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    local overflow = #queue - shown
    overflowText:SetShown(overflow > 0)
    if overflow > 0 then
        overflowText:ClearAllPoints()
        overflowText:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -(TITLE_H + HINT_H + shown * ROW_H))
        overflowText:SetText(string.format(S().more, overflow))
    end

    if #queue == 0 then
        deleteButton:SetText(S().deleteEmpty)
        deleteButton:SetEnabled(false)
    else
        deleteButton:SetText(#queue == 1 and S().deleteLast or string.format(S().deleteNext, #queue))
        deleteButton:SetEnabled(true)
    end

    panel:SetHeight(TITLE_H + HINT_H + shown * ROW_H + (overflow > 0 and 16 or 0) + FOOTER_H)
end

-------------------------------------------------------------------------------
-- The mode
-------------------------------------------------------------------------------

local function Exit(message)
    active = false
    wipe(queue)
    if panel then panel:Hide() end
    if message then Say(message) end
end

local function Enter(seedBag, seedSlot)
    active = true
    deletedCount = 0
    wipe(queue)
    if seedBag then Add(seedBag, seedSlot) end
    BuildPanel()
    anchored = AnchorPanel()
    Refresh()
    panel:Show()
    DevLog("Entered mass delete mode")
end

-- In-mode bag clicks land here through the PickupContainerItem hook: bounce
-- the item straight off the cursor and toggle it in the queue instead.
local function OnPickup(bag, slot)
    if not active or deleting then return end
    if GetCursorInfo() ~= "item" then return end -- empty slot, or the pickup failed
    ClearCursor()

    local index = IndexOf(bag, slot)
    if index then
        table.remove(queue, index)
    else
        Add(bag, slot)
    end
    -- Bags opened after the panel did: this click proves a bag window is on
    -- screen now, so take another shot at sitting beside it.
    if not anchored then anchored = AnchorPanel() end
    Refresh()
end

function LuckyGrabbag.MassDelete:DeleteNext()
    local entry = queue[1]
    if not entry then return end

    if not bottomPinned then
        bottomPinned = true
        PinBottom()
    end

    -- A bag sort can move a queued item between clicks; chase the link before
    -- trusting the remembered slot.
    if C_Container.GetContainerItemLink(entry.bag, entry.slot) ~= entry.link then
        local bag, slot = FindByLink(entry.link)
        if not bag then
            table.remove(queue, 1)
            Say(string.format(S().itemMoved, entry.link))
            if #queue == 0 then Exit() else Refresh() end
            return
        end
        entry.bag, entry.slot = bag, slot
    end

    deleting = true
    C_Container.PickupContainerItem(entry.bag, entry.slot)
    local deleted = false
    if GetCursorInfo() == "item" then
        DeleteCursorItem()
        -- A call the client refuses (no hardware budget left) is blocked
        -- silently and leaves the item on the cursor; keep it queued and put
        -- it back rather than counting it as gone.
        deleted = GetCursorInfo() == nil
    end
    if deleted then
        deletedCount = deletedCount + 1
        table.remove(queue, 1)
        DevLog("Deleted " .. entry.link)
    else
        ClearCursor()
    end
    deleting = false

    if #queue == 0 then
        Exit(deletedCount == 1 and S().finishedOne or string.format(S().finished, deletedCount))
    else
        Refresh()
    end
end

-------------------------------------------------------------------------------
-- The way in: a button beside the game's own delete confirmation
-------------------------------------------------------------------------------

local function OnOpenClicked()
    -- The pending item sits on the cursor with its origin slot locked, which
    -- is how it gets found and seeded into the list before the popup goes.
    local kind, _, cursorLink = GetCursorInfo()
    local bag, slot
    if kind == "item" then
        bag, slot = FindByLink(cursorLink, true)
    end
    ClearCursor()
    StaticPopup_Hide(StaticPopup1.which)

    if active then
        if bag and not IndexOf(bag, slot) then
            Add(bag, slot)
            Refresh()
        end
    else
        Enter(bag, slot)
    end
end

local function EnsureOpenButton()
    if openButton then return end
    openButton = CreateFrame("Button", "LGB_MassDeleteOpenButton", StaticPopup1, "UIPanelButtonTemplate")
    openButton:SetSize(110, 24)
    openButton:SetPoint("BOTTOM", StaticPopup1, "BOTTOM", 0, 10)
    openButton:SetText(S().openButton)
    openButton:SetScript("OnClick", OnOpenClicked)
    openButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().openButton)
        GameTooltip:AddLine(S().openTooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    openButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function LuckyGrabbag.MassDelete:Init(database)
    db = database

    hooksecurefunc(C_Container, "PickupContainerItem", OnPickup)

    -- The popup's content hangs from its top, so extra height opens a strip
    -- along the bottom edge for the Mass Delete button without moving the
    -- stock buttons. Blizzard recalculates the height on every show, so the
    -- stretch never accumulates.
    StaticPopup1:HookScript("OnShow", function(self)
        if db.massDelete and DELETE_POPUPS[self.which] then
            EnsureOpenButton()
            self:SetHeight(self:GetHeight() + POPUP_EXTRA)
            openButton:Show()
        elseif openButton then
            openButton:Hide()
        end
    end)

    DevLog("Initialized")
end
