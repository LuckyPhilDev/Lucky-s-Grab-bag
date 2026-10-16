LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.LabyrinthDoors = {}

-- Every door is its own server-side choice, so doors are matched by the button they all share.
-- Doors with a known ID teach that button in the client's own language.
local KNOWN_DOOR_CHOICES = { [1065] = true, [1072] = true }
local ENGLISH_DOOR_BUTTON = "Enter Chamber\nContinue your run to gather more rewards."

local db
local DevLog = LuckyGrabbag.Logger("LabyrinthDoors")

local function DoorButton(info)
    local option = #info.options == 1 and info.options[1]
    local button = option and #option.buttons == 1 and option.buttons[1]
    if not button then return nil end
    local signature = button.text .. "\n" .. (button.tooltip or "")
    if KNOWN_DOOR_CHOICES[info.choiceID] then db.labyrinthDoorButton = signature end
    if signature == (db.labyrinthDoorButton or ENGLISH_DOOR_BUTTON) then return button end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_CHOICE_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if not db or not db.autoEnterLabyrinth then return end
    local info = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
    if not info then return end
    DevLog("Player choice %d: %s", info.choiceID, info.questionText)

    local button = DoorButton(info)
    if not button or button.disabled then return end
    -- The client, not the server, closes the window after a choice, so answer once it is up and close it as a click would.
    C_Timer.After(0, function()
        DevLog("Entering through response %d", button.id)
        C_PlayerChoice.SendPlayerChoiceResponse(button.id)
        if PlayerChoiceFrame and PlayerChoiceFrame:IsShown() then PlayerChoiceFrame:OnSelectionMade() end
    end)
end)

function LuckyGrabbag.LabyrinthDoors:Init(database)
    db = database
end
