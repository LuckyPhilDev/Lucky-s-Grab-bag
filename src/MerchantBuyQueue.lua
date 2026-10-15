LuckyGrabbag = LuckyGrabbag or {}

local BUY_THROTTLE = 0.5 -- seconds between purchases, below this the server reports the item busy

local buyQueue = {}
local buyTicker

local function StopBuying()
    if buyTicker then
        buyTicker:Cancel()
        buyTicker = nil
    end
end

--- BuyMerchantItem only buys one stack per call, and calls sent back to back
--- fail with "Item is busy", so orders go out as a spaced run of stack-sized
--- purchases. Spacing and approach follow BuyEmAll.
local function ProcessBuyQueue()
    local job = buyQueue[1]
    if not job or not MerchantFrame:IsShown() then
        wipe(buyQueue)
        StopBuying()
        return
    end

    local amount = math.min(job.remaining, job.perCall)
    BuyMerchantItem(job.index, amount)
    job.remaining = job.remaining - amount
    if job.remaining < 1 then table.remove(buyQueue, 1) end
    if #buyQueue == 0 then StopBuying() end
end

---@param index number merchant item index
---@param quantity number total items to buy
---@param perCall number most items one BuyMerchantItem call may buy
function LuckyGrabbag.QueueMerchantPurchase(index, quantity, perCall)
    buyQueue[#buyQueue + 1] = { index = index, remaining = quantity, perCall = perCall }
    if buyTicker then return end

    ProcessBuyQueue() -- the first purchase goes out now, the rest are spaced
    if #buyQueue > 0 then
        buyTicker = C_Timer.NewTicker(BUY_THROTTLE, ProcessBuyQueue)
    end
end
