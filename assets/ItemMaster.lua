-- readByteArray = read
-- writeByteArray = write
-- message
-- IM_autoUpdate = autoUpdate
-- IM_save = save
-- debugmode
-- localversion = version
-- IMconfig
-- delete
-- latestVersion

if debugmode then message('Running successfully!') end

local function localRequire(dir)
    local thing, err = load(read(dir))
    if err then
        message("An error occured while running " .. dir .. " :\n" .. err)
    else
        if debugmode then
            message("Loaded: §7" .. dir:gsub("/([^/]*)$", "/§f%1"))
        end
        return thing()
    end
end

local base64 = localRequire('ItemMaster/assets/libraries/base64.lua')
local loam = localRequire('ItemMaster/assets/libraries/loam.lua')
local List = localRequire('ItemMaster/assets/libraries/List.lua')
local NinesliceRenderer = localRequire('ItemMaster/assets/libraries/NinesliceRenderer.lua')

local defaults = {
    key_open = "key.keyboard.right.bracket"
}

local function checkDefaults()
    --logTable(IMconfig)
    for i, v in pairs(defaults) do
        --log(IMconfig[i])
        if IMconfig[i] == nil then
            IM_save("config", i, v)
        end
    end
end

checkDefaults()

local keys = {
    open = keybinds:newKeybind("Open ItemMaster", IMconfig.key_open, false)
}

message('Press [ §e' .. keys.open:getKeyName() .. '§r ] to open ItemMaster.',nil,true)
local UI = models:newPart('IMUI'):setParentType('HUD')


local function save(index, value)
    IMconfig[index] = value
    write('ItemMaster/config.json',toJson(IMconfig))
    if debugmode then
        message('Written value "§a' .. value .. '" to setting "§b' .. index .. '§r".')
    end
end

local function localTexture(name, dir)
    local thing = base64.encode(read(dir))
    return textures:read(name, thing)
end

--message(base64.decode('SSBhbSBnYXku'))

local mainTexture = localTexture('IM_mainTexture', 'ItemMaster/assets/textures/texture.png')

local sprites = {
    title = {
        x = 0,
        y = 0,
        w = 82,
        h = 24,
        texture = mainTexture
    }
}
