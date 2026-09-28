-- luacheck: globals CreateFrame C_Timer C_CVar C_PartyInfo Enum GetTime GameTooltip GetInstanceInfo IsInInstance
-- luacheck: globals IsInGroup IsInRaid InCombatLockdown UnitIsGroupLeader UnitIsGroupAssistant LuckyGrabbag
-- luacheck: globals LuckySettings LuckyIcon SLASH_LGBCOMBATPREP1 SlashCmdList time BigWigsLoader BigWigs3DB DBM
--
-- Run from the addon root: lua tests/CombatPrepCountdownTest.lua

local function Stub()
    return setmetatable({}, { __index = function(_, key)
        if key == "SetText" then return function(s, text) s.text = text end end
        return function() return Stub() end
    end })
end

local now, epoch, onEvent = 100, 1000000, nil
GetTime = function() return now end
time = function() return epoch end
C_Timer = { After = function() end, NewTicker = Stub }
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
    Strings = { combatPrep = setmetatable({ pingTargets = {}, cancelCaption = "Stop" },
        { __index = function() return "%d" end }) },
}

dofile("src/features/CombatPrep.lua")
local db = { showCombatPrep = true, combatPrepTimerMythic = 10, combatPrepBreakTimer = 5 }
LuckyGrabbag.CombatPrep:Init(db)

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

local function refresh() onEvent(nil, "GROUP_ROSTER_UPDATE") end
local function wait(seconds) now, epoch = now + seconds, epoch + seconds; refresh() end

assert(pull.caption.text == "10", "idle pull shows its length")

onEvent(nil, "START_PLAYER_COUNTDOWN", "guid", 10, 10)
assert(pull.caption.text == "Stop", "a running pull turns into stop")
assert(brk.caption.text == "5", "the break is untouched")
onEvent(nil, "CANCEL_PLAYER_COUNTDOWN", "guid")
assert(pull.caption.text == "10", "cancelling puts the timer back")

onEvent(nil, "START_PLAYER_COUNTDOWN", "guid", 300, 300)
assert(brk.caption.text == "Stop" and pull.caption.text == "10", "without a boss mod a long countdown is the break")
assert(db.combatPrepBreakEndsAt, "and it is saved to survive a reload")
onEvent(nil, "START_PLAYER_COUNTDOWN", "guid", 10, 10)
assert(brk.caption.text == "5" and pull.caption.text == "Stop", "a pull replaces the fallback break")
wait(11)
assert(pull.caption.text == "10", "the pull expires by itself")

BigWigsLoader, SlashCmdList["break"] = {}, function() end
BigWigs3DB = { breakTime = { epoch - 60, 300, "Leader", false } }
refresh()
assert(brk.caption.text == "Stop", "a BigWigs break already running is picked up")
BigWigs3DB.breakTime = nil
refresh()
assert(brk.caption.text == "5", "and cleared when BigWigs ends it")

BigWigsLoader, SlashCmdList["break"] = nil, nil
DBM = { CreateBreakTimer = function() end, Options = { RestoreSettingBreakTimer = "300/" .. (epoch - 60) } }
refresh()
assert(brk.caption.text == "Stop", "a DBM break already running is picked up")
wait(241)
assert(brk.caption.text == "5", "and expires by itself")

io.write("CombatPrepCountdownTest passed\n")
