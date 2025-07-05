-- Core mod table must match the script filename in modDesc.xml
HelperProfiles = {}
local xmlFile = nil

-- Load XML profiles from user modSettings
function HelperProfiles:loadProfiles()
    local settingsDir = Utils.getUserProfileAppPath()
    local path = Utils.getFilename("modSettings/AIWorkerAvatars/workerProfiles.xml", settingsDir)
    xmlFile = loadXMLFile("WorkerProfiles", path)
end

-- Retrieve a worker name by zero-based index
function HelperProfiles:getWorkerName(index)
    return getXMLString(xmlFile, string.format("workerProfiles.worker(%d).n", index)) or "Helper"
end

-- Hook into helper creation to assign a name
function HelperProfiles:onCreateHelper(helper, profileIndex)
    self:loadProfiles()
    helper.name = self:getWorkerName(profileIndex)
end

-- Register the mod event listener (no '#' comments present)
addModEventListener(HelperProfiles)