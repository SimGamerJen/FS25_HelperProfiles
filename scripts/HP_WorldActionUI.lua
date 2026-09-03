-- HP_WorldActionUI.lua (FS25_HelperProfiles)
-- Alpha 5: expose validated world-worker movement behaviours in the WORLD UI.
--
-- This module deliberately does not implement locomotion. It is a thin UI
-- adapter over the proven Alpha4 COME/FOLLOW APIs, keeping movement ownership
-- in HP_WorldTargetNavigation / HP_WorldFollow / locomotion.

if HP_WorldWorkerScreen == nil then return end
if HP_WorldActionUI ~= nil then return end

HP_WorldActionUI = {
    version = "2.2.0.0-alpha5-world-actions-ui-1",
    installed = false
}

local UI = HP_WorldActionUI
local Screen = HP_WorldWorkerScreen
local LOG = "[FS25_HelperProfiles/WorldWorkerUI] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function getCanonicalId(row)
    if row == nil then return nil end
    if row.canonicalId ~= nil then return row.canonicalId end
    if HP_SlotRegistry ~= nil then return HP_SlotRegistry:canonicalId(row.stableIndex) end
    return string.format("helper%02d", math.floor(tonumber(row.stableIndex) or 0))
end

local function getFollowState(row)
    if row == nil or HP_WorldFollow == nil or HP_WorldFollow.followers == nil then return nil end
    local id = getCanonicalId(row)
    return id ~= nil and HP_WorldFollow.followers[id] or nil
end

local function getMotion(row)
    if row == nil or HP_WorldLocomotionPrototype == nil or HP_WorldLocomotionPrototype.motions == nil then return nil end
    local id = getCanonicalId(row)
    return id ~= nil and HP_WorldLocomotionPrototype.motions[id] or nil
end

local function getMovementStatus(row)
    local follow = getFollowState(row)
    if follow ~= nil then
        local mode = string.upper(tostring(follow.mode or "ACTIVE"))
        if mode == "MOVING" then return "FOLLOWING" end
        if mode == "WAITING" then return "FOLLOW / WAITING" end
        if mode == "BLOCKED" then return "FOLLOW / BLOCKED" end
        if mode == "OUT-OF-RANGE" then return "FOLLOW / OUT OF RANGE" end
        if mode == "PAUSED" then return "FOLLOW / PAUSED" end
        return "FOLLOW / " .. mode
    end

    local motion = getMotion(row)
    if motion ~= nil then
        local kind = string.lower(tostring(motion.navigationKind or motion.mode or "moving"))
        if kind == "come" then return "COMING HERE" end
        if kind == "goto" then return "MOVING / TARGET" end
        if kind == "follow" then return "FOLLOWING" end
        if kind == "curve" then return "MOVING / CURVE" end
        if kind == "straight" then return "MOVING / WALK" end
        return "MOVING"
    end

    return nil
end

local function setButtonDisabled(button, disabled)
    if button == nil then return end
    if button.setDisabled ~= nil then
        pcall(button.setDisabled, button, disabled == true)
    elseif button.setIsDisabled ~= nil then
        pcall(button.setIsDisabled, button, disabled == true)
    end
end

local function refresh(screen)
    if screen == nil then return end
    if screen.worldTable ~= nil then screen.worldTable:reloadData() end
    if screen.updateDetailText ~= nil then screen:updateDetailText() end
end

function UI:install()
    if self.installed then return true end

    local originalPopulate = Screen.populateCellForItemInSection
    function Screen:populateCellForItemInSection(list, section, index, cell, ...)
        originalPopulate(self, list, section, index, cell, ...)
        local row = self.rows ~= nil and self.rows[index] or nil
        local movement = getMovementStatus(row)
        if movement ~= nil and cell ~= nil and cell.getAttribute ~= nil then
            local worldState = cell:getAttribute("WorldState")
            if worldState ~= nil then worldState:setText(movement) end
        end
    end

    local originalDetail = Screen.updateDetailText
    function Screen:updateDetailText(...)
        originalDetail(self, ...)
        local row = self.getSelectedRow ~= nil and self:getSelectedRow() or nil
        local placed = row ~= nil and HP_WorldState ~= nil
            and HP_WorldState:getPlacement(row.stableIndex) ~= nil
        local following = getFollowState(row) ~= nil

        if self.followButton ~= nil then
            self.followButton:setText(following and "UNFOLLOW" or "FOLLOW")
            setButtonDisabled(self.followButton, not placed)
        end
        if self.comeHereButton ~= nil then
            self.comeHereButton:setText("COME HERE")
            setButtonDisabled(self.comeHereButton, not placed)
        end
    end

    function Screen:onClickComeHere(sender)
        local row = self.getSelectedRow ~= nil and self:getSelectedRow() or nil
        if row == nil then return end
        if HP_WorldTargetNavigation == nil then
            self.actionMessage = "Target navigation unavailable."
            refresh(self)
            return
        end

        -- COME HERE is a one-shot instruction. If this worker is currently in
        -- continuous FOLLOW, stop that intent first so the one-shot navigation
        -- request has unambiguous ownership.
        local followState = getFollowState(row)
        if followState ~= nil and HP_WorldFollow ~= nil then
            HP_WorldFollow:stop(row.stableIndex)
        end

        local ok, err = HP_WorldTargetNavigation:startCome(row.stableIndex)
        if ok then
            self.actionMessage = string.format("%s is coming to you.", tostring(row.displayName or row.slot or "Worker"))
        else
            self.actionMessage = string.format("COME HERE failed for %s: %s",
                tostring(row.displayName or row.slot or "Worker"), tostring(err or "unknown"))
        end
        refresh(self)
    end

    function Screen:onClickFollowToggle(sender)
        local row = self.getSelectedRow ~= nil and self:getSelectedRow() or nil
        if row == nil then return end
        if HP_WorldFollow == nil then
            self.actionMessage = "Continuous follow unavailable."
            refresh(self)
            return
        end

        local following = getFollowState(row) ~= nil
        local ok, err
        if following then
            ok, err = HP_WorldFollow:stop(row.stableIndex)
            if ok then
                self.actionMessage = string.format("%s stopped following you.", tostring(row.displayName or row.slot or "Worker"))
            end
        else
            ok, err = HP_WorldFollow:start(row.stableIndex)
            if ok then
                self.actionMessage = string.format("%s is now following you.", tostring(row.displayName or row.slot or "Worker"))
            end
        end

        if not ok then
            self.actionMessage = string.format("%s failed for %s: %s",
                following and "UNFOLLOW" or "FOLLOW",
                tostring(row.displayName or row.slot or "Worker"), tostring(err or "unknown"))
        end
        refresh(self)
    end

    self.installed = true
    log("Loaded %s (WORLD UI COME HERE + FOLLOW/UNFOLLOW; live movement status)", tostring(self.version))
    return true
end

UI:install()
