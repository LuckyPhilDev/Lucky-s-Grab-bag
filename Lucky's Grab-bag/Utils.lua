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
