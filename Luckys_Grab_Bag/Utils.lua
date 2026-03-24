-- Lucky's Grab-bag: Shared utilities
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.PREFIX = "|cff00cc00Lucky:|r"
local PREFIX = LuckyGrabbag.PREFIX

--- Dev logging via LuckyLog. Reads db.devMode from the shared namespace.
local _devLog = LuckyLog:New(PREFIX, function()
    local db = LuckyGrabbag.db
    return db and db.devMode
end)

---@param tag string
---@param msg string
function LuckyGrabbag.DevLog(tag, msg)
    _devLog("|cffaaaaaa[" .. tag .. "]|r " .. msg)
end

--- Creates a standard icon button with highlight texture and optional tooltip.
--- Button-specific attributes (SetAttribute, RegisterForClicks, etc.) are set by the caller after creation.
---@param opts table
---   opts.parent   (frame)        required
---   opts.name     (string|nil)   global frame name, or nil
---   opts.template (string|nil)   e.g. "SecureActionButtonTemplate", or nil for a plain Button
---   opts.size     (number|nil)   width/height in pixels; defaults to 42
---   opts.texture  (string|number|nil)  normal texture path or fileID
---   opts.tooltip  (function|nil) called inside OnEnter to populate GameTooltip (before :Show())
---@return Button
function LuckyGrabbag.CreateIconButton(opts)
    local btn = CreateFrame("Button", opts.name, opts.parent, opts.template)
    btn:SetSize(opts.size or 42, opts.size or 42)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:GetHighlightTexture():SetBlendMode("ADD") ---@diagnostic disable-line: param-type-mismatch
    if opts.texture then
        btn:SetNormalTexture(opts.texture)
    end
    if opts.tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            opts.tooltip(self)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return btn
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
