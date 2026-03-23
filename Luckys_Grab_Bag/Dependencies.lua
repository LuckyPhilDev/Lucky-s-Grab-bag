-- Lucky's Grab-bag: Generic addon dependency checker
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Dependencies = {}

local function parseVersion(str)
    local parts = {}
    for n in str:gmatch("%d+") do
        parts[#parts + 1] = tonumber(n)
    end
    return parts
end

local function isAtLeast(actual, minimum)
    local a = parseVersion(actual)
    local m = parseVersion(minimum)
    for i = 1, math.max(#a, #m) do
        local av = a[i] or 0
        local mv = m[i] or 0
        if av ~= mv then return av > mv end
    end
    return true
end

-- Returns true if an addon is installed and enabled, regardless of whether it has loaded yet.
function LuckyGrabbag.Dependencies.IsEnabled(addonName)
    local _, _, _, loadable = C_AddOns.GetAddOnInfo(addonName)
    return loadable == true
end

-- Checks whether an addon is loaded and meets an optional minimum version.
-- Returns: ok (bool), message (string | nil)
function LuckyGrabbag.Dependencies.Check(addonName, minVersion)
    local versionSuffix = minVersion and (" version " .. minVersion) or ""
    local failMessage = addonName .. versionSuffix .. " is required for this feature."

    if not C_AddOns.IsAddOnLoaded(addonName) then
        return false, failMessage
    end

    if minVersion then
        local actual = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
        if not isAtLeast(actual, minVersion) then
            return false, failMessage
        end
    end

    return true, nil
end
