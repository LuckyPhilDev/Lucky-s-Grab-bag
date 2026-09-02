-- Lucky's Grab-bag: shows a vendor's decor piece as a model beside its tooltip.
-- An item icon says nothing about what a piece of furniture actually looks like,
-- and the only other way to see one is to buy it and place it in a house.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DecorPreview = {}

local Feature = LuckyGrabbag.DecorPreview

local PANEL_WIDTH = 260
local PANEL_HEIGHT = 300
local GAP = 6
local YAW_PER_SECOND = 0.5
local TWO_PI = math.pi * 2
local DEFAULT_SCENE_ID = Constants.HousingCatalogConsts.HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT
local CAMERA_IMMEDIATE = 1
local CAMERA_DISCARD = 1

local db
local panel
local scene
local shownRecordID

local DevLog = LuckyGrabbag.Logger("DecorPreview")

--- Rides beside the tooltip so the two can never cover each other, flipping to
--- whichever side has the room. The tooltip resizes as it fills in, so this is
--- re-checked while the preview is up rather than once when it opens.
local function AnchorToTooltip()
    local right = GameTooltip:GetRight()
    local screenWidth = UIParent:GetRight()
    if not right or not screenWidth then return end

    local side = (right + GAP + PANEL_WIDTH <= screenWidth) and "RIGHT" or "LEFT"
    if side == panel.side then return end
    panel.side = side

    panel:ClearAllPoints()
    if side == "RIGHT" then
        panel:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", -GAP, 0)
    end
end

local function OnUpdate(self, elapsed)
    AnchorToTooltip()
    if not scene.decorActor then return end
    scene.yaw = (scene.yaw + elapsed * YAW_PER_SECOND) % TWO_PI
    scene.decorActor:SetYaw(scene.yaw)
end

local function Hide()
    shownRecordID = nil
    if panel then panel:Hide() end
end

local function CreatePanel()
    if panel then return end

    panel = LuckyUI.CreatePanel("LGB_DecorPreview", UIParent, PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetFrameStrata("TOOLTIP")
    -- Docked to the tooltip, so it neither drags nor takes the mouse off it.
    panel:SetMovable(false)
    panel:EnableMouse(false)
    panel:SetScript("OnDragStart", nil)
    panel:SetScript("OnDragStop", nil)
    panel:SetScript("OnUpdate", OnUpdate)

    scene = CreateFrame("ModelScene", nil, panel, "PanningModelSceneMixinTemplate")
    scene:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    scene:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    scene.yaw = 0

    GameTooltip:HookScript("OnHide", Hide)
    panel:Hide()
end

local function ShowDecor(info)
    -- The tooltip refreshes itself while hovered, so reloading the same model
    -- every pass would restart the turntable and never let it turn.
    if shownRecordID == info.recordID and panel and panel:IsShown() then return end

    CreatePanel()
    scene:TransitionToModelSceneID(info.uiModelSceneID or DEFAULT_SCENE_ID,
        CAMERA_IMMEDIATE, CAMERA_DISCARD, true)

    local actor = scene:GetActorByTag("decor")
    scene.decorActor = actor
    if not actor then
        DevLog("scene " .. tostring(info.uiModelSceneID) .. " has no decor actor")
        Hide()
        return
    end

    -- Furniture is wider than it is tall, so the camera has to frame the whole piece.
    actor:SetPreferModelCollisionBounds(true)
    actor:SetModelByFileID(info.asset)

    scene.yaw = 0
    shownRecordID = info.recordID
    panel.side = nil
    AnchorToTooltip()
    panel:Show()
end

--- Vendor UI replacements rewrite the merchant buttons and their item indices,
--- so the tooltip is the one place the hovered item can be read reliably.
local function IsMerchantSlot(frame)
    local name = frame and frame.GetName and frame:GetName()
    return name and name:match("^MerchantItem%d+ItemButton$") ~= nil
end

local function OnItemTooltip(tooltip, data)
    if not db.decorVendorPreview then return end
    if tooltip ~= GameTooltip or not MerchantFrame:IsShown() then return end
    if not IsMerchantSlot(tooltip:GetOwner()) then return end

    local info = data.id and C_HousingCatalog.GetCatalogEntryInfoByItem(data.id)
    if info and info.asset then
        ShowDecor(info)
    else
        Hide()
    end
end

function Feature:ApplySetting()
    if not db.decorVendorPreview then Hide() end
end

function Feature:Init(database)
    db = database
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end
