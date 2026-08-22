-- Lucky's Grab-bag: Shift-click a set on the Appearances Sets tab to track
-- every appearance you're missing from it, matching the Items tab behavior.
-- Works by pre-hooking the mixin tables before buttons/tiles are created
-- (they are pooled and copy mixin methods at creation), so shift-click tracks
-- instead of selecting the set or applying the outfit. Covers the Collections
-- journal sets list (WardrobeSetsScrollFrameButtonMixin), BetterWardrobe's
-- copy of it, the transmog NPC set tiles (TransmogSetModelMixin /
-- BW_TransmogSetModelMixin), and the individual item models in the set
-- details pane (WardrobeSetsDetailsItemMixin).
--
-- Retired: Lucky's Wardrobe now does this itself, so nothing below
-- is installed. The hooks are kept intact in case that ever changes; flip the
-- flag and re-enable the setting in Settings.lua to bring the feature back.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.TransmogSets = {}

local MOVED_TO_BETTER_WARDROBE = true

local db

local DevLog = LuckyGrabbag.Logger("TransmogSets")

-- Returns nil on success, an Enum.ContentTrackingError otherwise.
-- StartTracking throws a hard Lua error on some untrackable sources, which is
-- why an unguarded loop used to abandon the rest of the set; the pcall keeps
-- one bad item from stopping the others.
local function StartTrackingSource(sourceID)
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    if not (sourceInfo and sourceInfo.playerCanCollect) then
        return Enum.ContentTrackingError.Untrackable
    end
    local ok, err = pcall(C_ContentTracking.StartTracking, Enum.ContentTrackingType.Appearance, sourceID)
    if not ok then
        DevLog("StartTracking threw for sourceID " .. tostring(sourceID) .. ": " .. tostring(err))
        return Enum.ContentTrackingError.Untrackable
    end
    return err
end

-- An appearance can have several sources (raid drop, vendor, quest, catalyst
-- result). When the given source can't be tracked, try the other sources of
-- the same visual before giving up.
local function StartTrackingOne(sourceID)
    local err = StartTrackingSource(sourceID)
    if err == nil then
        return nil
    end
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    local visualID = sourceInfo and sourceInfo.visualID
    local altSources = visualID and C_TransmogCollection.GetAllAppearanceSources(visualID)
    for _, altID in ipairs(altSources or {}) do
        if altID ~= sourceID then
            if C_ContentTracking.IsTracking(Enum.ContentTrackingType.Appearance, altID) then
                return nil
            end
            local altErr = StartTrackingSource(altID)
            if altErr == nil then
                DevLog("Tracked alternate source " .. altID .. " for untrackable " .. sourceID)
                return nil
            end
        end
    end
    return err
end

local function Track(appearances, name)
    if not appearances then
        DevLog("No appearance data for " .. tostring(name))
        return
    end

    local added, skipped, lastErr = 0, 0, nil
    for _, appearance in ipairs(appearances) do
        if not appearance.collected
            and not C_ContentTracking.IsTracking(Enum.ContentTrackingType.Appearance, appearance.appearanceID) then
            local err = StartTrackingOne(appearance.appearanceID)
            if err == nil then
                added = added + 1
            else
                skipped = skipped + 1
                lastErr = err
            end
        end
    end

    local S = LuckyGrabbag.Strings.transmogSets
    if added > 0 then
        local msg = string.format(added == 1 and S.trackedOne or S.trackedMany, added, name)
        if skipped > 0 then
            msg = msg .. " " .. string.format(S.skippedSuffix, skipped)
        end
        print(LuckyGrabbag.PREFIX .. " " .. msg)
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    elseif lastErr then
        ContentTrackingUtil.DisplayTrackingError(lastErr)
    else
        print(LuckyGrabbag.PREFIX .. " " .. string.format(S.nothingToTrack, name))
    end
end

-- The list row always carries the base setID. If that base set is the one
-- currently open in the details pane, the user may have a difficulty variant
-- (Heroic/Mythic) selected there; track that variant instead of the base.
local function ResolveVariant(baseSetID)
    local frames = { WardrobeCollectionFrame, BetterWardrobeCollectionFrame }
    for _, frame in ipairs(frames) do
        local sets = frame and frame.SetsCollectionFrame
        if sets and sets:IsVisible() and type(sets.GetSelectedSetID) == "function" then
            local selected = sets:GetSelectedSetID()
            if selected and selected ~= baseSetID then
                local info = C_TransmogSets.GetSetInfo(selected)
                if info and info.baseSetID == baseSetID then
                    return selected
                end
            end
        end
    end
    return baseSetID
end

local function TrackSetID(setID)
    setID = ResolveVariant(setID)
    local info = C_TransmogSets.GetSetInfo(setID)
    Track(C_TransmogSets.GetSetPrimaryAppearances(setID), info and info.name or setID)
end

-- Transmog NPC set tiles carry elementData with pre-fetched appearance data.
local function TrackTile(elementData)
    local setID = elementData.setID or (elementData.set and elementData.set.setID)
    local appearances = elementData.sourceData and elementData.sourceData.primaryAppearances
    if not appearances and setID then
        appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
    end
    local name = elementData.name or (elementData.set and elementData.set.name)
    if not name and setID then
        local info = C_TransmogSets.GetSetInfo(setID)
        name = info and info.name
    end
    Track(appearances, name or "")
end

local function ShiftTrackWanted(button)
    return db and db.trackTransmogSets and button == "LeftButton" and IsShiftKeyDown()
end

local function WrapMethod(mixin, method, label, handler)
    if type(mixin) ~= "table" or mixin.LuckyGrabbagSetTracking then return end
    local orig = mixin[method]
    if type(orig) ~= "function" then return end
    mixin[method] = function(self, button, ...)
        if ShiftTrackWanted(button) and handler(self) then
            return
        end
        return orig(self, button, ...)
    end
    mixin.LuckyGrabbagSetTracking = true
    DevLog("Wrapped " .. label .. "." .. method)
end

local function HandleTile(self)
    if not self.elementData then return false end
    TrackTile(self.elementData)
    return true
end

local function HandleListButton(self)
    if not self.setID then return false end
    TrackSetID(self.setID)
    return true
end

-- Individual item models in the set details pane. Stock shift-click there is
-- a chat link; keep that behavior when a chat edit box is open, track otherwise.
local function HandleDetailsItem(self)
    if not self.sourceID or ChatEdit_GetActiveWindow() then return false end
    local S = LuckyGrabbag.Strings.transmogSets
    local sourceInfo = C_TransmogCollection.GetSourceInfo(self.sourceID)
    local name = (sourceInfo and sourceInfo.name) or ("appearance " .. self.sourceID)
    if self.collected
        or C_ContentTracking.IsTracking(Enum.ContentTrackingType.Appearance, self.sourceID) then
        print(LuckyGrabbag.PREFIX .. " " .. string.format(S.itemAlready, name))
        return true
    end
    local err = StartTrackingOne(self.sourceID)
    if err then
        ContentTrackingUtil.DisplayTrackingError(err)
    else
        print(LuckyGrabbag.PREFIX .. " " .. string.format(S.trackedItem, name))
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    end
    return true
end

-- Stock transmog UI is load-on-demand and BetterWardrobe may load in any
-- order relative to us, so retry on every ADDON_LOADED. Wrapping is a cheap
-- no-op once done.
local function TryWrap()
    WrapMethod(BW_TransmogSetModelMixin, "OnMouseDown", "BW_TransmogSetModelMixin", HandleTile)
    WrapMethod(TransmogSetModelMixin, "OnMouseDown", "TransmogSetModelMixin", HandleTile)
    WrapMethod(WardrobeSetsScrollFrameButtonMixin, "OnClick", "WardrobeSetsScrollFrameButtonMixin", HandleListButton)
    WrapMethod(BetterWardrobeSetsScrollFrameButtonMixin, "OnClick", "BetterWardrobeSetsScrollFrameButtonMixin", HandleListButton)
    WrapMethod(WardrobeSetsDetailsItemMixin, "OnMouseDown", "WardrobeSetsDetailsItemMixin", HandleDetailsItem)
    WrapMethod(BetterWardrobeSetsDetailsItemMixin, "OnMouseDown", "BetterWardrobeSetsDetailsItemMixin", HandleDetailsItem)
end

function LuckyGrabbag.TransmogSets:Init(database)
    if MOVED_TO_BETTER_WARDROBE then return end
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", TryWrap)
    TryWrap()
end
