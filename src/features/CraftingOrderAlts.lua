LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.CraftingOrderAlts = {}

local BLIZZARD_ADDON = "Blizzard_ProfessionsCustomerOrders"
local PAD = 8
local HEADER_HEIGHT = 40
local ROW_HEIGHT = 22
local MIN_WIDTH = 150
local C = LuckyUI.C

local db
local form
local panel
local rows = {}

local function HasProfession(entry, profession)
    for _, known in ipairs(entry.professions) do
        if known.skillLine == profession then return true end
    end
    return false
end

local function ReachableRealms(homeRealm)
    local realms = { [homeRealm] = true }
    for _, realm in ipairs(C_AutoComplete.GetAutoCompleteRealms()) do
        realms[realm] = true
    end
    return realms
end

local function Crafters(recipeID)
    local info = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
    local profession = info.parentProfessionID or info.professionID
    local homeRealm = GetNormalizedRealmName()
    local realms = ReachableRealms(homeRealm)
    local me = LuckyRoster:GetKey()

    local crafters = {}
    for _, key in ipairs(LuckyRoster:GetKeys()) do
        local entry = LuckyRoster:Get(key)
        if key ~= me and realms[entry.realm] and HasProfession(entry, profession) then
            local home = entry.realm == homeRealm
            table.insert(crafters, {
                target = home and entry.name or key,
                name   = entry.name,
                realm  = not home and entry.realm or "",
                class  = entry.class,
            })
        end
    end
    return crafters, info.parentProfessionName or info.professionName
end

local function SendTo(target)
    local personal = Enum.CraftingOrderType.Personal
    if form.order.orderType ~= personal then
        form:SetOrderRecipient(personal)
        -- The dropdown only redraws its label when its menu is regenerated.
        form.OrderRecipientDropdown:GenerateMenu()
    end
    form.OrderRecipientTarget:SetText(target)
    form:UpdateListOrderButton()
end

local function CreateText(parent, font, size, color)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(font, size, "")
    text:SetTextColor(color[1], color[2], color[3])
    return text
end

local function CreatePanel()
    panel = LuckyUI.CreatePanel(nil, form, MIN_WIDTH, HEADER_HEIGHT)
    panel:SetMovable(false)
    panel:SetScript("OnDragStart", nil)
    panel:SetScript("OnDragStop", nil)

    panel.title = CreateText(panel, LuckyUI.TITLE_FONT, 11, C.goldPrimary)
    panel.title:SetPoint("TOPLEFT", PAD, -PAD)
    panel.title:SetText(LuckyGrabbag.Strings.craftingOrderAlts.title)

    panel.profession = CreateText(panel, LuckyUI.BODY_FONT, 11, C.textMuted)
    panel.profession:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -3)
end

local function ShowTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.name:GetText())
    GameTooltip:AddLine(LuckyGrabbag.Strings.craftingOrderAlts.tooltip, 1, 1, 1, true)
    GameTooltip:Show()
end

local function GetRow(index)
    if rows[index] then return rows[index] end

    local row = CreateFrame("Button", nil, panel)
    local top = -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 1, top)
    row:SetPoint("TOPRIGHT", -1, top)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])

    row.name = CreateText(row, LuckyUI.BODY_FONT, 12, C.textLight)
    row.name:SetPoint("LEFT", PAD - 1, 0)
    row.realm = CreateText(row, LuckyUI.BODY_FONT, 11, C.textMuted)
    row.realm:SetPoint("RIGHT", 1 - PAD, 0)

    row:SetScript("OnClick", function(self) SendTo(self.target) end)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[index] = row
    return row
end

local function Refresh()
    local order = form.order
    local recipeID = db.craftingOrderAlts and order and not form.committed and order.spellID
    local crafters, professionName = {}, nil
    if recipeID then crafters, professionName = Crafters(recipeID) end

    if #crafters == 0 then
        if panel then panel:Hide() end
        return
    end
    if not panel then CreatePanel() end

    panel.profession:SetText(professionName)
    local width = math.max(MIN_WIDTH,
        panel.title:GetStringWidth() + 2 * PAD,
        panel.profession:GetStringWidth() + 2 * PAD)

    for i = #crafters + 1, #rows do rows[i]:Hide() end
    for i, crafter in ipairs(crafters) do
        local row = GetRow(i)
        row.target = crafter.target
        row.name:SetText(RAID_CLASS_COLORS[crafter.class]:WrapTextInColorCode(crafter.name))
        row.realm:SetText(crafter.realm)
        row:Show()
        width = math.max(width, row.name:GetStringWidth() + row.realm:GetStringWidth() + 3 * PAD)
    end

    local listings = form.CurrentListings
    panel:SetSize(width, HEADER_HEIGHT + #crafters * ROW_HEIGHT + PAD / 2)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", listings:IsShown() and listings or form, "TOPRIGHT", 10, 0)
    panel:Show()
end

local function InstallHooks()
    form = ProfessionsCustomerOrdersFrame.Form
    hooksecurefunc(form, "Init", Refresh)
    hooksecurefunc(form, "SetRecraftItemGUID", Refresh)
    hooksecurefunc(form, "ShowCurrentListings", Refresh)
    hooksecurefunc(form, "HideCurrentListings", Refresh)
end

function LuckyGrabbag.CraftingOrderAlts:Init(database)
    db = database
    if C_AddOns.IsAddOnLoaded(BLIZZARD_ADDON) then
        InstallHooks()
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= BLIZZARD_ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        InstallHooks()
    end)
end
