-- Lucky's Grab-bag: Auto-spend profession knowledge to next perk.
-- When clicking a profession specialisation node, automatically purchase
-- additional ranks up to the next 5-point perk boundary.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.ProfessionSpendToPerk = {}

local db
local hooked = false

local DevLog = LuckyGrabbag.Logger("ProfessionSpendToPerk")

local function InstallHook()
    if hooked then return end
    if not ProfessionsSpecPathMixin then return end

    hooksecurefunc(ProfessionsSpecPathMixin, "PurchaseRank", function(self)
        if not db.spendToNextPerk then return end

        local skillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
        if not skillLineID then return end

        local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
        if not configID then return end

        local nodeID = self:GetNodeID()
        local pathInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if not pathInfo then return end

        local spend = 5 - ((pathInfo.ranksPurchased - 1) % 5)
        local safety = 5
        while spend > 0 and spend < 5 and safety > 0 do
            C_Traits.PurchaseRank(configID, nodeID)
            spend = spend - 1
            safety = safety - 1
        end
        DevLog("Auto-spent to next perk on node " .. nodeID)
    end)

    hooked = true
    DevLog("Hooked ProfessionsSpecPathMixin:PurchaseRank")
end

function LuckyGrabbag.ProfessionSpendToPerk:Init(database)
    db = database
    DevLog("Init called")

    if C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
        InstallHook()
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_Professions" then
            InstallHook()
        elseif event == "TRADE_SKILL_SHOW" then
            InstallHook()
        end
    end)
end
