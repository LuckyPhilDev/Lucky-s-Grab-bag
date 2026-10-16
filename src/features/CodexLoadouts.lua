LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.CodexLoadouts = {}

-- The Codex is a player choice with no fixed ID we can rely on; its item shares the window's localized title.
local CODEX_ITEM_ID = 276142
local WIDTH = 290
local PAD = 26
local DOCK_GAP = 14
local TITLE_TOP = 48
local INPUT_TOP = -84
local DIVIDER_TOP = -122
local LIST_TOP = -138
local BUTTON_HEIGHT = 26
local SAVE_WIDTH = 64
local FOOTER_BOTTOM = 30
local POWERS_INSET = 8
local ROW_GAP = 12
local STEP_INTERVAL = 0.3
local RECLICK_DELAY = 1
local LOAD_TIMEOUT = 5
local CHECKMARK = CreateAtlasMarkup("common-icon-checkmark", 16, 16)

local DevLog = LuckyGrabbag.Logger("CodexLoadouts")

local db
local window, nameInput, emptyText
local rows = {}
local applying

local function S()
    return LuckyGrabbag.Strings.codexLoadouts
end

local function Print(message)
    print(LuckyGrabbag.PREFIX .. " " .. message)
end

local function CodexInfo()
    local info = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
    local title = C_Item.GetItemNameByID(CODEX_ITEM_ID)
    if not info or not title then return nil end
    if info.questionText == title then return info end
    for _, option in ipairs(info.options) do
        if option.header == title then return info end
    end
    return nil
end

-- The Codex flags an active power only by a checkmark in front of its name, an icon escape or a glyph.
local function SplitCheckmark(text)
    local trimmed = strtrim(text)
    local name = strtrim((trimmed:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("^[\226-\239][\128-\191][\128-\191]%s+", "")))
    return name, name ~= trimmed
end

local function Powers(info)
    local powers = {}
    for _, option in ipairs(info.options) do
        for _, button in ipairs(option.buttons) do
            local name, active = SplitCheckmark(button.text)
            table.insert(powers, {
                id       = button.id,
                name     = name,
                active   = active,
                disabled = button.disabled,
            })
        end
    end
    return powers
end

local function Wanted(set)
    local wanted = {}
    for _, name in ipairs(set.powers) do wanted[name] = true end
    return wanted
end

local function Mismatches(powers, wanted)
    local wrong, seen = {}, {}
    for _, power in ipairs(powers) do
        seen[power.name] = true
        if power.active ~= (wanted[power.name] == true) then table.insert(wrong, power) end
    end
    for name in pairs(wanted) do
        if not seen[name] then table.insert(wrong, { name = name }) end
    end
    return wrong
end

-- Turning a power off first frees its slot for the one coming in.
local function NextPower(wrong)
    local turnOn
    for _, power in ipairs(wrong) do
        if power.id and not power.disabled then
            if power.active then return power end
            turnOn = turnOn or power
        end
    end
    return turnOn
end

local function Names(powers)
    local names = {}
    for _, power in ipairs(powers) do table.insert(names, power.name) end
    return table.concat(names, ", ")
end

local function Finish(message)
    applying.ticker:Cancel()
    applying = nil
    Print(message)
end

-- Polled rather than event-driven: the Codex can report its old state for a moment after a click.
local function Step()
    local info = CodexInfo()
    if not info then return Finish(S().interrupted) end
    local wrong = Mismatches(Powers(info), applying.wanted)
    if #wrong == 0 then return Finish(S().loaded:format(applying.name)) end
    local now = GetTime()
    if now > applying.deadline then return Finish(S().stuck:format(Names(wrong))) end

    local power = NextPower(wrong)
    if not power or (power.id == applying.lastID and now - applying.lastAt < RECLICK_DELAY) then return end
    applying.lastID, applying.lastAt = power.id, now
    DevLog("Toggling %s (%d)", power.name, power.id)
    C_PlayerChoice.SendPlayerChoiceResponse(power.id)
end

local function Load(set)
    if applying then return end
    applying = {
        name     = set.name,
        wanted   = Wanted(set),
        deadline = GetTime() + LOAD_TIMEOUT,
        ticker   = C_Timer.NewTicker(STEP_INTERVAL, function() Step() end),
    }
    Step()
end

local Render

local function Save()
    local info = CodexInfo()
    if not info then return end
    local active = {}
    for _, power in ipairs(Powers(info)) do
        if power.active then table.insert(active, power.name) end
    end
    if #active == 0 then return Print(S().nothingActive) end

    local name = strtrim(nameInput:GetText())
    if name == "" then name = table.concat(active, " + ") end
    local sets = db.codexLoadoutSets
    local existing
    for _, set in ipairs(sets) do
        if set.name == name then existing = set end
    end
    if existing then
        existing.powers = active
    else
        table.insert(sets, { name = name, powers = active })
    end
    nameInput:SetText("")
    nameInput:ClearFocus()
    Render()
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.set.name)
    for _, power in ipairs(button.set.powers) do GameTooltip:AddLine(power, 1, 1, 1) end
    GameTooltip:AddLine(S().deleteHint, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function OnRowClick(button, mouseButton)
    if mouseButton == "RightButton" then
        StaticPopup_Show("LGB_DELETE_CODEX_LOADOUT", button.set.name, nil, button.set)
    else
        Load(button.set)
    end
end

local function Row(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Frame", nil, window)
    row:SetWidth(WIDTH - 2 * PAD)
    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetPoint("TOPLEFT")
    row.button:SetPoint("TOPRIGHT")
    row.button:SetHeight(BUTTON_HEIGHT)
    row.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.button:SetScript("OnClick", OnRowClick)
    row.button:SetScript("OnEnter", ShowTooltip)
    row.button:SetScript("OnLeave", GameTooltip_Hide)
    row.powers = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.powers:SetPoint("TOPLEFT", row.button, "BOTTOMLEFT", POWERS_INSET, -5)
    row.powers:SetPoint("TOPRIGHT", row.button, "BOTTOMRIGHT", -POWERS_INSET, -5)
    row.powers:SetJustifyH("LEFT")
    row.powers:SetSpacing(2)
    row.powers:SetTextColor(0.8, 0.8, 0.8)
    rows[index] = row
    return row
end

-- ponytail: no scrolling, the Codex is tall enough for about a dozen loadouts.
function Render()
    local info = CodexInfo()
    local powers = info and Powers(info) or {}
    local sets = db.codexLoadoutSets
    local y = LIST_TOP
    for i, set in ipairs(sets) do
        local row = Row(i)
        local current = info and #Mismatches(powers, Wanted(set)) == 0
        row.button.set = set
        row.button:SetText(current and CHECKMARK .. " " .. set.name or set.name)
        row.powers:SetText(table.concat(set.powers, "\n"))
        row:SetHeight(BUTTON_HEIGHT + 5 + row.powers:GetStringHeight())
        row:SetPoint("TOPLEFT", PAD, y)
        row:Show()
        y = y - row:GetHeight() - ROW_GAP
    end
    for i = #sets + 1, #rows do rows[i]:Hide() end
    emptyText:SetShown(#sets == 0)
end

-- Borrows the Codex's own texture kit art so the two read as one window.
local function CopyCodexArt()
    local kit = PlayerChoiceFrame.uiTextureKit
    local kitInfo = PlayerChoiceFrame.textureKitInfo
    window.background:SetAtlas(PlayerChoiceFrame.Background.BackgroundTile:GetAtlas())
    window.background:SetHorizTile(true)
    window.background:SetVertTile(true)
    for _, border in ipairs({ window.border, window.NineSlice }) do
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", kitInfo.borderTopLeftAnchorX, kitInfo.borderTopLeftAnchorY)
        border:SetPoint("BOTTOMRIGHT", kitInfo.borderBottomRightAnchorX, kitInfo.borderBottomRightAnchorY)
    end
    window.border:SetShown(not kitInfo.useOldNineSlice)
    window.NineSlice:SetShown(kitInfo.useOldNineSlice)
    if not kitInfo.useOldNineSlice then
        window.border:SetAtlas(PlayerChoiceFrame.BorderOverlay:GetAtlas())
    elseif kitInfo.uniqueCorners then
        NineSliceUtil.ApplyUniqueCornersLayout(window.NineSlice, kit)
    else
        NineSliceUtil.ApplyIdenticalCornersLayout(window.NineSlice, kit)
    end
end

local function Build()
    window = CreateFrame("Frame", "LGB_CodexLoadouts", UIParent)
    window:SetWidth(WIDTH)
    window:EnableMouse(true)
    window:Hide()
    window.background = window:CreateTexture(nil, "BACKGROUND")
    window.background:SetAllPoints()
    window.border = window:CreateTexture(nil, "OVERLAY")
    window.NineSlice = CreateFrame("Frame", nil, window, "NineSlicePanelTemplate")

    local title = window:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Large")
    title:SetPoint("TOP", 0, -TITLE_TOP)
    title:SetText(S().title)

    nameInput = CreateFrame("EditBox", nil, window, "InputBoxInstructionsTemplate")
    nameInput.Instructions:SetText(S().namePlaceholder)
    nameInput:SetSize(WIDTH - 2 * PAD - SAVE_WIDTH - 12, BUTTON_HEIGHT)
    nameInput:SetPoint("TOPLEFT", PAD + 6, INPUT_TOP)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(40)
    nameInput:SetScript("OnEnterPressed", Save)
    local saveButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    saveButton:SetSize(SAVE_WIDTH, BUTTON_HEIGHT)
    saveButton:SetPoint("TOPRIGHT", -PAD, INPUT_TOP)
    saveButton:SetText(S().save)
    saveButton:SetScript("OnClick", Save)

    local divider = window:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", PAD, DIVIDER_TOP)
    divider:SetPoint("TOPRIGHT", -PAD, DIVIDER_TOP)
    divider:SetColorTexture(1, 1, 1, 0.12)

    emptyText = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", PAD, LIST_TOP)
    emptyText:SetWidth(WIDTH - 2 * PAD)
    emptyText:SetText(S().empty)

    local footer = CreateFrame("Button", nil, window)
    footer:SetPoint("BOTTOM", 0, FOOTER_BOTTOM)
    footer:SetNormalFontObject("GameFontDisableSmall")
    footer:SetHighlightFontObject("GameFontHighlightSmall")
    footer:SetText(S().addedBy)
    footer:SetSize(footer:GetFontString():GetStringWidth(), 16)
    footer:SetScript("OnClick", function()
        LuckyGrabbag.Settings:OpenTo(LuckyGrabbag.Settings.delvesGroup, LuckyGrabbag.Strings.settings.codexLoadouts.label)
    end)
    footer:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(S().addedByTooltip, 1, 1, 1)
        GameTooltip:Show()
    end)
    footer:SetScript("OnLeave", GameTooltip_Hide)

    StaticPopupDialogs.LGB_DELETE_CODEX_LOADOUT = {
        text         = S().confirmDelete,
        button1      = DELETE,
        button2      = CANCEL,
        OnAccept     = function(_, set)
            tDeleteItem(db.codexLoadoutSets, set)
            Render()
        end,
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
    }
end

local function Open()
    if not window then Build() end
    window:SetFrameStrata(PlayerChoiceFrame:GetFrameStrata())
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", PlayerChoiceFrame, "TOPRIGHT", DOCK_GAP, 0)
    window:SetPoint("BOTTOMLEFT", PlayerChoiceFrame, "BOTTOMRIGHT", DOCK_GAP, 0)
    CopyCodexArt()
    Render()
    window:Show()
end

local function Close()
    if window then window:Hide() end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_CHOICE_UPDATE")
eventFrame:RegisterEvent("PLAYER_CHOICE_CLOSE")
local function OnChoiceUpdate()
    if not CodexInfo() then return Close() end
    -- Blizzard builds PlayerChoiceFrame from this same event, so anchor to it a frame later.
    C_Timer.After(0, Open)
end

eventFrame:SetScript("OnEvent", function(_, event)
    if not db or not db.codexLoadouts then return end
    if event == "PLAYER_CHOICE_CLOSE" then return Close() end
    -- The item name is the Codex's title, and it is not cached the first time the Codex opens in a session.
    Item:CreateFromItemID(CODEX_ITEM_ID):ContinueOnItemLoad(OnChoiceUpdate)
end)

function LuckyGrabbag.CodexLoadouts:ApplySetting()
    if not db.codexLoadouts then Close() end
end

function LuckyGrabbag.CodexLoadouts:Init(database)
    db = database
end
