if debugmode then message('Running successfully!') end

local keys = {
    open = keybinds:newKeybind("Open ItemMaster", IMconfig.key_open, false)
}




message('Press [ ' .. keys.open:getKeyName() .. ' ] to open ItemMaster.',nil,true)
local UI = models:newPart('IMUI'):setParentType('HUD')

local function localRequire(dir)
    local thing = load(read(dir))
    return thing()
end

local function save(index, value)
    IMconfig[index] = value
    write('ItemMaster/config.json',toJson(IMconfig))
    if debugmode then
        message('Written value "§a' .. value .. '" to setting "§b' .. index .. '§r".')
    end
end

local base64 = localRequire('ItemMaster/assets/libraries/base64.lua')

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

local tasks = {}

local UItree = {
    main = {
        {
            type = 'sprite',
            index = 'title',
            pos = vec(0,0,0),
            anchor = 'MC' -- middle center
        }
    }
}

local function goto_screen(index)
    for _, screen in pairs(UItree[index]) do
        for __, element in ipairs(screen) do
            if element.type == 'sprite' then
                
            end
        end
    end
end
