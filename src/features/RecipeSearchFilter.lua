-- Lucky's Grab-bag: Limit recipe search results to the selected expansion.
-- While a search is active, Blizzard's recipe list ignores the expansion
-- selected in the Filter dropdown and shows matches from every expansion.
-- Wrapping the shared list builder restores the expansion check that the
-- search path skips, for both the crafting page and the crafting orders page.
-- An "All Expansions" radio injected at the top of the dropdown's expansion
-- list brings back the search-everything behaviour on demand.
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

local function InstallHook()
    if installed then return end
    if not (Professions and Professions.GenerateCraftingDataProvider) then return end

    local origGenerate = Professions.GenerateCraftingDataProvider
    local origGetIDs = C_TradeSkillUI.GetFilteredRecipeIDs
    local restrictTo -- child skill line ID, set only while a searching rebuild runs

    C_TradeSkillUI.GetFilteredRecipeIDs = function()
        local recipeIDs = origGetIDs()
        if not restrictTo then return recipeIDs end
        local filtered = {}
        for _, recipeID in ipairs(recipeIDs) do
            if C_TradeSkillUI.IsRecipeInSkillLine(recipeID, restrictTo) then
                filtered[#filtered + 1] = recipeID
            end
        end
        return filtered
    end

    Professions.GenerateCraftingDataProvider = function(professionID, searching, ...)
        -- NPC crafting and Runeforging deliberately show everything, and
        -- Runeforging swaps in its own profession ID; leave both alone.
        if db.searchSelectedExpansionOnly and not db.searchAllExpansions and searching
            and not C_TradeSkillUI.IsNPCCrafting() and not C_TradeSkillUI.IsRuneforging() then
            restrictTo = professionID
        end
        local ok, result = pcall(origGenerate, professionID, searching, ...)
        restrictTo = nil
        if not ok then error(result, 0) end
        return result
    end

    installed = true
    DevLog("Wrapped Professions.GenerateCraftingDataProvider")
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
