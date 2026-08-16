-- Lucky's Grab-bag: Remembers the blueprint share codes you import, so a code
-- can be brought back and imported again without hunting down where it came from.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.BlueprintImportHistory = {}

local Feature = LuckyGrabbag.BlueprintImportHistory

local MAX_CODES = 10
local CODE_PREVIEW_LENGTH = 12
local HISTORY_ATLAS = "auctionhouse-icon-clock"

local db
local historyButton

local function DevLog(msg)
    LuckyGrabbag.DevLog("BlueprintImportHistory", msg)
end

local function S()
    return LuckyGrabbag.Strings.blueprintImportHistory
end

local function Remember(code, blueprintType)
    if not db.blueprintImportHistory then return end

    for i = #db.blueprintImportCodes, 1, -1 do
        if db.blueprintImportCodes[i].code == code then
            table.remove(db.blueprintImportCodes, i)
        end
    end

    table.insert(db.blueprintImportCodes, 1, { code = code, blueprintType = blueprintType })
    for i = #db.blueprintImportCodes, MAX_CODES + 1, -1 do
        table.remove(db.blueprintImportCodes, i)
    end

    DevLog("Remembered code, history now " .. #db.blueprintImportCodes)
end

--- The code itself is the only identity a share code has, so the label leads
--- with the blueprint type and keeps enough of the code to recognise it.
local function EntryLabel(entry)
    local preview = entry.code
    if #preview > CODE_PREVIEW_LENGTH then
        preview = preview:sub(1, CODE_PREVIEW_LENGTH) .. "..."
    end

    local typeName = HousingBlueprintTypeStrings[entry.blueprintType]
    if typeName then
        return string.format("%s |cff909090%s|r", typeName, preview)
    end
    return preview
end

local function UpdateButton()
    if not historyButton then return end
    historyButton:SetShown(db.blueprintImportHistory and #db.blueprintImportCodes > 0)
end

local function CreateButton()
    local input = HousingBlueprintImportFrame.InputContent

    historyButton = CreateFrame("DropdownButton", "LGB_BlueprintImportHistoryButton", input, "UIPanelIconDropdownButtonTemplate")
    historyButton.ignoreInLayout = true
    historyButton:SetPoint("RIGHT", input.GearDropdown, "LEFT", -6, 0)

    -- The template ships a gear icon on both the artwork and highlight layers.
    for _, region in ipairs({ historyButton:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            region:SetAtlas(HISTORY_ATLAS, false)
            region:SetSize(15, 15)
        end
    end

    historyButton:SetupMenu(function(_, rootDescription)
        rootDescription:CreateTitle(S().menuTitle)
        for _, entry in ipairs(db.blueprintImportCodes) do
            rootDescription:CreateButton(EntryLabel(entry), function()
                HousingBlueprintImportFrame.InputContent:SetShareCode(entry.code)
            end)
        end
    end)

    historyButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().buttonTooltip)
        GameTooltip:AddLine(S().buttonTooltipDetail, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    historyButton:HookScript("OnLeave", GameTooltip_Hide)

    DevLog("History button created")
end

local function OnBlueprintUILoaded()
    -- Every import path funnels through OnImportConfirmed: house, interior and
    -- exterior after their confirmation popup, rooms directly.
    hooksecurefunc(HousingBlueprintImportFrame, "OnImportConfirmed", function(_, code, blueprintType)
        Remember(code, blueprintType)
        UpdateButton()
    end)

    CreateButton()
    HousingBlueprintImportFrame:HookScript("OnShow", UpdateButton)
    UpdateButton()
end

function Feature:ApplySetting()
    UpdateButton()
end

function Feature:Init(database)
    db = database
    db.blueprintImportCodes = db.blueprintImportCodes or {}

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, addonName)
        if addonName == "Blizzard_HousingBlueprint" then
            OnBlueprintUILoaded()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)

    -- The blueprint UI is load-on-demand, so it may already be up.
    if C_AddOns.IsAddOnLoaded("Blizzard_HousingBlueprint") then
        OnBlueprintUILoaded()
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end
