-- HP_PayrollCost.lua (FS25_HelperProfiles)
-- Read-only projection of HelperPayroll snapshot costs for UI consumers.
-- In dailyPayroll mode this keeps completed-but-unpaid work visible and merges
-- any active job into the matching worker/day/farm payroll row without
-- double-applying call-out or minimum charges.

HP_PayrollCost = HP_PayrollCost or {}

local function upperSlot(value)
    if value == nil then return nil end
    local text = string.upper(tostring(value))
    return text ~= "" and text or nil
end

local function rowKey(row)
    local slot = upperSlot(row ~= nil and row.helperSlot or nil)
    if slot == nil then return nil, nil end

    return table.concat({
        slot,
        tostring(row.gameDate or "unknown"),
        tostring(row.farmId or "unknown")
    }, "|"), slot
end

local function round2(value)
    local number = tonumber(value) or 0
    return math.floor(number * 100 + 0.5) / 100
end

local function inferActiveMinimum(job, calloutFee)
    if job == nil or tostring(job.payBasis or "hourly") == "daily" then
        return 0
    end

    local labour = tonumber(job.labourEstimate) or 0
    local charge = tonumber(job.chargeEstimate) or 0
    local subtotal = labour + (tonumber(calloutFee) or 0)

    if charge > subtotal + 0.0001 then
        return charge
    end
    return 0
end

local function addCost(costs, slot, value)
    if slot == nil then return end
    local amount = tonumber(value)
    if amount == nil then return end
    costs[slot] = (tonumber(costs[slot]) or 0) + amount
end

local function activeOnlyCosts(snapshot)
    local costs = {}
    for _, job in ipairs(snapshot.activeJobs or {}) do
        addCost(costs, upperSlot(job ~= nil and job.helperSlot or nil), job ~= nil and job.chargeEstimate or nil)
    end
    for slot, value in pairs(costs) do costs[slot] = round2(value) end
    return costs
end

function HP_PayrollCost.getCostsBySlot(snapshot)
    if type(snapshot) ~= "table" then return {} end

    local policy = type(snapshot.policy) == "table" and snapshot.policy or {}
    if tostring(policy.billingMode or "onJobFinish") ~= "dailyPayroll" then
        return activeOnlyCosts(snapshot)
    end

    local calloutFee = tonumber(policy.calloutFee) or 0
    local legacyMinimum = tonumber(policy.legacyMinimum) or 0
    local groups = {}

    for _, pending in ipairs(snapshot.pendingPayroll or {}) do
        local key, slot = rowKey(pending)
        if key ~= nil then
            local charge = tonumber(pending.chargeEstimate) or 0
            local group = groups[key] or {
                slot = slot,
                payBasis = tostring(pending.payBasis or "hourly"),
                payRate = tonumber(pending.payRate) or 0,
                labour = 0,
                completedJobs = 0,
                activeJobs = 0,
                pendingCharge = 0,
                minimum = legacyMinimum,
                hasPending = false
            }

            group.hasPending = true
            group.labour = group.labour + (tonumber(pending.labour) or 0)
            group.completedJobs = group.completedJobs + (tonumber(pending.jobs) or 0)
            group.pendingCharge = group.pendingCharge + charge
            if pending.minimumApplied == true then
                group.minimum = math.max(group.minimum, charge)
            end
            groups[key] = group
        end
    end

    for _, job in ipairs(snapshot.activeJobs or {}) do
        local activeRows = {}
        if type(job.workSegments) == "table" and #job.workSegments > 0 then
            for _, segment in ipairs(job.workSegments) do
                table.insert(activeRows, {
                    helperSlot = job.helperSlot,
                    gameDate = segment.gameDate,
                    farmId = job.farmId,
                    payBasis = job.payBasis,
                    payRate = job.payRate,
                    labourEstimate = segment.labourEstimate,
                    chargeEstimate = segment.chargeEstimate
                })
            end
        else
            table.insert(activeRows, job)
        end

        for _, active in ipairs(activeRows) do
            local key, slot = rowKey(active)
            if key ~= nil then
                local group = groups[key] or {
                    slot = slot,
                    payBasis = tostring(active.payBasis or "hourly"),
                    payRate = tonumber(active.payRate) or 0,
                    labour = 0,
                    completedJobs = 0,
                    activeJobs = 0,
                    pendingCharge = 0,
                    minimum = legacyMinimum,
                    hasPending = false
                }

                group.activeJobs = group.activeJobs + 1
                if group.payBasis ~= "daily" then
                    group.labour = group.labour + (tonumber(active.labourEstimate) or 0)
                    group.minimum = math.max(group.minimum, inferActiveMinimum(active, calloutFee))
                elseif group.payRate <= 0 then
                    group.payRate = tonumber(active.payRate) or tonumber(active.chargeEstimate) or 0
                end
                groups[key] = group
            end
        end
    end

    local costs = {}
    for _, group in pairs(groups) do
        local charge
        if group.activeJobs <= 0 then
            charge = group.pendingCharge
        elseif group.payBasis == "daily" then
            charge = group.hasPending and group.pendingCharge or group.payRate
        else
            local subtotal = group.labour
            if (group.completedJobs + group.activeJobs) > 0 then
                subtotal = subtotal + calloutFee
            end
            charge = subtotal
            if charge > 0 and group.minimum > 0 and charge < group.minimum then
                charge = group.minimum
            end
        end
        addCost(costs, group.slot, charge)
    end

    for slot, value in pairs(costs) do costs[slot] = round2(value) end
    return costs
end
