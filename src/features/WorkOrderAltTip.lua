-- Lucky's Grab-bag: Auto 1s tip on personal work orders to your own alts
-- When you submit a personal work order whose recipient matches a character in
-- LuckyRoster (same-realm name match), the tip is set to 1 silver automatically.
-- Dev logging + /lgbdump slash command help confirm the live Blizzard frame paths.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.WorkOrderAltTip = {}

local BLIZZARD_ADDON = "Blizzard_ProfessionsCustomerOrders"
local ONE_SILVER = 100  -- copper

local db
local form           -- ProfessionsCustomerOrdersFrame.Form, set on addon load
local hooked = false
local watcher        -- polling frame; recipient EditBox can be recreated by Blizzard
                     -- between events, leaving our HookScript on a dead instance.
local lastRecipient  -- text seen on last poll; only act on changes

local DevLog = LuckyGrabbag.Logger("WorkOrderAltTip")

-- ─── Roster lookup ───────────────────────────────────────────────────────────

local function MatchAltByName(name)
    if not name or name == "" then return nil end
    local lower = name:lower()

    local meName = (UnitName("player") or ""):lower()
    if lower == meName then return nil end

    local all = LuckyRoster and LuckyRoster:GetAll() or {}
    for key in pairs(all) do
        local n = key:match("^(.-)%-")
        if n and n:lower() == lower then
            return key
        end
    end
    return nil
end

-- ─── Form lookups ────────────────────────────────────────────────────────────

local function GetForm()
    return ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
end

local function GetTipFrame()
    local f = form or GetForm()
    local pc = f and f.PaymentContainer
    if not pc then return nil end
    -- Confirmed via /framestack: PaymentContainer.TipMoneyInputFrame is the silver/gold input.
    return pc.TipMoneyInputFrame or pc.Tip
end

-- Scan Form (and one level into common subframes) for EditBoxes. The personal-target
-- recipient field has shifted naming across patches, so we resolve it dynamically.
local function FindEditBoxes()
    local f = form or GetForm()
    local found = {}
    if not f then return found end

    local function scan(parent, prefix)
        if type(parent) ~= "table" then return end
        for k, v in pairs(parent) do
            if type(v) == "table" and type(v.GetObjectType) == "function" then
                local ok, ot = pcall(v.GetObjectType, v)
                if ok and ot == "EditBox" then
                    table.insert(found, { path = prefix .. "." .. tostring(k), frame = v, key = tostring(k) })
                end
            end
        end
    end

    scan(f, "Form")
    if f.PaymentContainer then scan(f.PaymentContainer, "Form.PaymentContainer") end
    if f.OrderInfoContainer then scan(f.OrderInfoContainer, "Form.OrderInfoContainer") end
    return found
end

-- The recipient field for a personal order. Prefers a known name, falls back to
-- "any editbox whose key contains Recipient/Target".
local function GetRecipientEditBox()
    local f = form or GetForm()
    if not f then return nil end

    local direct = f.RecipientNameEditBox or f.OrderRecipient or f.RecipientName
        or f.TargetName or f.TargetEditBox or f.RecipientEditBox
    if direct and direct.GetText then return direct, "direct" end

    for _, info in ipairs(FindEditBoxes()) do
        local k = info.key:lower()
        if k:find("recipient") or k:find("target") then
            return info.frame, info.path
        end
    end
    return nil
end

local function GetOrderType()
    local f = form or GetForm()
    if f and f.order and f.order.orderType then return f.order.orderType end
    local p = ProfessionsCustomerOrdersFrame
    if p and p.orderType then return p.orderType end
    return nil
end

local function GetRecipientText()
    local eb = GetRecipientEditBox()
    if eb then return eb:GetText() end
    local f = form or GetForm()
    if f and f.order and f.order.customerName then return f.order.customerName end
    return nil
end

-- ─── Apply ───────────────────────────────────────────────────────────────────

local function TrySetTip(reason)
    if not db or not db.autoTipAlt then return end

    local tip = GetTipFrame()
    if not tip then DevLog("Skip ("..reason.."): tip frame missing.") return end

    local orderType = GetOrderType()
    local personal = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Personal
    if orderType ~= personal then
        DevLog("Skip ("..reason.."): orderType="..tostring(orderType).." need Personal("..tostring(personal)..").")
        return
    end

    local name = GetRecipientText()
    local altKey = MatchAltByName(name)
    if not altKey then
        DevLog("Skip ("..reason.."): recipient '"..tostring(name).."' not an alt.")
        return
    end

    -- Try several APIs in order; TipMoneyInputFrame template varies by patch.
    -- We log every attempt outcome so we can see what stuck.
    local attempts = {
        { name = "tip:SetAmount",            fn = function() return tip.SetAmount and tip:SetAmount(ONE_SILVER) end },
        { name = "MoneyInputFrame_SetCopper", fn = function() return MoneyInputFrame_SetCopper and MoneyInputFrame_SetCopper(tip, ONE_SILVER) end },
        { name = "tip:SetCopper",            fn = function() return tip.SetCopper and tip:SetCopper(ONE_SILVER) end },
        { name = "SilverBox:SetNumber",      fn = function()
            if tip.SilverBox and tip.SilverBox.SetNumber then
                if tip.GoldBox  and tip.GoldBox.SetNumber  then tip.GoldBox:SetNumber(0) end
                if tip.CopperBox and tip.CopperBox.SetNumber then tip.CopperBox:SetNumber(0) end
                tip.SilverBox:SetNumber(1)
                return true
            end
        end },
    }

    for _, a in ipairs(attempts) do
        local ok, err = pcall(a.fn)
        DevLog(("attempt %s -> ok=%s err=%s"):format(a.name, tostring(ok), tostring(err)))
        if ok then
            DevLog("Set tip to 1s for alt "..altKey.." via "..a.name.." (reason="..reason..").")
            return
        end
    end
    DevLog("Failed to set tip for alt "..altKey..". Tip frame keys:")
    for k in pairs(tip) do DevLog("  tip."..tostring(k)) end
end

-- ─── Watcher ─────────────────────────────────────────────────────────────────

-- The recipient EditBox is rebuilt by Blizzard between order-type switches,
-- so OnTextChanged hooks installed earlier go stale. Poll once every 0.3s
-- while the form is visible and act on recipient transitions.
local function EnsureWatcher()
    if watcher then return end
    watcher = CreateFrame("Frame")
    watcher:Hide()
    local accum = 0
    local pollCount = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        accum = accum + elapsed
        if accum < 0.3 then return end
        accum = 0

        local f = form or GetForm()
        local shown = f and f:IsShown()
        if not shown then return end

        local eb, ebPath = GetRecipientEditBox()
        local ebText = eb and eb.GetText and eb:GetText() or nil
        local orderName = f and f.order and f.order.customerName or nil
        local text = ebText or orderName or ""

        pollCount = pollCount + 1
        if pollCount % 10 == 1 then
            DevLog(("poll: eb=%s ebText=%q orderName=%q orderType=%s")
                :format(tostring(ebPath), tostring(ebText), tostring(orderName), tostring(GetOrderType())))
        end

        if text == lastRecipient then return end
        lastRecipient = text
        DevLog("watcher: recipient changed to '"..tostring(text).."'")
        TrySetTip("watcher")
    end)
end

-- ─── Dev: dump full form structure ───────────────────────────────────────────

local function DumpFormStructure(label)
    local f = form or GetForm()
    if not f then DevLog("Dump ["..label.."]: form is nil.") return end

    DevLog("Dump ["..label.."]: orderType="..tostring(GetOrderType())
        ..", recipient='"..tostring(GetRecipientText()).."'")

    DevLog("  Form keys of interest:")
    for _, k in ipairs({
        "PaymentContainer", "OrderInfoContainer", "RecipientNameEditBox",
        "OrderRecipient", "RecipientName", "TargetName", "TargetEditBox",
        "RecipientEditBox", "RecipientDropdown", "OrderTypeRadioGroup", "order",
    }) do
        DevLog("    ."..k.." = "..tostring(f[k]))
    end

    if f.PaymentContainer then
        DevLog("  PaymentContainer keys:")
        for _, k in ipairs({
            "TipMoneyInputFrame", "Tip", "PostingFee", "Duration", "TotalPrice",
            "ListOrderButton", "NoteEditBox",
        }) do
            DevLog("    ."..k.." = "..tostring(f.PaymentContainer[k]))
        end
    end

    local ebs = FindEditBoxes()
    DevLog("  EditBoxes found ("..#ebs.."):")
    for _, info in ipairs(ebs) do
        local text = info.frame.GetText and info.frame:GetText() or "?"
        DevLog("    "..info.path.." text='"..tostring(text).."'")
    end

    local _, ebPath = GetRecipientEditBox()
    DevLog("  Recipient editbox resolved at: "..tostring(ebPath))
end

-- ─── Hooks ───────────────────────────────────────────────────────────────────

local function InstallHooks()
    if hooked then return end
    form = GetForm()
    if not form then DevLog("InstallHooks: form not ready, retrying.") C_Timer.After(0.2, InstallHooks) return end

    DumpFormStructure("install")
    EnsureWatcher()
    if form:IsShown() then watcher:Show() end

    -- Re-resolve and hook the recipient editbox whenever the form is shown,
    -- since some patches build it lazily on order-type change.
    local function HookRecipient()
        local eb = GetRecipientEditBox()
        if not eb or eb._lgbHooked then return end
        eb._lgbHooked = true
        eb:HookScript("OnTextChanged",   function() C_Timer.After(0, function() TrySetTip("recipient-text-changed") end) end)
        eb:HookScript("OnEditFocusLost", function() C_Timer.After(0, function() TrySetTip("recipient-focus-lost") end) end)
        DevLog("Hooked recipient editbox.")
    end
    HookRecipient()

    local p = ProfessionsCustomerOrdersFrame
    if p and p.SetCraftingOrderType then
        hooksecurefunc(p, "SetCraftingOrderType",
            function(_, ot) C_Timer.After(0, function()
                HookRecipient()
                TrySetTip("order-type-changed:"..tostring(ot))
            end) end)
        DevLog("Hooked ProfessionsCustomerOrdersFrame:SetCraftingOrderType.")
    end

    if form.Init then
        hooksecurefunc(form, "Init", function() C_Timer.After(0, function()
            HookRecipient()
            TrySetTip("form-init")
        end) end)
        DevLog("Hooked Form:Init.")
    end

    if form.HookScript then
        form:HookScript("OnShow", function()
            watcher:Show()
            C_Timer.After(0, function()
                HookRecipient()
                TrySetTip("form-shown")
            end)
        end)
        form:HookScript("OnHide", function() watcher:Hide() end)
        DevLog("Hooked Form:OnShow/OnHide.")
    end

    hooked = true
end

-- ─── Slash command ───────────────────────────────────────────────────────────

SLASH_LGBDUMP1 = "/lgbdump"
SlashCmdList["LGBDUMP"] = function()
    local wasDev = db and db.devMode
    if db then db.devMode = true end
    DumpFormStructure("slash")
    if db then db.devMode = wasDev end
end

-- ─── Init ────────────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == BLIZZARD_ADDON then
        DevLog(BLIZZARD_ADDON .. " loaded.")
        C_Timer.After(0, InstallHooks)
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end)

function LuckyGrabbag.WorkOrderAltTip:Init(database)
    db = database
    if C_AddOns and C_AddOns.IsAddOnLoaded(BLIZZARD_ADDON) then
        DevLog(BLIZZARD_ADDON .. " already loaded; installing hooks.")
        C_Timer.After(0, InstallHooks)
    end
end
