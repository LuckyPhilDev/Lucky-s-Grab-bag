-- luacheck: globals CreateFrame C_Timer C_CVar C_PartyInfo Enum GetTime GameTooltip GetInstanceInfo IsInInstance
-- luacheck: globals IsInGroup IsInRaid InCombatLockdown UnitIsGroupLeader UnitIsGroupAssistant LuckyGrabbag
-- luacheck: globals LuckySettings LuckyIcon SLASH_LGBCOMBATPREP1 SlashCmdList
--
-- Run from the addon root: lua tests/CombatPrepCountdownTest.lua

local function Stub()
    return setmetatable({}, { __index = function(self, key)
        if key == "SetText" then return function(s, text) s.text = text end end
        return function() return Stub() end
    end })
end

local now, timers, onEvent = 100, {}, nil
GetTime = function() return now end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
CreateFrame = function()
    local frame = Stub()
    frame.SetScript = function(_, script, fn) if script == "OnEvent" then onEvent = fn end end
    return frame
end
GameTooltip = { GetOwner = function() return nil end }
C_CVar = { GetCVar = function() return "0" end }
C_PartyInfo = { DoCountdown = function() end }
Enum = { PingTargetOption = { All = 0 } }
GetInstanceInfo = function() return nil, "party" end
IsInInstance = function() return true, "party" end
IsInGroup, IsInRaid, InCombatLockdown = function() return true end, function() return false end, function() return false end
UnitIsGroupLeader, UnitIsGroupAssistant = function() return true end, function() return false end
LuckyIcon = function(name) return "shared\\" .. name end
SlashCmdList = {}
LuckySettings = { Rich = {
    Theme = setmetatable({ warn = { 0.8, 0.3, 0.3 } }, { __index = function() return { 1, 1, 1, 1 } end }),
    FillBg = Stub, EdgeRule = Stub,
} }
LuckyGrabbag = {
    Logger = function() return function() end end,
    GroupInstanceType = function() return "party" end,
    Strings = { combatPrep = setmetatable({ pingTargets = {}, cancelCaption = "Cancel" },
        { __index = function() return "%d" end }) },
}

dofile("src/features/CombatPrep.lua")
LuckyGrabbag.CombatPrep:Init({ showCombatPrep = true, combatPrepTimerMythic = 10, combatPrepBreakTimer = 5 })
local function tick(seconds)
    now = now + seconds
    for _, t in ipairs(timers) do
        if t.at <= now and not t.done then t.done = true; t.fn() end
    end
end

local function captionOf(tile) return tile.caption.text end

-- The window is file-local, so read it off ApplySetting's upvalue.
local pull, brk
local i = 1
while true do
    local name, value = debug.getupvalue(LuckyGrabbag.CombatPrep.ApplySetting, i)
    if not name then break end
    if name == "prepFrame" then pull, brk = value.pullTimerBtn, value.breakBtn end
    i = i + 1
end
assert(pull and brk, "found the tiles")

assert(captionOf(pull) == "10", "idle pull shows its length")

onEvent(nil, "START_PLAYER_COUNTDOWN", "guid", 10, 10)
assert(captionOf(pull) == "Cancel", "a running pull turns into cancel")
assert(captionOf(brk) == "5", "the break is untouched")

onEvent(nil, "CANCEL_PLAYER_COUNTDOWN", "guid")
assert(captionOf(pull) == "10", "cancelling puts the timer back")

onEvent(nil, "START_PLAYER_COUNTDOWN", "guid", 300, 300)
assert(captionOf(brk) == "Cancel" and captionOf(pull) == "10", "a long Blizzard countdown is the break")

onEvent(nil, "START_PLAYER_COUNTDOWN", "guid", 10, 10)
assert(captionOf(brk) == "5" and captionOf(pull) == "Cancel", "a pull replaces the fallback break")

tick(11)
assert(captionOf(pull) == "10", "the pull expires by itself")

io.write("CombatPrepCountdownTest passed\n")
