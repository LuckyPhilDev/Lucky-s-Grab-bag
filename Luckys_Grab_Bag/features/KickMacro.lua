-- Lucky's Grab-bag: Create a class-appropriate kick macro in character slots
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.KickMacro = {}

local MAX_ACCOUNT_MACROS = 120

local MACRO_BODY = table.concat({
    "#showtooltip %s",
    "/cast [@focus,exists,nodead,harm] %s",
    "/stopmacro [@focus,exists,nodead,harm]",
    "/focus target",
    "/cleartarget",
    "/targetenemy",
    "/cast %s",
    "/target focus",
    "/clearfocus",
    "/startattack",
}, "\n")

local function GetInterruptSpell()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

    if classToken == "HUNTER" then
        -- Survival (255) uses Muzzle; Beast Mastery (253) and Marksmanship (254) use Counter Shot
        return (specID == 255) and "Muzzle" or "Counter Shot"
    elseif classToken == "WARLOCK" then
        -- Demonology (266) uses Axe Toss via Felguard; others use Spell Lock via Felhunter
        return (specID == 266) and "Axe Toss" or "Spell Lock"
    elseif classToken == "PRIEST" then
        -- Only Shadow (258) has an interrupt
        return (specID == 258) and "Silence" or nil
    end

    local spells = {
        WARRIOR     = "Pummel",
        PALADIN     = "Rebuke",
        ROGUE       = "Kick",
        SHAMAN      = "Wind Shear",
        MAGE        = "Counterspell",
        MONK        = "Spear Hand Strike",
        DRUID       = "Skull Bash",
        DEMONHUNTER = "Disrupt",
        DEATHKNIGHT = "Mind Freeze",
        EVOKER      = "Quell",
    }
    return spells[classToken]
end

local function MacroExists(name)
    local numGeneral, numCharacter = GetNumMacros()
    for i = 1, numGeneral do
        if GetMacroInfo(i) == name then return true end
    end
    for i = MAX_ACCOUNT_MACROS + 1, MAX_ACCOUNT_MACROS + numCharacter do
        if GetMacroInfo(i) == name then return true end
    end
    return false
end

function LuckyGrabbag.KickMacro:Create()
    local S = LuckyGrabbag.Strings
    local prefix = S.addon.prefix

    local spell = GetInterruptSpell()
    if not spell then
        print(prefix .. " " .. S.kickMacro.noInterrupt)
        return
    end

    if MacroExists("Kick") then
        print(prefix .. " " .. S.kickMacro.alreadyExists)
        return
    end

    local body = string.format(MACRO_BODY, spell, spell, spell)
    local idx = CreateMacro("Kick", "INV_Misc_QuestionMark", body, true)
    if not idx or idx == 0 then
        print(prefix .. " " .. S.kickMacro.slotsFull)
    else
        print(prefix .. " " .. string.format(S.kickMacro.created, spell))
    end
end
