-- Lucky's Grab-bag: online friends as plain text on screen
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.FriendsOverlay = {}

local FO = LuckyGrabbag.FriendsOverlay

local LINE_SPACING = 2
local REFRESH_DELAY = 0.2
local FONT_RETRY_DELAY = 0.1
local FONT_RETRIES = 20
local PLACEHOLDER_ALPHA = 0.25
local WOW_CLIENT = "WoW"
local LAUNCHER_CLIENTS = { App = true, BSAp = true }
local FOREVER_PROJECT_ID = 18
local FACTION_COLORS = { Alliance = "ff4a8cff", Horde = "ffe03c3c" }

local BUILTIN_FONTS = {
    { key = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata" },
    { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
    { key = "Fonts\\SKURRI_CYR.TTF",   label = "Skurri" },
    { key = "Fonts\\MORPHEUS_CYR.TTF", label = "Morpheus" },
}

local LOCK_ICON = "Interface\\AddOns\\Luckys_Grab_Bag\\media\\icons\\lock.tga"
local LOCK_SIZE = 16

local db, frame, backdrop, lockButton
local lines = {}
local refreshPending = false
local inCombat = false
local active = false
local classFileByName
local fontRetries = 0

local function ColorText(hex, text)
    return "|c" .. hex .. text .. "|r"
end

local function ClassFile(localizedClass)
    if not classFileByName then
        classFileByName = {}
        for file, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do classFileByName[name] = file end
        for file, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do classFileByName[name] = file end
    end
    return classFileByName[localizedClass]
end

local function ClassColor(localizedClass)
    return RAID_CLASS_COLORS[ClassFile(localizedClass) or ""]
end

local function LevelHex(level)
    local c = GetQuestDifficultyColor(level)
    return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

-- Early Forever builds report the Mainline project ID, so ours comes from LuckyUtils.
local function OwnProjectID()
    return LuckyUtils.IsForever() and FOREVER_PROJECT_ID or WOW_PROJECT_ID
end

local function GameLabel(game)
    local S = LuckyGrabbag.Strings.friendsOverlay
    if game.clientProgram ~= WOW_CLIENT then
        local presence = game.richPresence
        return presence and presence ~= "" and presence or game.clientProgram
    end
    if game.wowProjectID and game.wowProjectID ~= OwnProjectID() then
        return rawget(S.games, game.wowProjectID) or S.games.other
    end
end

-- A friend is { account?, name?, level?, class?, faction?, area?, game? }; the line
-- carries no colour codes when the whole of it is drawn in the friend's class colour.
function FO.FormatFriend(friend)
    local S = LuckyGrabbag.Strings.friendsOverlay
    local classColor = friend.class and ClassColor(friend.class)
    local classHex = classColor and classColor.colorStr
    local plain = db.friendsOverlayWholeLineClass and classColor ~= nil
    local function paint(hex, text)
        if plain or not hex then return text end
        return ColorText(hex, text)
    end
    local nameHex = db.friendsOverlayClassColors and classHex or nil

    local head
    if friend.account and friend.name then
        head = friend.account .. " - " .. paint(nameHex, friend.name)
    else
        head = friend.account or paint(nameHex, friend.name)
    end

    local fields = { head }
    local levelClass = {}
    if db.friendsOverlayShowLevel and friend.level and friend.level > 0 then
        local levelHex = db.friendsOverlayLevelColors and LevelHex(friend.level) or nil
        levelClass[#levelClass + 1] = paint(levelHex, tostring(friend.level))
    end
    if db.friendsOverlayShowClass and friend.class and friend.class ~= "" then
        levelClass[#levelClass + 1] = paint(nameHex, friend.class)
    end
    if #levelClass > 0 then fields[#fields + 1] = table.concat(levelClass, " ") end
    if db.friendsOverlayShowFaction and FACTION_COLORS[friend.faction] then
        local letter = friend.faction == "Alliance" and S.alliance or S.horde
        fields[#fields + 1] = paint(db.friendsOverlayFactionColors and FACTION_COLORS[friend.faction], letter)
    end
    if db.friendsOverlayShowLocation and friend.area and friend.area ~= "" then
        fields[#fields + 1] = friend.area
    end
    if db.friendsOverlayShowGame and friend.game then
        fields[#fields + 1] = friend.game
    end
    return table.concat(fields, ", "), plain and classColor
end

local function BNetFriends(out)
    local _, numOnline = BNGetNumFriends()
    for i = 1, numOnline or 0 do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        local game = info and info.gameAccountInfo
        local inGame = game and game.isOnline
            and (db.friendsOverlayShowOutOfGame or not LAUNCHER_CLIENTS[game.clientProgram])
        if inGame then
            local inWoW = game.clientProgram == WOW_CLIENT and game.characterName
            out[#out + 1] = {
                account = info.accountName ~= "" and info.accountName or info.battleTag,
                name    = inWoW and game.characterName or nil,
                level   = inWoW and game.characterLevel or nil,
                class   = inWoW and game.className or nil,
                faction = inWoW and game.factionName or nil,
                area    = inWoW and game.areaName or nil,
                game    = GameLabel(game),
                favorite = info.isFavorite,
            }
        end
    end
end

local function CharacterFriends(out)
    local faction = UnitFactionGroup("player")
    for i = 1, C_FriendList.GetNumOnlineFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            out[#out + 1] = {
                name    = info.name,
                level   = info.level,
                class   = info.className,
                faction = faction,
                area    = info.area,
            }
        end
    end
end

local function CollectFriends()
    local list = {}
    local bnetFirst = db.friendsOverlayOrder ~= "characterFirst"
    if bnetFirst and db.friendsOverlayShowBNet then BNetFriends(list) end
    if db.friendsOverlayShowCharacter then CharacterFriends(list) end
    if not bnetFirst and db.friendsOverlayShowBNet then BNetFriends(list) end
    return list
end

-- Favourites claim places first, but the kept friends stay in the chosen order.
function FO.Limit(friends, max)
    if #friends <= max then return friends end
    local keep, kept = {}, 0
    for pass = 1, 2 do
        for i, friend in ipairs(friends) do
            if kept < max and not keep[i] and (pass == 2 or friend.favorite) then
                keep[i], kept = true, kept + 1
            end
        end
    end
    local limited = {}
    for i, friend in ipairs(friends) do
        if keep[i] then limited[#limited + 1] = friend end
    end
    return limited
end

local function GetLine(i)
    local line = lines[i]
    if not line then
        line = frame:CreateFontString(nil, "OVERLAY")
        line:SetJustifyH("LEFT")
        lines[i] = line
    end
    return line
end

local function Render()
    local c = db.friendsOverlayColor
    local friends = FO.Limit(CollectFriends(), db.friendsOverlayMax)
    local shown = #friends
    local placeholder = shown == 0 and db.friendsOverlayUnlocked
    if placeholder then shown = 1 end

    local fontLoading = false
    local width, height = 1, 0
    for i = 1, shown do
        local line = GetLine(i)
        -- SetFont fails while a font file loads on first use, and for a SharedMedia
        -- font whose addon is gone; Refresh retries in case it is the first.
        if not line:SetFont(db.friendsOverlayFont, db.friendsOverlaySize, "") then
            line:SetFont(BUILTIN_FONTS[1].key, db.friendsOverlaySize, "")
            fontLoading = true
        end
        line:SetShadowOffset(1, -1)
        line:SetShadowColor(0, 0, 0, db.friendsOverlayShadow and 1 or 0)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 0, -height)
        if placeholder then
            line:SetText(LuckyGrabbag.Strings.friendsOverlay.placeholder)
            line:SetTextColor(c.r, c.g, c.b, PLACEHOLDER_ALPHA)
        else
            local text, lineColor = FO.FormatFriend(friends[i])
            line:SetText(text)
            if lineColor then
                line:SetTextColor(lineColor.r, lineColor.g, lineColor.b)
            else
                line:SetTextColor(c.r, c.g, c.b)
            end
        end
        line:Show()
        width = math.max(width, line:GetStringWidth())
        height = height + line:GetStringHeight() + LINE_SPACING
    end
    for i = shown + 1, #lines do lines[i]:Hide() end
    frame:SetSize(width, math.max(height, 1))
    return fontLoading
end

local function ShouldShow()
    return db.friendsOverlay and not (inCombat and db.friendsOverlayHideInCombat)
end

local function Refresh()
    refreshPending = false
    if not frame then return end
    frame:SetShown(ShouldShow())
    if not frame:IsShown() then return end
    local fontLoading = Render()
    if not fontLoading then
        fontRetries = 0
    elseif fontRetries < FONT_RETRIES then
        fontRetries = fontRetries + 1
        C_Timer.After(FONT_RETRY_DELAY, Refresh)
    end
end

-- Battle.net events arrive in bursts as friends zone, so a burst renders once.
local function QueueRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(REFRESH_DELAY, Refresh)
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    db.friendsOverlayPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function ApplyLock()
    local unlocked = db.friendsOverlayUnlocked
    frame:EnableMouse(unlocked)
    backdrop:SetShown(unlocked)
    lockButton:SetShown(unlocked)
end

local function CreateOverlay()
    frame = CreateFrame("Frame", "LuckyGrabbagFriendsOverlay", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        SavePosition()
    end)

    local pos = db.friendsOverlayPos
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("LEFT", UIParent, "LEFT", 20, 100)
    end

    backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetPoint("TOPLEFT", -4, 4)
    backdrop:SetPoint("BOTTOMRIGHT", 4, -4)
    backdrop:SetColorTexture(0, 0, 0, 0.4)

    local S = LuckyGrabbag.Strings.friendsOverlay
    lockButton = CreateFrame("Button", nil, frame)
    lockButton:SetSize(LOCK_SIZE, LOCK_SIZE)
    lockButton:SetPoint("TOPLEFT", backdrop, "TOPRIGHT", 4, 0)
    lockButton:SetNormalTexture(LOCK_ICON)
    lockButton:SetHighlightTexture(LOCK_ICON, "ADD")
    lockButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(S.lock)
        GameTooltip:AddLine(S.lockDesc, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lockButton:SetScript("OnLeave", GameTooltip_Hide)
    lockButton:SetScript("OnClick", function()
        GameTooltip_Hide()
        db.friendsOverlayUnlocked = false
        FO:Apply()
        LuckyGrabbag.Settings.panel:Refresh()
    end)
end

local eventFrame = CreateFrame("Frame")
local FRIEND_EVENTS = {
    "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
    "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED", "BN_DISCONNECTED", "PLAYER_LEVEL_UP",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        Refresh()
    else
        QueueRefresh()
    end
end)

function FO.FontOptions()
    local options, listed = {}, {}
    local function add(path, label)
        local file = path:lower()
        if listed[file] then return end
        listed[file] = true
        options[#options + 1] = { key = path, label = label }
    end
    for _, font in ipairs(BUILTIN_FONTS) do add(font.key, font.label) end
    -- SharedMedia registers the game's own fonts too, under its own names.
    local media = LibStub("LibSharedMedia-3.0", true)
    if media then
        for _, name in ipairs(media:List("font")) do add(media:Fetch("font", name), name) end
    end
    return options
end

function FO:Apply()
    if not db.friendsOverlay then
        eventFrame:UnregisterAllEvents()
        active = false
        if frame then frame:Hide() end
        return
    end
    if not active then
        active = true
        if not frame then CreateOverlay() end
        for _, event in ipairs(FRIEND_EVENTS) do eventFrame:RegisterEvent(event) end
        inCombat = InCombatLockdown()
        C_FriendList.ShowFriends()
    end
    ApplyLock()
    frame:SetAlpha(db.friendsOverlayOpacity / 100)
    fontRetries = 0
    Refresh()
end

function FO:Init(database)
    db = database
    if db.friendsOverlay then
        local loginFrame = CreateFrame("Frame")
        loginFrame:RegisterEvent("PLAYER_LOGIN")
        loginFrame:SetScript("OnEvent", function()
            loginFrame:UnregisterAllEvents()
            FO:Apply()
        end)
    end
end
