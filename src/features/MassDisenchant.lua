-- luacheck: globals GetCVarBool IsResting

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.MassDisenchant = {}

local DISENCHANT_SPELL_ID = 13262
local LAST_BAG = 5
local PANEL_WIDTH = 310
local TITLE_HEIGHT = LuckyUI.HEADER_HEIGHT + 1
local ROW_HEIGHT = 26
local LIST_HEIGHT = 364
local FOOTER_HEIGHT = 36

local C = LuckyUI.C
local FONT = LuckyUI.BODY_FONT

local panel, scroll, content, emptyText, destroyButton
local buttons = {}
local omitted = {}
local selected
local readyForNext = false
local db

local function S() return LuckyGrabbag.Strings.massDisenchant end

local function IsCandidate(info)
    if not info or not info.hyperlink then return false end
    local quality = C_Item.GetItemQualityByID(info.hyperlink)
    if quality ~= 2 and quality ~= 3 then return false end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.hyperlink)
    return classID == 2 or classID == 4
end

function LuckyGrabbag.MassDisenchant:Scan()
    local items = {}
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if IsCandidate(info) and not omitted[info.hyperlink] then
                table.insert(items, {
                    bag = bag,
                    slot = slot,
                    icon = info.iconFileID,
                    link = info.hyperlink,
                })
            end
        end
    end
    return items
end

function LuckyGrabbag.MassDisenchant:DestroyMacro(item)
    return ("/cast %s\n/use %d %d"):format(C_Spell.GetSpellName(DISENCHANT_SPELL_ID), item.bag, item.slot)
end

function LuckyGrabbag.MassDisenchant:DestroyClickTrigger()
    return GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp"
end

local function BuildButton(index)
    local button = CreateFrame("Button", nil, content)
    button:SetSize(PANEL_WIDTH - 34, ROW_HEIGHT)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("LEFT")

    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(FONT, 11, "")
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
    button.text:SetPoint("RIGHT")
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:AddLine(S().omitHint, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            omitted[self.link] = true
            if selected and selected.link == self.link then selected = nil end
        else
            selected = { bag = self.bag, slot = self.slot, link = self.link }
        end
        LuckyGrabbag.MassDisenchant:Refresh()
    end)
    button:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -(index - 1) * ROW_HEIGHT)
    return button
end

local function RefreshAfterDestroy()
    C_Timer.After(0, function()
        if panel:IsShown() and not InCombatLockdown() then
            LuckyGrabbag.MassDisenchant:Refresh()
        end
    end)
end

local function UpdateReadyGlow()
    if readyForNext and selected then
        destroyButton:LockHighlight()
    else
        destroyButton:UnlockHighlight()
    end
end

local function BuildPanel()
    if panel then return end

    local titleBar
    panel, titleBar = LuckyUI.CreateWindow("LGB_MassDisenchantPanel", PANEL_WIDTH,
        TITLE_HEIGHT + LIST_HEIGHT + FOOTER_HEIGHT + 12, S().title)
    local position = db.massDisenchantPosition
    if position then
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
    end
    titleBar:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        db.massDisenchantPosition = {
            x = panel:GetLeft() - UIParent:GetLeft(),
            y = panel:GetBottom() - UIParent:GetBottom(),
        }
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 11, "")
    hint:SetPoint("TOPLEFT", 12, -(TITLE_HEIGHT + 8))
    hint:SetPoint("TOPRIGHT", -12, -(TITLE_HEIGHT + 8))
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(S().hint)
    hint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -(TITLE_HEIGHT + 36))
    scroll:SetPoint("BOTTOMRIGHT", -28, FOOTER_HEIGHT + 10)
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(PANEL_WIDTH - 40)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    emptyText = content:CreateFontString(nil, "OVERLAY")
    emptyText:SetFont(FONT, 11, "")
    emptyText:SetPoint("TOPLEFT")
    emptyText:SetPoint("TOPRIGHT")
    emptyText:SetJustifyH("LEFT")
    emptyText:SetWordWrap(true)
    emptyText:SetText(S().empty)
    emptyText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    destroyButton = CreateFrame("Button", "LGB_MassDisenchantDestroyButton", panel,
        "BackdropTemplate,SecureActionButtonTemplate")
    LuckyUI.StyleButton(destroyButton, "", "primary")
    -- Gives LockHighlight something to light up for the ready glow.
    destroyButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    destroyButton:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.2)
    destroyButton:SetSize(PANEL_WIDTH - 24, 24)
    destroyButton:SetPoint("BOTTOM", 0, 10)
    destroyButton:RegisterForClicks(LuckyGrabbag.MassDisenchant:DestroyClickTrigger())
    destroyButton:SetAttribute("*type1", "macro")
    destroyButton:SetAttribute("*macrotext1", "")
    destroyButton:SetText(S().destroyNext)
    destroyButton:SetScript("PostClick", function()
        readyForNext = false
        UpdateReadyGlow()
        RefreshAfterDestroy()
    end)
end

local function CurrentSelected(items)
    for _, item in ipairs(items) do
        if selected and item.bag == selected.bag and item.slot == selected.slot and item.link == selected.link then
            return item
        end
    end
    return items[1]
end

function LuckyGrabbag.MassDisenchant:Refresh()
    if InCombatLockdown() then return end

    local items = self:Scan()
    selected = CurrentSelected(items)
    emptyText:SetShown(#items == 0)
    content:SetHeight(math.max(#items * ROW_HEIGHT, LIST_HEIGHT))
    for index, item in ipairs(items) do
        local button = buttons[index] or BuildButton(index)
        buttons[index] = button
        button.bag = item.bag
        button.slot = item.slot
        button.link = item.link
        button.icon:SetTexture(item.icon)
        button.text:SetText(item.link)
        if selected == item then button:LockHighlight() else button:UnlockHighlight() end
        button:Show()
    end
    for index = #items + 1, #buttons do buttons[index]:Hide() end

    if selected then
        destroyButton:SetAttribute("*macrotext1", self:DestroyMacro(selected))
        destroyButton:SetEnabled(true)
    else
        destroyButton:SetAttribute("*macrotext1", "")
        destroyButton:SetEnabled(false)
    end
    UpdateReadyGlow()
end

function LuckyGrabbag.MassDisenchant:Open()
    if InCombatLockdown() then
        print(LuckyGrabbag.PREFIX .. " " .. S().inCombat)
        return
    end
    if not C_SpellBook.ContainsAnyDisenchantSpell() then
        print(LuckyGrabbag.PREFIX .. " " .. S().noSkill)
        return
    end
    BuildPanel()
    self:Refresh()
    panel:Show()
end

function LuckyGrabbag.MassDisenchant:Init(database)
    db = database
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit == "player" and spellID == DISENCHANT_SPELL_ID then
                readyForNext = true
                if db.massDisenchantAutoOpen and IsResting() then self:Open() end
                C_Timer.After(0, function()
                    if panel and panel:IsShown() and not InCombatLockdown() then self:Refresh() end
                end)
            end
            return
        end
        if panel and panel:IsShown() then
            LuckyGrabbag.MassDisenchant:Refresh()
        end
    end)
end
