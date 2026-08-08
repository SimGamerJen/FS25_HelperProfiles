-- HP_TabbedManagement.lua (FS25_HelperProfiles)
-- Presents appearance, roster and world-worker management dialogs as one
-- three-tab management workflow while preserving staged changes between tabs.

if HP_TabbedManagement ~= nil then return end

HP_TabbedManagement = {
    installed = false,
    sessionId = 0,
    openFromTab = {
        appearance = false,
        roster = false,
        world = false
    }
}

local LOG = "[FS25_HelperProfiles/TabbedManagement] "
local function hpPrint(message) print(LOG .. tostring(message)) end

local function configureTabs(screen, activeIndex)
    if screen == nil then return end

    if screen.managementTabs ~= nil then
        for index, tab in pairs(screen.managementTabs) do
            if tab ~= nil then
                local selected = index == activeIndex
                local background = tab.getDescendantByName ~= nil
                    and tab:getDescendantByName("background") or nil

                if background ~= nil then background.getIsSelected = function() return selected end end
                tab.getIsSelected = function() return selected end
                if tab.invalidateLayout ~= nil then tab:invalidateLayout() end
            end
        end
    end

    if screen.managementTabBox ~= nil and screen.managementTabBox.invalidateLayout ~= nil then
        screen.managementTabBox:invalidateLayout()
    end
end

local function beginOpen(tabName, fromTab)
    local isTabSwitch = fromTab == true
    if not isTabSwitch then HP_TabbedManagement.sessionId = HP_TabbedManagement.sessionId + 1 end
    HP_TabbedManagement.openFromTab[tabName] = isTabSwitch
end

local function shouldResume(screen, tabName)
    local fromTab = HP_TabbedManagement.openFromTab[tabName] == true
    HP_TabbedManagement.openFromTab[tabName] = false
    return fromTab
        and screen._hpTabbedDataLoaded == true
        and screen._hpTabbedSessionId == HP_TabbedManagement.sessionId
end

local function markLoaded(screen)
    screen._hpTabbedDataLoaded = true
    screen._hpTabbedSessionId = HP_TabbedManagement.sessionId
end

local function openAppearance(screen)
    if HP_AppearanceBindingsGui == nil or HP_AppearanceBindingsGui.open == nil then return end
    screen:close()
    HP_AppearanceBindingsGui:open(true)
end

local function openRoster(screen)
    if HP_RosterManagerGui == nil or HP_RosterManagerGui.open == nil then return end
    screen:close()
    HP_RosterManagerGui:open(true)
end

local function openWorld(screen)
    if HP_WorldWorkerGui == nil or HP_WorldWorkerGui.open == nil then return end
    screen:close()
    HP_WorldWorkerGui:open(true)
end

local function patchAppearanceScreen()
    local screenClass = HP_AppearanceBindingsScreen
    if screenClass == nil or screenClass._hpTabbedManagementPatched == true then return false end

    local originalSetup = screenClass.onGuiSetupFinished
    function screenClass:onGuiSetupFinished(...)
        originalSetup(self, ...)
        configureTabs(self, 1)
    end

    local originalOpen = screenClass.onOpen
    function screenClass:onOpen(...)
        local resume = shouldResume(self, "appearance")
        if resume then
            local originalReloadData = self.reloadData
            self.reloadData = function() end
            originalOpen(self, ...)
            self.reloadData = originalReloadData
            if self.reloadLists ~= nil then self:reloadLists() end
            if self.updateDetailText ~= nil then self:updateDetailText() end
        else
            originalOpen(self, ...)
        end
        markLoaded(self)
        configureTabs(self, 1)
    end

    function screenClass:onClickAppearanceTab(sender) configureTabs(self, 1) end
    function screenClass:onClickOpenRosterManager(sender) openRoster(self) end
    function screenClass:onClickOpenWorldManager(sender) openWorld(self) end

    screenClass._hpTabbedManagementPatched = true
    return true
end

local function patchRosterScreen()
    local screenClass = HP_RosterManagerScreen
    if screenClass == nil or screenClass._hpTabbedManagementPatched == true then return false end

    local originalSetup = screenClass.onGuiSetupFinished
    function screenClass:onGuiSetupFinished(...)
        originalSetup(self, ...)
        configureTabs(self, 2)
    end

    local originalOpen = screenClass.onOpen
    function screenClass:onOpen(...)
        local resume = shouldResume(self, "roster")
        if resume then
            local originalReloadData = self.reloadData
            self.reloadData = function() end
            originalOpen(self, ...)
            self.reloadData = originalReloadData
            if self.rosterTable ~= nil then self.rosterTable:reloadData() end
            if self.updateDetailText ~= nil then self:updateDetailText() end
        else
            originalOpen(self, ...)
        end
        markLoaded(self)
        configureTabs(self, 2)
    end

    function screenClass:onClickRosterTab(sender) configureTabs(self, 2) end
    function screenClass:onClickAppearances(sender) openAppearance(self) end
    function screenClass:onClickOpenWorldManager(sender) openWorld(self) end

    screenClass._hpTabbedManagementPatched = true
    return true
end

local function patchWorldScreen()
    local screenClass = HP_WorldWorkerScreen
    if screenClass == nil or screenClass._hpTabbedManagementPatched == true then return false end

    local originalSetup = screenClass.onGuiSetupFinished
    function screenClass:onGuiSetupFinished(...)
        originalSetup(self, ...)
        configureTabs(self, 3)
    end

    local originalOpen = screenClass.onOpen
    function screenClass:onOpen(...)
        originalOpen(self, ...)
        markLoaded(self)
        configureTabs(self, 3)
    end

    function screenClass:onClickWorldTab(sender) configureTabs(self, 3) end
    function screenClass:onClickAppearances(sender) openAppearance(self) end
    function screenClass:onClickRoster(sender) openRoster(self) end

    screenClass._hpTabbedManagementPatched = true
    return true
end

local function patchGuiManagers()
    if HP_AppearanceBindingsGui ~= nil
        and HP_AppearanceBindingsGui._hpTabbedManagementPatched ~= true
        and type(HP_AppearanceBindingsGui.open) == "function" then
        local originalOpen = HP_AppearanceBindingsGui.open
        function HP_AppearanceBindingsGui:open(fromTab)
            beginOpen("appearance", fromTab)
            return originalOpen(self)
        end
        HP_AppearanceBindingsGui._hpTabbedManagementPatched = true
    end

    if HP_RosterManagerGui ~= nil
        and HP_RosterManagerGui._hpTabbedManagementPatched ~= true
        and type(HP_RosterManagerGui.open) == "function" then
        local originalOpen = HP_RosterManagerGui.open
        function HP_RosterManagerGui:open(fromTab)
            beginOpen("roster", fromTab)
            return originalOpen(self)
        end
        HP_RosterManagerGui._hpTabbedManagementPatched = true
    end

    if HP_WorldWorkerGui ~= nil
        and HP_WorldWorkerGui._hpTabbedManagementPatched ~= true
        and type(HP_WorldWorkerGui.open) == "function" then
        local originalOpen = HP_WorldWorkerGui.open
        function HP_WorldWorkerGui:open(fromTab)
            beginOpen("world", fromTab)
            return originalOpen(self)
        end
        HP_WorldWorkerGui._hpTabbedManagementPatched = true
    end

    return HP_AppearanceBindingsGui ~= nil and HP_AppearanceBindingsGui._hpTabbedManagementPatched == true
        and HP_RosterManagerGui ~= nil and HP_RosterManagerGui._hpTabbedManagementPatched == true
        and HP_WorldWorkerGui ~= nil and HP_WorldWorkerGui._hpTabbedManagementPatched == true
end

function HP_TabbedManagement:update(dt)
    if self.installed then return end

    local appearanceReady = patchAppearanceScreen()
        or (HP_AppearanceBindingsScreen ~= nil and HP_AppearanceBindingsScreen._hpTabbedManagementPatched == true)
    local rosterReady = patchRosterScreen()
        or (HP_RosterManagerScreen ~= nil and HP_RosterManagerScreen._hpTabbedManagementPatched == true)
    local worldReady = patchWorldScreen()
        or (HP_WorldWorkerScreen ~= nil and HP_WorldWorkerScreen._hpTabbedManagementPatched == true)
    local managersReady = patchGuiManagers()

    if appearanceReady and rosterReady and worldReady and managersReady then
        self.installed = true
        hpPrint("Three-tab helper management workflow installed")
    end
end

addModEventListener(HP_TabbedManagement)
