-- HP_Compatibility.lua (FS25_HelperProfiles)
-- Central runtime guard for helper-roster mods that cannot safely coexist.

HP_Compatibility = HP_Compatibility or {
    checked = false,
    blocked = false,
    conflictMod = nil,
    warningLogged = false
}

local LOG = "[FS25_HelperProfiles/Compatibility] "
local CONFLICT_NAMES = {"FS25_HiredHelperTool", "HiredHelperTool"}

local function isLoadedByName(name)
    local loaded = rawget(_G, "g_modIsLoaded")
    if type(loaded) == "table" and loaded[name] == true then
        return true
    end

    if g_modManager ~= nil and type(g_modManager.getModByName) == "function" then
        local ok, mod = pcall(g_modManager.getModByName, g_modManager, name)
        if ok and type(mod) == "table" then
            return mod.isLoaded == true or mod.isActive == true or mod.isSelected == true
        end
    end

    return false
end

function HP_Compatibility:detect()
    self.checked = true
    self.blocked = false
    self.conflictMod = nil

    for _, name in ipairs(CONFLICT_NAMES) do
        if isLoadedByName(name) then
            self.blocked = true
            self.conflictMod = name
            break
        end
    end

    if self.blocked and not self.warningLogged then
        self.warningLogged = true
        print(LOG .. "HelperProfiles disabled for this session: incompatible mod detected (" .. tostring(self.conflictMod) .. "). Disable either HelperProfiles or Hired Helper Tool and reload the save.")
    end

    return self.blocked
end

function HP_Compatibility:isBlocked()
    if not self.checked then
        self:detect()
    end
    return self.blocked == true
end

function HP_Compatibility:getReason()
    if not self:isBlocked() then return nil end
    return "incompatible-helper-roster-mod:" .. tostring(self.conflictMod or "unknown")
end

function HP_Compatibility:loadMap()
    self.checked = false
    self.warningLogged = false
    self:detect()
end

function HP_Compatibility:deleteMap()
    self.checked = false
    self.blocked = false
    self.conflictMod = nil
    self.warningLogged = false
end

addModEventListener(HP_Compatibility)
