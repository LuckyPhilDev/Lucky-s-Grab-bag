-- Lucky's Grab-bag: engine graphics settings WoW Forever has but its Graphics menu leaves out
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ForeverGraphics = {}

local FG = LuckyGrabbag.ForeverGraphics

-- Top ends go past Blizzard's Ultra preset on purpose; that headroom is what the group is for.
local OFF_LOW_HIGH = { { 0, "off" }, { 1, "low" }, { 2, "high" } }
local LOW_TO_ULTRA = { { 0, "low" }, { 1, "medium" }, { 2, "high" }, { 3, "ultra" } }
local OFF_TO_HIGH = { { 0, "off" }, { 1, "low" }, { 2, "medium" }, { 3, "high" } }

FG.SECTIONS = {
    { key = "distance", rows = {
        { cvar = "farclip",             kind = "Slider", min = 1000, max = 20000, step = 500 },
        { cvar = "horizonStart",        kind = "Slider", min = 400,  max = 10000, step = 200 },
        { cvar = "horizonClip",         kind = "Slider", min = 1600, max = 20000, step = 400 },
        { cvar = "disableHorizonStart", kind = "Toggle" },
    } },
    { key = "grass", rows = {
        { cvar = "groundEffectDensity", kind = "Slider", min = 16, max = 256, step = 8 },
        { cvar = "groundEffectDist",    kind = "Slider", min = 70, max = 500, step = 10 },
        { cvar = "groundEffectFade",    kind = "Slider", min = 70, max = 500, step = 10 },
    } },
    { key = "lighting", rows = {
        { cvar = "sunShafts",           kind = "Select", choices = OFF_LOW_HIGH },
        { cvar = "volumeFogLevel",      kind = "Select", choices = LOW_TO_ULTRA },
        { cvar = "shadowTextureSize",   kind = "Select", choices = { { 1024, "standard" }, { 2048, "sharp" } } },
        { cvar = "shadowNumCascades",   kind = "Slider", min = 1, max = 4 },
        { cvar = "shadowBlendCascades", kind = "Toggle" },
        { cvar = "shadowSoft",          kind = "Toggle" },
    } },
    { key = "water", rows = {
        { cvar = "waterDetail",         kind = "Select", choices = LOW_TO_ULTRA },
        { cvar = "reflectionMode",      kind = "Select", choices = LOW_TO_ULTRA },
        { cvar = "refraction",          kind = "Select", choices = OFF_LOW_HIGH },
        { cvar = "rippleDetail",        kind = "Select", choices = { { 0, "low" }, { 1, "medium" }, { 2, "high" } } },
    } },
    { key = "image", rows = {
        { cvar = "weatherDensity",        kind = "Select", choices = OFF_TO_HIGH },
        { cvar = "ResampleAlwaysSharpen", kind = "Toggle" },
        { cvar = "ffxGlow",               kind = "Toggle" },
        { cvar = "HDROutput",             kind = "Toggle" },
        { cvar = "HDRFactor",             kind = "Select", parent = "HDROutput",
          choices = { { 1, "hdrNone" }, { 1.2, "hdrSubtle" }, { 1.5, "hdrMedium" }, { 2, "hdrBlizzard" } } },
    } },
}

local db

-- Blizzard renames and drops these between Forever builds, so rows and saved values for unknown ones are skipped.
function FG.IsKnown(cvar)
    return C_CVar.GetCVarDefault(cvar) ~= nil
end

function FG.Get(cvar)
    return tonumber(C_CVar.GetCVar(cvar))
end

-- Each value is saved with the one it replaced, so Restore can put back what
-- Blizzard's own menu had set rather than the engine's bare default.
function FG.Set(cvar, value)
    if FG.Get(cvar) == value then return end
    local saved = db.foreverGraphics[cvar]
    if saved then
        saved.value = value
    else
        db.foreverGraphics[cvar] = { value = value, original = C_CVar.GetCVar(cvar) }
    end
    C_CVar.SetCVar(cvar, value)
end

function FG.Restore()
    for cvar, saved in pairs(db.foreverGraphics) do
        if FG.IsKnown(cvar) then C_CVar.SetCVar(cvar, saved.original) end
    end
    wipe(db.foreverGraphics)
end

-- Moving one of Blizzard's Graphics sliders rewrites several of these, so ours go back on at every login.
local function applySaved()
    for cvar, saved in pairs(db.foreverGraphics) do
        if FG.IsKnown(cvar) then C_CVar.SetCVar(cvar, saved.value) end
    end
end

function FG:Init(database)
    db = database
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function()
        frame:UnregisterAllEvents()
        applySaved()
    end)
end
