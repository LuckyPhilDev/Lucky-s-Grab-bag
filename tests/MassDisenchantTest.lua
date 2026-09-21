-- luacheck: globals C_Container C_Item C_Spell C_SpellBook C_Timer CreateFrame GameTooltip GetCVarBool InCombatLockdown IsResting LuckySettings UIParent UISpecialFrames LuckyUI

local bags = {
    [0] = {
        { hyperlink = "[Green Armor]", iconFileID = 1, classID = 4, quality = 2 },
        { hyperlink = "[Blue Weapon]", iconFileID = 2, classID = 2, quality = 3 },
        { hyperlink = "[Epic Armor]", iconFileID = 3, classID = 4, quality = 4 },
        { hyperlink = "[Bound Green]", iconFileID = 4, classID = 4, quality = 2, isBound = true },
        { hyperlink = "[Hearthstone]", iconFileID = 5, classID = 15, quality = 1 },
    },
}

C_Container = {
    GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end,
    GetContainerItemInfo = function(bag, slot)
        local item = bags[bag] and bags[bag][slot]
        return item and { hyperlink = item.hyperlink, iconFileID = item.iconFileID, isBound = item.isBound }
    end,
}

C_Item = {
    GetItemQualityByID = function(link)
        for _, item in ipairs(bags[0]) do
            if item.hyperlink == link then return item.quality end
        end
    end,
    GetItemInfoInstant = function(link)
        for _, item in ipairs(bags[0]) do
            if item.hyperlink == link then return nil, nil, nil, nil, nil, item.classID end
        end
    end,
}

C_Spell = { GetSpellName = function() return "Disenchant" end }
C_SpellBook = { ContainsAnyDisenchantSpell = function() return true end }
C_Timer = { After = function(_, callback) callback() end }
GetCVarBool = function() return true end
InCombatLockdown = function() return false end
IsResting = function() return true end

local lastHighlightedFrame
local Frame = {}
Frame.__index = Frame
function Frame:CreateTexture() return setmetatable({}, Frame) end
function Frame:CreateFontString() return setmetatable({}, Frame) end
function Frame:GetHighlightTexture() return setmetatable({}, Frame) end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:LockHighlight()
    self.highlighted = true
    lastHighlightedFrame = self
end
function Frame:Show() self.shown = true end
function Frame:UnlockHighlight() self.highlighted = false end
setmetatable(Frame, { __index = function() return function() end end })

local eventFrame
CreateFrame = function()
    local frame = setmetatable({ events = {} }, Frame)
    function frame:RegisterEvent(event)
        self.events[event] = true
        if event == "UNIT_SPELLCAST_SUCCEEDED" then eventFrame = self end
    end
    function frame:SetScript(script, callback) self[script] = callback end
    return frame
end

UIParent = setmetatable({}, Frame)
UISpecialFrames = {}
GameTooltip = setmetatable({}, Frame)
LuckyGrabbag = { Strings = { massDisenchant = {} } }
LuckySettings = { Rich = {
    Theme = { bg = {}, bg2 = {}, border = {}, accentLight = { 1, 1, 1 }, textDim = { 1, 1, 1 } },
    Font = "GameFontNormal",
    FillBg = function() end,
    EdgeRule = function() end,
} }
-- LuckyUI builds real frames in game; here every helper hands back a stub frame.
LuckyUI = {
    HEADER_HEIGHT = 32,
    BODY_FONT     = "font",
    Backdrop      = {},
    C             = setmetatable({}, { __index = function() return { 1, 1, 1, 1 } end }),
    CreateWindow  = function(name) return CreateFrame("Frame", name), CreateFrame("Frame") end,
    CreateHeader  = function() return CreateFrame("Frame") end,
    CreateButton  = function() return CreateFrame("Button") end,
    StyleButton   = function(button) return button end,
    CreateInput   = function() return CreateFrame("EditBox") end,
    CreateIconButton = function() return CreateFrame("Button") end,
}

dofile("src/features/MassDisenchant.lua")

local items = LuckyGrabbag.MassDisenchant:Scan()
assert(#items == 3, "uncommon and rare armor or weapons should be listed even when bound")
assert(items[1].link == "[Green Armor]", "green armor should be listed")
assert(items[2].link == "[Blue Weapon]", "blue weapon should be listed")
assert(items[3].link == "[Bound Green]", "bound green armor should be listed")
assert(LuckyGrabbag.MassDisenchant:DestroyMacro(items[1]) == "/cast Disenchant\n/use 0 1", "destroy macro should cast on the selected bag slot")
assert(LuckyGrabbag.MassDisenchant:DestroyClickTrigger() == "LeftButtonDown", "secure click should follow ActionButtonUseKeyDown")

local db = { massDisenchantAutoOpen = true }
LuckyGrabbag.MassDisenchant:Init(db)
assert(eventFrame.events.UNIT_SPELLCAST_SUCCEEDED, "successful casts should be watched")
LuckyGrabbag.MassDisenchant:Open()
local opened = 0
LuckyGrabbag.MassDisenchant.Open = function() opened = opened + 1 end
eventFrame.OnEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13262)
assert(opened == 1, "successful disenchant should open the window while rested")
assert(lastHighlightedFrame.highlighted, "successful disenchant should highlight the ready button")

IsResting = function() return false end
eventFrame.OnEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13262)
assert(opened == 1, "successful disenchant should not open the window outside a rested area")

IsResting = function() return true end
db.massDisenchantAutoOpen = false
eventFrame.OnEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13262)
assert(opened == 1, "successful disenchant should not open the window when disabled")

print("MassDisenchant: all checks passed")
