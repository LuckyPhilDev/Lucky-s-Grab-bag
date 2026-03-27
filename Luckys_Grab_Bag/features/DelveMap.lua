-- Lucky's Grab-bag: Trovehunter's Bounty Map button in delves
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveMap = {}

local BOUNTY_MAP_ITEM_ID = 252415
local DELVE_DIFFICULTY_ID = 208
local BUTTON_SIZE = 42

local db
local button
local inCombat = false

local function DevLog(msg)
    LuckyGrabbag.DevLog("DelveMap", msg)
end

-- Returns true + tier number if the player is in a delve, false otherwise.
-- Tier detection tries multiple APIs; returns 0 if tier cannot be determined.
local function GetDelveInfo()
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= DELVE_DIFFICULTY_ID then
        return false, 0
    end

    -- Try C_DelvesUI API (TWW 11.x)
    if C_DelvesUI and C_DelvesUI.GetCurrentDelveTier then
        local ok, tier = pcall(C_DelvesUI.GetCurrentDelveTier)
        if ok and tier then
            DevLog("Tier from C_DelvesUI: " .. tier)
            return true, tier
        end
    end

    -- Try Challenge Mode (delves may expose tier as keystone level)
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if ok and level and level > 0 then
            DevLog("Tier from ChallengeMode: " .. level)
            return true, level
        end
    end

    -- Fallback: parse tier from difficulty name (e.g. "Tier 8", "Level 8")
    local _, _, _, difficultyName = GetInstanceInfo()
    if difficultyName then
        local tier = difficultyName:match("(%d+)")
        if tier then
            DevLog("Tier parsed from difficultyName '" .. difficultyName .. "': " .. tier)
            return true, tonumber(tier)
        end
    end

    DevLog("In delve but tier unknown (difficultyName='" .. tostring(difficultyName) .. "')")
    return true, 0
end

-- Scans bags for the Trovehunter's Bounty Map.
local function HasBountyMap()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == BOUNTY_MAP_ITEM_ID then
                return true, info.itemName, info.iconFileID
            end
        end
    end
    return false
end

local function CreateButton()
    local btn = LuckyGrabbag.CreateIconButton({
        parent   = UIParent,
        name     = "LGB_DelveMapButton",
        template = "SecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        tooltip  = function()
            GameTooltip:SetItemByID(BOUNTY_MAP_ITEM_ID)
        end,
    })
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("type", "item")
    btn:SetFrameStrata("HIGH")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.delveMapPos = { point = point, relPoint = relPoint, x = x, y = y }
        DevLog("Saved position")
    end)
    btn:Hide()
    return btn
end

local function RestorePosition()
    local pos = db.delveMapPos
    if pos then
        button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

local function Refresh()
    if not db.showDelveMap then
        if button then button:Hide() end
        return
    end

    if inCombat then return end

    local inDelve, tier = GetDelveInfo()
    local minLevel = db.delveMapMinLevel or 8
    local meetsLevel = (tier == 0) or (tier >= minLevel)
    local hasMap, itemName, iconFileID = HasBountyMap()

    DevLog("Refresh: inDelve=" .. tostring(inDelve) .. " tier=" .. tier
        .. " minLevel=" .. minLevel .. " meetsLevel=" .. tostring(meetsLevel)
        .. " hasMap=" .. tostring(hasMap))

    if inDelve and meetsLevel and hasMap then
        if not InCombatLockdown() then
            button:SetAttribute("item", itemName)
            if iconFileID then
                button:SetNormalTexture(iconFileID)
            end
        end
        button:Show()
    else
        if not InCombatLockdown() then
            button:Hide()
        end
    end
end

function LuckyGrabbag.DelveMap:ApplySetting()
    if button then
        Refresh()
    end
end

function LuckyGrabbag.DelveMap:Init(database)
    db = database

    button = CreateButton()
    RestorePosition()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            Refresh()
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            -- GetInstanceInfo() is often not ready yet when these fire during
            -- a loading screen. Refresh immediately (may catch it), then retry
            -- after a short delay to cover the late-availability case.
            Refresh()
            C_Timer.After(1, Refresh)
        else
            Refresh()
        end
    end)

    DevLog("Initialized")
end
