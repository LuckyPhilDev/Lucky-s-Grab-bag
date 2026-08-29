-- luacheck: globals C_AddOns LuckyDeps LuckyGrabbag CreateFrame BonusRollFrame

-- Covers who owns Auto-dismiss Bonus Roll when Lucky's Loot Wishlist is also
-- installed. The check runs off .toc metadata rather than a loaded table,
-- because Grab-bag inits on its own ADDON_LOADED and cannot rely on Wishlist
-- having loaded yet, and because a Wishlist too old to carry the feature must
-- not switch ours off.
--
-- Run from the addon root: lua tests/BonusRollHandoffTest.lua

local installed, blocksBonusRolls = false, nil

LuckyDeps = { IsEnabled = function(_, name)
    return name == "Luckys_Loot_Wishlist" and installed
end }

C_AddOns = { GetAddOnMetadata = function(name, field)
    if name ~= "Luckys_Loot_Wishlist" then return nil end
    if field ~= "X-BlocksBonusRolls" then return nil end
    return blocksBonusRolls
end }

function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

dofile("src/features/BonusRoll.lua")
local BR = LuckyGrabbag.BonusRoll
local passed = 0

local function check(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
    passed = passed + 1
end

installed, blocksBonusRolls = false, nil
check(BR.HandedOff(), false, "with no Wishlist installed, Grab-bag keeps the feature")

installed, blocksBonusRolls = false, "1"
check(BR.HandedOff(), false, "an uninstalled Wishlist cannot claim it, whatever its toc says")

installed, blocksBonusRolls = true, nil
check(BR.HandedOff(), false, "a Wishlist too old to declare the flag leaves the feature here")

installed, blocksBonusRolls = true, "1"
check(BR.HandedOff(), true, "a Wishlist that declares the flag takes it over")

print(string.format("BonusRollHandoff: %d checks passed", passed))
