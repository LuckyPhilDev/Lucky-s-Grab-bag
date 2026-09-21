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
local namePane

local DevLog = LuckyGrabbag.Logger("BlueprintImportHistory")

local function S()
    return LuckyGrabbag.Strings.blueprintImportHistory
end

--- Moves a re-entered code to the top with its name intact, and returns the
--- stored entry so the name prompt can attach to it.
local function Remember(code, blueprintType)
    if not db.blueprintImportHistory then return end

    local name
    for i = #db.blueprintImportCodes, 1, -1 do
        if db.blueprintImportCodes[i].code == code then
            name = db.blueprintImportCodes[i].name
            table.remove(db.blueprintImportCodes, i)
        end
    end

    local entry = { code = code, blueprintType = blueprintType, name = name }
    table.insert(db.blueprintImportCodes, 1, entry)
    for i = #db.blueprintImportCodes, MAX_CODES + 1, -1 do
        table.remove(db.blueprintImportCodes, i)
    end

    DevLog("Remembered code, history now " .. #db.blueprintImportCodes)
    return entry
end

local function Forget(code)
    for i = #db.blueprintImportCodes, 1, -1 do
        if db.blueprintImportCodes[i].code == code then
            table.remove(db.blueprintImportCodes, i)
        end
    end
    DevLog("Forgot code, history now " .. #db.blueprintImportCodes)
end

local function CodePreview(code)
    if #code > CODE_PREVIEW_LENGTH then
        return code:sub(1, CODE_PREVIEW_LENGTH) .. "..."
    end
    return code
end

--- A named entry leads with its name. Without one, the blueprint type and
--- enough of the code to recognise it are all the identity a share code has.
local function EntryLabel(entry)
    local typeName = HousingBlueprintTypeStrings[entry.blueprintType]

    if entry.name and entry.name ~= "" then
        return string.format("%s |cff909090%s|r", entry.name, typeName or CodePreview(entry.code))
    end
    if typeName then
        return string.format("%s |cff909090%s|r", typeName, CodePreview(entry.code))
    end
    return CodePreview(entry.code)
end

local function UpdateButton()
    if not historyButton then return end
    historyButton:SetShown(db.blueprintImportHistory)
    historyButton:SetEnabled(#db.blueprintImportCodes > 0)
    DevLog(string.format("UpdateButton: setting=%s, codes=%d",
        tostring(db.blueprintImportHistory), #db.blueprintImportCodes))
end

-------------------------------------------------------------------------------
-- The name pane: prompts for a label the moment a code is saved
-------------------------------------------------------------------------------

local function BuildNamePane()
    if namePane then return namePane end

    local C = LuckyUI.C
    local FONT = LuckyUI.BODY_FONT

    -- Parented to the import window, so it follows its visibility and position.
    local f = CreateFrame("Frame", "LGB_BlueprintCodeNamePane", HousingBlueprintImportFrame, "BackdropTemplate")
    f:SetSize(240, 150)
    f:SetPoint("TOPLEFT", HousingBlueprintImportFrame, "TOPRIGHT", 12, 0)
    f:SetBackdrop(LuckyUI.Backdrop)
    f:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], C.bgDark[4])
    f:SetBackdropBorderColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3])
    f:Hide()
    LuckyUI.CreateHeader(f, S().namePaneTitle)

    local codeLine = f:CreateFontString(nil, "OVERLAY")
    codeLine:SetFont(FONT, 11, "")
    codeLine:SetPoint("TOPLEFT", 12, -(LuckyUI.HEADER_HEIGHT + 11))
    codeLine:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    f.codeLine = codeLine

    local editBox = LuckyUI.CreateInput(f, { width = 216, height = 22, maxLetters = 40 })
    editBox:SetPoint("TOPLEFT", codeLine, "BOTTOMLEFT", 0, -8)
    f.editBox = editBox

    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 10, "")
    hint:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(S().namePaneHint)
    hint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local save = LuckyUI.CreateButton(f, SAVE, 90, 22, "primary")
    save:SetPoint("BOTTOMRIGHT", -12, 10)
    f.saveButton = save

    local function SaveName()
        local entry = f.entry
        if entry then
            local name = strtrim(editBox:GetText() or "")
            entry.name = name ~= "" and name or nil
            DevLog("Named code: " .. tostring(entry.name))
        end
        editBox:ClearFocus()
        f:Hide()
    end

    save:SetScript("OnClick", SaveName)
    editBox:SetScript("OnEnterPressed", SaveName)
    editBox:SetScript("OnEscapePressed", function()
        editBox:ClearFocus()
        f:Hide()
    end)

    namePane = f
    return f
end

local function ShowNamePane(entry)
    local f = BuildNamePane()
    f.entry = entry

    local typeName = HousingBlueprintTypeStrings[entry.blueprintType]
    f.codeLine:SetText(typeName
        and string.format("%s  %s", typeName, CodePreview(entry.code))
        or CodePreview(entry.code))
    f.editBox:SetText(entry.name or "")
    f:Show()
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
            local row = rootDescription:CreateButton(EntryLabel(entry), function()
                DevLog("Recalling code " .. CodePreview(entry.code))
                HousingBlueprintImportFrame.InputContent:SetShareCode(entry.code)
            end)

            -- Same row furniture as Lucky's Wardrobe situation presets: an X
            -- to delete and a pencil to rename, inline on the right.
            row:AddInitializer(function(menuButton, _description, menu)
                local deleteButton = MenuTemplates.AttachBasicButton(menuButton)
                deleteButton:SetPoint("RIGHT", menuButton, "RIGHT", -3, 0)
                local deleteIcon = deleteButton:AttachTexture()
                deleteIcon:SetAllPoints()
                deleteIcon:SetTexture(MenuVariants.CancelButtonTexture)
                deleteButton:SetScript("OnClick", function()
                    Forget(entry.code)
                    UpdateButton()
                    menu:Close()
                end)
                MenuUtil.HookTooltipScripts(deleteButton, function(tooltip)
                    tooltip:SetText(S().deleteTooltip)
                end)

                local renameButton = MenuTemplates.AttachBasicButton(menuButton)
                renameButton:SetPoint("RIGHT", deleteButton, "LEFT", -2, 0)
                local renameIcon = renameButton:AttachTexture()
                renameIcon:SetAllPoints()
                renameIcon:SetAtlas("Pencil-Icon")
                renameButton:SetScript("OnClick", function()
                    ShowNamePane(entry)
                    menu:Close()
                end)
                MenuUtil.HookTooltipScripts(renameButton, function(tooltip)
                    tooltip:SetText(S().renameTooltip)
                end)
            end)
        end
    end)

    historyButton:SetMotionScriptsWhileDisabled(true)
    historyButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S().buttonTooltip)
        local detail = #db.blueprintImportCodes > 0 and S().buttonTooltipDetail or S().buttonTooltipEmpty
        GameTooltip:AddLine(detail, 1, 1, 1, true)
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

    -- A code counts as "put in" the moment Next accepts it, import or not.
    if type(frame.OnInputNextClicked) == "function" then
        hooksecurefunc(frame, "OnInputNextClicked", function(self)
            local isValid = self.InputContent:IsInputValid()
            DevLog("OnInputNextClicked fired, valid=" .. tostring(isValid))
            if not isValid then return end

            local code, blueprintType = self.InputContent:GetInputValues()
            local entry = Remember(code, blueprintType)
            UpdateButton()
            if entry then ShowNamePane(entry) end
        end)
    else
        DevLog("OnInputNextClicked is not a function, cannot hook the Next button")
    end

    -- Codes arriving pre-filled (blueprint links) skip the input tab entirely,
    -- so catch them at OnImportConfirmed, where every import path ends up.
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
