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
    local shown = db.blueprintImportHistory and #db.blueprintImportCodes > 0
    historyButton:SetShown(shown)
    DevLog(string.format("UpdateButton: setting=%s, codes=%d, shown=%s",
        tostring(db.blueprintImportHistory), #db.blueprintImportCodes, tostring(shown)))
end

local function CreateButton()
    local input = HousingBlueprintImportFrame.InputContent

    historyButton = CreateFrame("DropdownButton", "LGB_BlueprintImportHistoryButton", input, "UIPanelIconDropdownButtonTemplate")
    historyButton.ignoreInLayout = true
    historyButton:SetPoint("RIGHT", input.GearDropdown, "LEFT", -6, 0)

    -- The template ships a gear icon on both the artwork and highlight layers.
    if C_Texture.GetAtlasInfo(HISTORY_ATLAS) then
        for _, region in ipairs({ historyButton:GetRegions() }) do
            if region:GetObjectType() == "Texture" then
                region:SetAtlas(HISTORY_ATLAS, false)
                region:SetSize(15, 15)
            end
        end
    else
        DevLog("Atlas " .. HISTORY_ATLAS .. " does not exist, keeping the gear icon")
    end

    historyButton:SetupMenu(function(_, rootDescription)
        DevLog("Menu opened with " .. #db.blueprintImportCodes .. " codes")
        rootDescription:CreateTitle(S().menuTitle)
        for _, entry in ipairs(db.blueprintImportCodes) do
            rootDescription:CreateButton(EntryLabel(entry), function()
                DevLog("Recalling code " .. entry.code:sub(1, CODE_PREVIEW_LENGTH))
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
    local frame = HousingBlueprintImportFrame
    if not frame then
        DevLog("HousingBlueprintImportFrame is missing, cannot attach")
        return
    end
    if not frame.InputContent or not frame.InputContent.GearDropdown then
        DevLog("Import frame layout changed: InputContent="
            .. tostring(frame.InputContent ~= nil)
            .. ", GearDropdown=" .. tostring(frame.InputContent and frame.InputContent.GearDropdown ~= nil))
        return
    end
    if type(frame.OnImportConfirmed) ~= "function" then
        DevLog("OnImportConfirmed is not a function, cannot hook imports")
        return
    end

    -- Every import path funnels through OnImportConfirmed: house, interior and
    -- exterior after their confirmation popup, rooms directly.
    hooksecurefunc(frame, "OnImportConfirmed", function(_, code, blueprintType)
        DevLog(string.format("OnImportConfirmed fired: type=%s, code=%s...",
            tostring(blueprintType), tostring(code):sub(1, CODE_PREVIEW_LENGTH)))
        Remember(code, blueprintType)
        UpdateButton()
    end)

    CreateButton()
    frame:HookScript("OnShow", UpdateButton)
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
            DevLog("Blizzard_HousingBlueprint loaded, attaching")
            OnBlueprintUILoaded()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)

    -- The blueprint UI is load-on-demand, so it may already be up.
    if C_AddOns.IsAddOnLoaded("Blizzard_HousingBlueprint") then
        DevLog("Blizzard_HousingBlueprint already loaded at Init, attaching now")
        OnBlueprintUILoaded()
        eventFrame:UnregisterEvent("ADDON_LOADED")
    else
        DevLog("Waiting for Blizzard_HousingBlueprint to load")
    end
end
