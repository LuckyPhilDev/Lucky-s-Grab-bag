-- luacheck: globals C_AddOns LuckyGrabbag print

-- Covers the What's New floor in Defaults.lua: it is derived from the .toc
-- version so nobody has to remember to bump it, which means the parsing has to
-- survive the version strings a release can actually carry.
--
-- Run from the addon root: lua tests/WhatsNewFloorTest.lua

local version = ""
C_AddOns = { GetAddOnMetadata = function() return version end }

local function floorFor(v)
    version = v
    LuckyGrabbag = nil
    dofile("src/Defaults.lua")
    return LuckyGrabbag.WHATS_NEW_MIN_VERSION
end

assert(floorFor("1.24.0") == "1.22.0", "two minors back, got " .. floorFor("1.24.0"))
assert(floorFor("1.23.1") == "1.21.0", "the patch number should not matter, got " .. floorFor("1.23.1"))
assert(floorFor("1.24") == "1.22.0", "a two part version should still read, got " .. floorFor("1.24"))

-- Early in a major there is nothing two minors back to reach for.
assert(floorFor("2.0.0") == "2.0.0", "a fresh major should highlight only itself, got " .. floorFor("2.0.0"))
assert(floorFor("2.1.0") == "2.0.0", "one minor in should reach back to the major, got " .. floorFor("2.1.0"))

-- A version string that cannot be read must not hide every badge, nor error.
assert(floorFor("") == "0.0.0", "an unreadable version should show everything")
assert(floorFor("nightly") == "0.0.0", "a non-numeric version should show everything")

print("WhatsNewFloor: all checks passed")
