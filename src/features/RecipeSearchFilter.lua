-- While searching, Blizzard's recipe list ignores the Filter dropdown's
-- expansion and shows matches from every expansion; this restores that check.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.RecipeSearchFilter = {}

local db
local installed = false

local DevLog = LuckyGrabbag.Logger("RecipeSearchFilter")

local function OnAllExpansionsSelected()
    db.searchAllExpansions = true
    -- Same refresh path Blizzard's expansion radios take; with an unchanged
    -- skill line it just rebuilds the recipe list.
    EventRegistry:TriggerEvent("Professions.SelectSkillLine", C_TradeSkillUI.GetChildProfessionInfo())
end

local function InjectAllExpansionsRadio(owner, rootDescription)
    if not db.searchSelectedExpansionOnly then return end

    local firstExpansionIndex
    for index, element in rootDescription:EnumerateElementDescriptions() do
        local data = element:GetData()
        if type(data) == "table" and data.expansionName and data.professionID then
            firstExpansionIndex = firstExpansionIndex or index

            -- Blizzard's radio for the open skill line stays dotted while "All
            -- Expansions" is active, so fold our state into its check.
            local blizzIsSelected = element.isSelected
            element:SetIsSelected(function(professionInfo)
                return not db.searchAllExpansions and blizzIsSelected(professionInfo)
            end)

            -- Clear our state before Blizzard's responder rebuilds the list,
            -- so picking an expansion filters immediately.
            local blizzResponder = element.responder
            element:SetResponder(function(...)
                db.searchAllExpansions = false
                if blizzResponder then return blizzResponder(...) end
            end)
        end
    end
    if not firstExpansionIndex then return end

    local radio = MenuUtil.CreateRadio(LuckyGrabbag.Strings.recipeSearchFilter.allExpansions,
        function() return db.searchAllExpansions end,
        OnAllExpansionsSelected)
    rootDescription:Insert(radio, firstExpansionIndex)
end

local function ShouldRestrict(recipeList)
    -- NPC crafting and Runeforging deliberately show everything, and
    -- Runeforging swaps in its own profession ID; leave both alone.
    return db.searchSelectedExpansionOnly and not db.searchAllExpansions
        and recipeList.SearchBox:HasText()
        and not C_TradeSkillUI.IsNPCCrafting() and not C_TradeSkillUI.IsRuneforging()
end

local function PruneOtherExpansions(node, skillLineID)
    local keptAny = false
    local children = node:GetNodes()
    for i = #children, 1, -1 do
        local child = children[i]
        local data = child:GetData()
        local keep = true
        if data.recipeInfo then
            keep = C_TradeSkillUI.IsRecipeInSkillLine(data.recipeInfo.recipeID, skillLineID)
        elseif data.categoryInfo then
            keep = PruneOtherExpansions(child, skillLineID)
        end
        if not keep then
            node:Remove(child, true)
        elseif data.recipeInfo or data.categoryInfo then
            keptAny = true
        end
    end
    return keptAny
end

-- Prune the list Blizzard built rather than replacing Blizzard's functions:
-- a replaced C_TradeSkillUI or Professions function taints every caller,
-- which spread to the action bars and broke cooldowns in combat.
local function HookRecipeList(page, recipeList)
    hooksecurefunc(recipeList.ScrollBox, "SetDataProvider", function(_, dataProvider)
        if not (page.professionInfo and ShouldRestrict(recipeList)) then return end
        PruneOtherExpansions(dataProvider:GetRootNode(), page.professionInfo.professionID)
        dataProvider:Invalidate()
    end)
end

local function InstallHook()
    if installed then return end
    if not ProfessionsFrame then return end

    HookRecipeList(ProfessionsFrame.CraftingPage, ProfessionsFrame.CraftingPage.RecipeList)
    HookRecipeList(ProfessionsFrame.OrdersPage, ProfessionsFrame.OrdersPage.BrowseFrame.RecipeList)

    installed = true
    DevLog("Hooked recipe list data providers")
end

function LuckyGrabbag.RecipeSearchFilter:Init(database)
    db = database
    DevLog("Init called")

    Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", InjectAllExpansionsRadio)

    InstallHook()
    if installed then return end

    local eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function()
        InstallHook()
        if installed then
            eventFrame:UnregisterAllEvents()
        end
    end)
    eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
    eventFrame:RegisterEvent("ADDON_LOADED")
end
