-- Lucky's Grab-bag: Shared utilities and UI helpers
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.PREFIX = LuckyGrabbag.Strings.addon.prefix

local function IsDevMode()
    local db = LuckyGrabbag.db
    return db and db.devMode
end

local _devLog = LuckyLog:New(LuckyGrabbag.PREFIX, IsDevMode)

--- Extra arguments are passed to msg:format() only when dev mode is on, so hot
--- paths can log without building strings for nobody.
---@param tag string
---@param msg string
function LuckyGrabbag.DevLog(tag, msg, ...)
    if not IsDevMode() then return end
    if select("#", ...) > 0 then msg = msg:format(...) end
    _devLog("|cffaaaaaa[" .. tag .. "]|r " .. msg)
end

--- Returns a DevLog bound to one feature's tag, for the one-liner at the top
--- of each feature file: local DevLog = LuckyGrabbag.Logger("FeatureName")
---@param tag string
---@return fun(msg: string, ...: any)
function LuckyGrabbag.Logger(tag)
    return function(msg, ...) LuckyGrabbag.DevLog(tag, msg, ...) end
end

local GROUP_INSTANCE_TYPES = { party = true, raid = true, scenario = true }

--- Instance type for windows that only make sense in group content, or nil
--- when the player is somewhere else. An allowlist, so new game modes stay out
--- until they are added deliberately.
---
--- GetInstanceInfo and IsInInstance can disagree, and hybrid content is where
--- it bites: a housing Decor Duel reports "pvp" from the first and "scenario"
--- from the second. Both have to agree before content counts.
---@return string|nil
function LuckyGrabbag.GroupInstanceType()
    local _, infoType = GetInstanceInfo()
    local _, inInstanceType = IsInInstance()
    if infoType ~= inInstanceType then return nil end
    return GROUP_INSTANCE_TYPES[infoType] and infoType or nil
end

-- opts: parent, name, template, size, texture, and tooltip(button) filling GameTooltip.
function LuckyGrabbag.CreateIconButton(opts)
    local tooltip = opts.tooltip
    return LuckyUI.CreateActionButton(opts.parent, {
        name     = opts.name,
        template = opts.template,
        size     = opts.size,
        texture  = opts.texture,
        tooltip  = tooltip and function(_, button) tooltip(button) end,
    })
end

--- Makes a container frame draggable via right-click on its child buttons.
--- Position is saved relative to an anchor frame so buttons follow the window.
---
--- After calling this, use `container:RegisterDraggable(button)` on each child.
--- Call `container:RestorePosition()` when the anchor frame is shown, to re-anchor
--- after the anchor moves (e.g. when the Auction House reopens).
---
---@param container Frame       the group container to move
---@param anchorFrame Frame     the window to anchor relative to (e.g. AuctionHouseFrame)
---@param dbKey string          key in LuckyGrabbagDB for the saved offset table {x, y}
---@param defaultX number       default x offset from anchor's TOPRIGHT
---@param defaultY number       default y offset from anchor's TOPRIGHT
function LuckyGrabbag.EnableGroupDrag(container, anchorFrame, dbKey, defaultX, defaultY)
    container:SetMovable(true)
    container:SetClampedToScreen(true)

    local function Restore()
        container:ClearAllPoints()
        local pos = LuckyGrabbag.db and LuckyGrabbag.db[dbKey]
        container:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT",
            pos and pos.x or defaultX,
            pos and pos.y or defaultY)
    end

    local function Save()
        if not LuckyGrabbag.db then return end
        local left = container:GetLeft()
        local top  = container:GetTop()
        local aRight = anchorFrame:GetRight()
        local aTop   = anchorFrame:GetTop()
        if left and top and aRight and aTop then
            LuckyGrabbag.db[dbKey] = { x = left - aRight, y = top - aTop }
        end
    end

    function container:RestorePosition()
        Restore()
    end

    function container:RegisterDraggable(button)
        button:RegisterForDrag("RightButton")
        button:HookScript("OnDragStart", function() container:StartMoving() end)
        button:HookScript("OnDragStop", function()
            container:StopMovingOrSizing()
            Save()
            Restore() -- re-anchor so the group continues to follow the window
        end)
    end

    Restore()
end
