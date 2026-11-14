-- luacheck: globals ContainerFrameCombinedBags GamepadBagBar IsUsingGamepad SmartNavigation
-- luacheck: globals SMART_NAV_INPUT_DIRECTION SmartNavigation_AddJumpNavigationOverride
-- luacheck: globals SmartNavigation_ClearJumpNavigationOverridesInDirection

if not LuckyUtils.IsForever() then return end

LuckyGrabbag.ControllerBags = {}
local selected, hooked = nil, false
local overrides = {}
local bag = ContainerFrameCombinedBags
local input = CreateFrame("Frame", nil, UIParent)
input:Hide()

local function clearOverrides()
    if InCombatLockdown() then return end
    for _, entry in ipairs(overrides) do
        local key = "smartNavigationOverride-" .. entry.direction.dirKey
        if entry.button[key] == entry.target then
            if entry.previous then
                SmartNavigation_AddJumpNavigationOverride(entry.button, entry.direction, entry.previous)
            else
                SmartNavigation_ClearJumpNavigationOverridesInDirection(entry.button, entry.direction)
            end
        end
    end
    wipe(overrides)
end

local function setGridOverrides(item)
    if not SMART_NAV_INPUT_DIRECTION or not SmartNavigation_AddJumpNavigationOverride then return end
    local x, y = item:GetCenter()
    if not x or not y then return end
    local left, right, leftDistance, rightDistance
    local up, down, upDistance, downDistance
    local function consider(candidate)
        if candidate ~= item and candidate:IsVisible() then
            local cx, cy = candidate:GetCenter()
            if cx and cy then
                local dx, dy = cx - x, cy - y
                if math.abs(dy) < item:GetHeight() / 2 then
                    if dx < -1 and (not leftDistance or -dx < leftDistance) then
                        left, leftDistance = candidate, -dx
                    elseif dx > 1 and (not rightDistance or dx < rightDistance) then
                        right, rightDistance = candidate, dx
                    end
                end
                if math.abs(dx) < item:GetWidth() / 2 then
                    if dy > 1 and (not upDistance or dy < upDistance) then
                        up, upDistance = candidate, dy
                    elseif dy < -1 and (not downDistance or -dy < downDistance) then
                        down, downDistance = candidate, -dy
                    end
                end
            end
        end
    end
    for _, candidate in ipairs(bag.Items or {}) do
        consider(candidate)
    end
    if GamepadBagBar then
        for _, candidate in ipairs(GamepadBagBar.BagButtonArray or {}) do
            consider(candidate)
        end
    end
    for _, pair in ipairs({ { SMART_NAV_INPUT_DIRECTION.LEFT, left }, { SMART_NAV_INPUT_DIRECTION.RIGHT, right },
        { SMART_NAV_INPUT_DIRECTION.UP, up }, { SMART_NAV_INPUT_DIRECTION.DOWN, down } }) do
        local direction, target = pair[1], pair[2]
        if direction and target then
            local key = "smartNavigationOverride-" .. direction.dirKey
            overrides[#overrides + 1] = { button = item, direction = direction, target = target, previous = item[key] }
            SmartNavigation_AddJumpNavigationOverride(item, direction, target)
        end
    end
end

local function refreshSelection()
    clearOverrides()
    local current = SmartNavigation and SmartNavigation:GetCurrentButton()
    selected = nil
    if input:IsShown() and SmartNavigation:GetActiveFrame() == bag then
        for _, item in ipairs(bag.Items or {}) do
            if item == current and item:IsVisible() then selected = item break end
        end
        if not selected and GamepadBagBar then
            for _, button in ipairs(GamepadBagBar.BagButtonArray or {}) do
                if button == current and button:IsVisible() then selected = button break end
            end
        end
    end
    if selected then
        if not InCombatLockdown() then setGridOverrides(selected) end
    end
end

local function refresh()
    local active = LuckyGrabbag.db and LuckyGrabbag.db.controllerBags and bag and bag:IsShown()
        and IsUsingGamepad() and not InCombatLockdown()
        and SmartNavigation and SmartNavigation.GetCurrentButton
    if active and not hooked then
        hooksecurefunc(SmartNavigation, "SelectButton", refreshSelection)
        hooked = true
    end
    input:SetShown(active)
    refreshSelection()
end

LuckyGrabbag.ControllerBags.ApplySetting = refresh

if bag then
    bag:HookScript("OnShow", refresh)
    bag:HookScript("OnHide", refresh)
end
input:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
input:RegisterEvent("PLAYER_REGEN_DISABLED")
input:RegisterEvent("PLAYER_REGEN_ENABLED")
input:SetScript("OnEvent", refresh)
