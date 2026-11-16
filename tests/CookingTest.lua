local noop = function() end
local function frame()
    return setmetatable({ scripts = {} }, { __index = function(_, key)
        if key == 'petGUID' then return nil end
        if key == 'SetScript' then return function(self, event, fn) self.scripts[event] = fn end end
        if key == 'CreateTexture' then return function() return frame() end end
        return noop
    end })
end
local events, buttons = nil, {}
function CreateFrame() local f = frame(); events = events or f; return f end
UIParent, ProfessionsFrame = frame(), frame()
LuckyGrabbag = {
    Logger = function() return noop end,
    EnableGroupDrag = noop,
    CreateIconButton = function(opts) local f = frame(); buttons[opts.name] = f; return f end,
}
local petName = 2
C_PetJournal = {
    GetPetInfoBySpeciesID = function() return petName end,
    FindPetIDByName = function(name) assert(type(name) == 'string', 'Usage: FindPetIDByName("petName")'); return 1204, 'pet-guid' end,
    GetSummonedPetGUID = noop,
}
C_TradeSkillUI = { GetBaseProfessionInfo = function() return { professionID = 185 } end }
C_Spell = { GetSpellTexture = noop, GetSpellCooldown = noop }
C_Item = { GetItemIconByID = noop }
C_UnitAuras = { GetPlayerAuraBySpellID = noop }
function InCombatLockdown() return false end
dofile('src/features/CookingData.lua')
dofile('src/features/Cooking.lua')
LuckyGrabbag.Cooking:Init({ showCookingButtons = true })
events.scripts.OnEvent(events, 'TRADE_SKILL_DATA_SOURCE_CHANGED')
assert(buttons.LGB_PierreButton.petGUID == nil)
petName = 'Pierre'
events.scripts.OnEvent(events, 'COMPANION_UPDATE')
assert(buttons.LGB_PierreButton.petGUID == 'pet-guid')
print('Cooking: unavailable and available Pierre data handled')
