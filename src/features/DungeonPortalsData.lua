-- Lucky's Grab-bag: teleport spell for each dungeon that has one
LuckyGrabbag = LuckyGrabbag or {}

-- Keyed by Mythic+ challenge mode ID, because that is the only ID the client
-- will hand back a dungeon name for. The names in the comments are for reading
-- here; the map matches on the client's own localised name instead.
--
-- A list means the dungeon has more than one teleport: one per faction, or an
-- older spell alongside a re-issued one. Whichever the player knows wins.
LuckyGrabbag.DUNGEON_PORTAL_SPELLS = {
    -- Midnight
    [588] = 1286812, -- Altar of Fangs
    [586] = 1286807, -- Den of Nalorakk
    [558] = 1254572, -- Magister's Terrace
    [560] = 1254559, -- Maisara Caverns
    [587] = 1286809, -- Murder Row
    [559] = 1254563, -- Nexus-Point Xenas
    [584] = 1286801, -- The Blinding Vale
    [585] = 1286804, -- Voidscar Arena
    [557] = 1254400, -- Windrunner Spire

    -- The War Within
    [503] = 445417,  -- Ara-Kara, City of Echoes
    [506] = 445440,  -- Cinderbrew Meadery
    [502] = 445416,  -- City of Threads
    [504] = 445441,  -- Darkflame Cleft
    [542] = 1237215, -- Eco-Dome Al'dani
    [525] = 1216786, -- Operation: Floodgate
    [499] = 445444,  -- Priory of the Sacred Flame
    [505] = 445414,  -- The Dawnbreaker
    [500] = 445443,  -- The Rookery
    [501] = 445269,  -- The Stonevault

    -- Dragonflight
    [402] = 393273, -- Algeth'ar Academy
    [405] = 393267, -- Brackenhide Hollow
    [463] = 424197, -- Dawn of the Infinite
    [464] = 424197, -- Dawn of the Infinite
    [406] = 393283, -- Halls of Infusion
    [404] = 393276, -- Neltharus
    [399] = 393256, -- Ruby Life Pools
    [401] = 393279, -- The Azure Vault
    [400] = 393262, -- The Nokhud Offensive
    [403] = 393222, -- Uldaman: Legacy of Tyr

    -- Shadowlands
    [377] = 354468, -- De Other Side
    [378] = 354465, -- Halls of Atonement
    [375] = 354464, -- Mists of Tirna Scithe
    [379] = 354463, -- Plaguefall
    [380] = 354469, -- Sanguine Depths
    [381] = 354466, -- Spires of Ascension
    [391] = 367416, -- Tazavesh, the Veiled Market
    [392] = 367416, -- Tazavesh, the Veiled Market
    [376] = 354462, -- The Necrotic Wake
    [382] = 354467, -- Theater of Pain

    -- Battle for Azeroth
    [244] = 424187,  -- Atal'Dazar
    [245] = 410071,  -- Freehold
    [249] = 1286831, -- Kings' Rest
    [369] = 373274,  -- Operation: Mechagon
    [370] = 373274,  -- Operation: Mechagon
    [353] = { 445418, 464256 }, -- Siege of Boralus
    [250] = 1286828, -- Temple of Sethraliss
    [247] = { 467553, 467555 }, -- The MOTHERLODE!!
    [251] = 410074,  -- The Underrot
    [248] = 424167,  -- Waycrest Manor

    -- Legion
    [199] = 424153,  -- Black Rook Hold
    [210] = 393766,  -- Court of Stars
    [198] = 424163,  -- Darkheart Thicket
    [200] = 393764,  -- Halls of Valor
    [206] = 410078,  -- Neltharion's Lair
    [227] = 373262,  -- Return to Karazhan
    [234] = 373262,  -- Return to Karazhan
    [239] = 1254551, -- Seat of the Triumvirate

    -- Warlords of Draenor
    [164] = 159897, -- Auchindoun
    [163] = 159895, -- Bloodmaul Slag Mines
    [166] = 159900, -- Grimrail Depot
    [169] = 159896, -- Iron Docks
    [165] = 159899, -- Shadowmoon Burial Grounds
    [161] = { 159898, 1254557 }, -- Skyreach
    [168] = 159901, -- The Everbloom
    [167] = 159902, -- Upper Blackrock Spire

    -- Mists of Pandaria
    [57] = 131225, -- Gate of the Setting Sun
    [60] = 131222, -- Mogu'shan Palace
    [77] = 131231, -- Scarlet Halls
    [78] = 131229, -- Scarlet Monastery
    [76] = 131232, -- Scholomance
    [58] = 131206, -- Shado-Pan Monastery
    [59] = 131228, -- Siege of Niuzao Temple
    [56] = 131205, -- Stormstout Brewery
    [2]  = 131204, -- Temple of the Jade Serpent

    -- Cataclysm
    [507] = 445424, -- Grim Batol
    [456] = 424142, -- Throne of the Tides
    [438] = 410080, -- The Vortex Pinnacle

    -- Wrath of the Lich King
    [556] = 1254555, -- Pit of Saron
}

-- Raid teleports, keyed by Encounter Journal instance ID: raids have no
-- challenge mode ID, and their map pins carry the journal ID directly.
-- Spell IDs cross-checked between EnhanceQoL and LibOpenRaid; journal IDs for
-- The War Within confirmed from Plumber, the older two expansions from the
-- Encounter Journal's own numbering.
LuckyGrabbag.RAID_PORTAL_SPELLS = {
    -- The War Within
    [1296] = 1226482, -- Liberation of Undermine
    [1302] = 1239155, -- Manaforge Omega

    -- Dragonflight
    [1200] = 432254, -- Vault of the Incarnates
    [1208] = 432257, -- Aberrus, the Shadowed Crucible
    [1207] = 432258, -- Amirdrassil, the Dream's Hope

    -- Shadowlands
    [1190] = 373190, -- Castle Nathria
    [1193] = 373191, -- Sanctum of Domination
    [1195] = 373192, -- Sepulcher of the First Ones
}

-- Class teleports, keyed by class file name, each with the spot the spell
-- lands on its own zone map (normalized coordinates), so the badge can be
-- projected onto whichever map is open. A list of spells means one destination
-- with a spell per faction. Spell IDs and landing points cross-checked against
-- EnhanceQoL's teleport compendium and MDungeonTeleports.
--
-- Deliberately absent: a monk's Zen Pilgrimage and a druid's Dreamwalk land in
-- instances no browsable map can reach, and a shaman's Astral Recall has no
-- fixed destination at all.
LuckyGrabbag.CLASS_TELEPORTS = {}

-- Held back until their landing points are confirmed in game: neither badge
-- turned up where it should. Moonglade's coordinates are a guess, and Acherus
-- sits on its own instance map, which may not project onto the Broken Isles
-- at all. Move these into CLASS_TELEPORTS once each is verified.
--   DRUID:       { teleport = 18960, map = 80,  x = 0.5200, y = 0.4000 } Moonglade
--   DEATHKNIGHT: { teleport = 50977, map = 648, x = 0.2706, y = 0.2994 } Death Gate

LuckyGrabbag.CLASS_TELEPORTS.MAGE = {
    { teleport = 3561,    portal = 10059,   map = 84,   x = 0.4571, y = 0.9038 }, -- Stormwind
    { teleport = 3562,    portal = 11416,   map = 87,   x = 0.2551, y = 0.0914 }, -- Ironforge
    { teleport = 3565,    portal = 11419,   map = 62,   x = 0.4595, y = 0.1972 }, -- Darnassus (lands in Darkshore)
    { teleport = 32271,   portal = 32266,   map = 103,  x = 0.4787, y = 0.5900 }, -- Exodar
    { teleport = 3567,    portal = 11417,   map = 85,   x = 0.5265, y = 0.8984 }, -- Orgrimmar
    { teleport = 3563,    portal = 11418,   map = 90,   x = 0.8110, y = 0.2105 }, -- Undercity
    { teleport = 3566,    portal = 11420,   map = 88,   x = 0.4667, y = 0.4921 }, -- Thunder Bluff
    { teleport = 32272,   portal = 32267,   map = 110,  x = 0.7214, y = 0.5997 }, -- Silvermoon
    { teleport = { 33690, 35715 }, portal = { 33691, 35717 },
      map = 111, x = 0.5528, y = 0.3909 },                                        -- Shattrath
    { teleport = 49359,   portal = 49360,   map = 70,   x = 0.6628, y = 0.4828 }, -- Theramore
    { teleport = 49358,   portal = 49361,   map = 51,   x = 0.4703, y = 0.5505 }, -- Stonard
    { teleport = 53140,   portal = 53142,   map = 125,  x = 0.2372, y = 0.4670 }, -- Dalaran, Northrend
    { teleport = 88342,   portal = 88345,   map = 245,  x = 0.7357, y = 0.6079 }, -- Tol Barad (Alliance)
    { teleport = 88344,   portal = 88346,   map = 245,  x = 0.5480, y = 0.7819 }, -- Tol Barad (Horde)
    { teleport = 132621,  portal = 132620,  map = 1530, x = 0.8637, y = 0.6319 }, -- Vale of Eternal Blossoms (Alliance)
    { teleport = 132627,  portal = 132626,  map = 1530, x = 0.6186, y = 0.2213 }, -- Vale of Eternal Blossoms (Horde)
    { teleport = 176248,  portal = 176246,  map = 622,  x = 0.4715, y = 0.4759 }, -- Stormshield
    { teleport = 176242,  portal = 176244,  map = 624,  x = 0.5217, y = 0.4921 }, -- Warspear
    { teleport = 224869,  portal = 224871,  map = 627,  x = 0.6042, y = 0.4440 }, -- Dalaran, Broken Isles
    { teleport = 281403,  portal = 281400,  map = 1161, x = 0.6960, y = 0.1996 }, -- Boralus
    { teleport = 281404,  portal = 281402,  map = 1165, x = 0.4978, y = 0.4114 }, -- Dazar'alor
    { teleport = 344587,  portal = 344597,  map = 1670, x = 0.5229, y = 0.7460 }, -- Oribos
    { teleport = 395277,  portal = 395289,  map = 2112, x = 0.5432, y = 0.4788 }, -- Valdrakken
    { teleport = 446540,  portal = 446534,  map = 2339, x = 0.4249, y = 0.2905 }, -- Dornogal
    { teleport = 1259190, portal = 1259194, map = 2393, x = 0.5279, y = 0.6556 }, -- Silvermoon City
}

-- The Abundance event in Quel'Thalas: the active site shows as one of these
-- area POIs, and Dundun's Abundant Travel Method teleports straight to it.
LuckyGrabbag.ABUNDANCE_POI_IDS = {
    [8671] = true, -- Zul'Aman Skinning Den
    [8672] = true, -- Eversong Enchanting Crypt
    [8675] = true, -- Voidstorm Voidburrow
    [8676] = true, -- Harandar Herbalism Grotto
}
LuckyGrabbag.ABUNDANCE_TRAVEL_TOY_ID = 266370 -- Dundun's Abundant Travel Method
