-- HP_Config.lua — external config for FS25_HelperProfiles overlay
-- Persists UI settings to:  <user>/modSettings/FS25_HelperProfiles/config.xml

HP_Config = {
    dir   = nil,
    path  = nil,
    _ver  = 1,
}

local function _userPath()
    if getUserProfileAppPath ~= nil then
        return getUserProfileAppPath()
    end
    return "" -- fallback (unlikely in-game)
end

local function _mkDir(path)
    if createFolder ~= nil then
        return createFolder(path)
    end
    -- fallback: try Lua I/O (will only work if FS allows; guarded anyway)
    local ok = os.execute and os.execute(string.format('mkdir "%s"', path)) or false
    return ok == true or ok == 0
end

local function _fileExists(path)
    if fileExists ~= nil then
        return fileExists(path)
    end
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

function HP_Config:init()
    if self.dir ~= nil then return end
    local base = _userPath() .. "modSettings/"
    local dir  = base .. "FS25_HelperProfiles/"
    if not _fileExists(dir) then _mkDir(base) ; _mkDir(dir) end
    self.dir  = dir
    self.path = dir .. "config.xml"
end

-- Defaults that mirror HP_UI’s internal defaults
function HP_Config:getDefaults()
    return {
        anchor      = HP_UI and HP_UI.anchor      or "TR",
        x           = HP_UI and HP_UI.x           or 0.985,
        y           = HP_UI and HP_UI.y           or 0.965,
        scale       = HP_UI and HP_UI.scale       or 1.0,
        width       = HP_UI and HP_UI.width       or 0.36,
        opacity     = HP_UI and HP_UI.opacity     or 0.85,
        pad         = HP_UI and HP_UI.pad         or 0.006,
        rowGap      = HP_UI and HP_UI.rowGap      or 0.006,
        fontSize    = HP_UI and HP_UI.fontSize    or 0.017,
        maxRows     = HP_UI and HP_UI.maxRows     or 10,
        bgEnabled   = HP_UI and HP_UI.bgEnabled   or true,
        outline     = HP_UI and HP_UI.outline     or false,
        shadow      = HP_UI and HP_UI.shadow      or true,
        showMarkers = HP_UI and HP_UI.showMarkers or true,
        bindHud     = HP_UI and HP_UI.bindHud     or true,
        version     = self._ver,
    }
end

function HP_Config:applyToUI(cfg)
    if not HP_UI or not cfg then return end
    HP_UI:setAnchor(cfg.anchor)
    HP_UI:setPos(cfg.x, cfg.y)
    if HP_UI.setWidth then HP_UI:setWidth(cfg.width) end
    HP_UI:setScale(cfg.scale)
    HP_UI:setOpacity(cfg.opacity)
    HP_UI:setPadding(cfg.pad)
    HP_UI:setRowGap(cfg.rowGap)
    HP_UI:setFontSize(cfg.fontSize)
    HP_UI:setMaxRows(cfg.maxRows)
    HP_UI:setBackground(cfg.bgEnabled)
    HP_UI:setOutline(cfg.outline)
    HP_UI.shadow      = cfg.shadow and true or false
    HP_UI.showMarkers = cfg.showMarkers and true or false
    HP_UI.bindHud     = cfg.bindHud and true or false
end

function HP_Config:read(pathOverride)
    self:init()
    local path = pathOverride or self.path
    if not _fileExists(path) then
        return nil, "missing"
    end
    if XMLFile == nil then
        return nil, "xml-api-missing"
    end
    local xml = XMLFile.load("hpCfgRead", path, "hp")
    if not xml then return nil, "load-failed" end

    local cfg = self:getDefaults()
    cfg.version     = xml:getInt("hp#version", cfg.version)

    cfg.anchor      = xml:getString("hp.ui#anchor", cfg.anchor)
    cfg.x           = xml:getFloat ("hp.ui#x",       cfg.x)
    cfg.y           = xml:getFloat ("hp.ui#y",       cfg.y)
    cfg.scale       = xml:getFloat ("hp.ui#scale",   cfg.scale)
    cfg.width       = xml:getFloat ("hp.ui#width",   cfg.width)
    cfg.opacity     = xml:getFloat ("hp.ui#opacity", cfg.opacity)
    cfg.pad         = xml:getFloat ("hp.ui#pad",     cfg.pad)
    cfg.rowGap      = xml:getFloat ("hp.ui#rowGap",  cfg.rowGap)
    cfg.fontSize    = xml:getFloat ("hp.ui#font",    cfg.fontSize)
    cfg.maxRows     = xml:getInt   ("hp.ui#maxRows", cfg.maxRows)
    cfg.bgEnabled   = xml:getBool  ("hp.ui#bg",      cfg.bgEnabled)
    cfg.outline     = xml:getBool  ("hp.ui#outline", cfg.outline)
    cfg.shadow      = xml:getBool  ("hp.ui#shadow",  cfg.shadow)
    cfg.showMarkers = xml:getBool  ("hp.ui#markers", cfg.showMarkers)
    cfg.bindHud     = xml:getBool  ("hp.ui#bindHud", cfg.bindHud)

    xml:delete()
    return cfg, nil
end

function HP_Config:write(pathOverride)
    self:init()
    local path = pathOverride or self.path
    if XMLFile == nil or XMLFile.create == nil then
        return false, "xml-api-missing"
    end
    local xml = XMLFile.create("hpCfgWrite", path, "hp")
    if not xml then return false, "create-failed" end

    local cfg = self:getDefaults() -- start from current UI
    if HP_UI then
        cfg.anchor      = HP_UI.anchor
        cfg.x           = HP_UI.x
        cfg.y           = HP_UI.y
        cfg.scale       = HP_UI.scale
        cfg.width       = HP_UI.width or cfg.width
        cfg.opacity     = HP_UI.opacity
        cfg.pad         = HP_UI.pad
        cfg.rowGap      = HP_UI.rowGap
        cfg.fontSize    = HP_UI.fontSize
        cfg.maxRows     = HP_UI.maxRows
        cfg.bgEnabled   = HP_UI.bgEnabled
        cfg.outline     = HP_UI.outline
        cfg.shadow      = HP_UI.shadow
        cfg.showMarkers = HP_UI.showMarkers
        cfg.bindHud     = HP_UI.bindHud
    end

    xml:setInt   ("hp#version", cfg.version)

    xml:setString("hp.ui#anchor",  cfg.anchor)
    xml:setFloat ("hp.ui#x",       cfg.x)
    xml:setFloat ("hp.ui#y",       cfg.y)
    xml:setFloat ("hp.ui#scale",   cfg.scale)
    xml:setFloat ("hp.ui#width",   cfg.width)
    xml:setFloat ("hp.ui#opacity", cfg.opacity)
    xml:setFloat ("hp.ui#pad",     cfg.pad)
    xml:setFloat ("hp.ui#rowGap",  cfg.rowGap)
    xml:setFloat ("hp.ui#font",    cfg.fontSize)
    xml:setInt   ("hp.ui#maxRows", cfg.maxRows)
    xml:setBool  ("hp.ui#bg",      cfg.bgEnabled)
    xml:setBool  ("hp.ui#outline", cfg.outline)
    xml:setBool  ("hp.ui#shadow",  cfg.shadow)
    xml:setBool  ("hp.ui#markers", cfg.showMarkers)
    xml:setBool  ("hp.ui#bindHud", cfg.bindHud)

    local ok = xml:save()
    xml:delete()
    return ok == true, ok and nil or "save-failed"
end
