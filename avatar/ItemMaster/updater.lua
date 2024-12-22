if not host:isHost() then
    return
end

local branch = 'main'
local Promise = require("ItemMaster.Promise")
local debugmode = true

local function writeByteArray(path, str)
    local buf = data:createBuffer()
    buf:writeByteArray(str)
    buf:setPosition(0)
    local dat = file:openWriteStream(path)
    buf:writeToStream(dat)
    dat:close()
    buf:close()
end

local function readByteArray(path)
    local dat = file:openReadStream(path)
    local available = dat:available() + 1
    local buf = data:createBuffer(available)
    buf:readFromStream(dat, available)
    buf:setPosition(0)
    local str = buf:readByteArray(available)
    dat:close()
    buf:close()
    return str
end

local localversion = file:exists('ItemMaster/assets/VERSION') and tonumber(readByteArray('ItemMaster/assets/VERSION')) or 0

local function message(str,color,actionbar)
    if not color then color = 'white' end
    if actionbar then
        local bleh = {
            '§3[IM] ',
            {
                text = str,
                color = color
            }
        }
        host:setActionbar(toJson(bleh))
    else
        local bleh = {
            '§3[IM v' .. localversion .. '_' .. branch .. '] ',
            {
                text = str .. '\n',
                color = color
            }
        }
        printJson(toJson(bleh))
    end
end

local function checkNetworking()
    if net:isNetworkingAllowed() then
        if net:isLinkAllowed('https://api.github.com') and net:isLinkAllowed('https://raw.githubusercontent.com') then
            return true
        else
            message('Host "api.github.com" and/or "raw.githubusercontent.com" are not whitelisted. Whitelist them and restart the avatar to update.', "red")
        end
    else
        message('Networking API is disabled. Enable it and restart the avatar to update.', "red")
    end
    return false
end



local function recursiveDelete(dir,thisone)
    for _, x in ipairs(file:list(dir)) do
        if file:isDirectory(dir .. '/' .. x) then
            recursiveDelete(dir .. '/' .. x, true)
        elseif file:isFile(dir .. '/' .. x) then
            file:delete(dir .. '/' .. x)
        end
    end
    if thisone then file:delete(dir) end
end

local function fetchAssets()
    if checkNetworking() then
        recursiveDelete('ItemMaster/assets',false)
        Promise.awaitGet('https://api.github.com/repos/purpledeni/ItemMaster/git/trees/' .. branch .. '?recursive=1')
        :thenJson(function(json)
            table.sort(json.tree, function(a,b)
                return a.type == 'tree' and b.type == 'blob' -- tree comes before blob
            end)
            for i, v in pairs(json.tree) do
                if string.find(v.path, "^assets/") then
                    if v.type == 'tree' then
                        if file:mkdirs('ItemMaster/' .. v.path) then
                            if debugmode then message('Created folder : ItemMaster/' .. v.path) end
                        end
                    elseif v.type == 'blob' then
                        --file:writeString()
                        Promise.awaitGet('https://raw.githubusercontent.com/purpledeni/ItemMaster/' .. branch .. '/' .. v.path)
                        :thenByteArray(function(str)
                            --log(str)
                            writeByteArray('ItemMaster/' .. v.path, str)
                            if debugmode then message('Written to: ItemMaster/' .. v.path) end
                        end)
                    end
                    --log(v.path)
                end
            end
        end)
    end
end

local function checkVersion()
    if checkNetworking() then
        Promise.awaitGet('https://raw.githubusercontent.com/purpledeni/ItemMaster/' .. branch .. '/assets/VERSION')
        :thenString(function(str)
            if localversion < tonumber(str) then
                if debugmode then message('Currently installed version is outdated, updating to ' .. str .. '_' .. branch .. '...') end
                fetchAssets()
            else
                if debugmode then message('Currently installed version is up to date.', "white") end
            end
        end)
    end
end

local IMconfig = {}
if file:exists('ItemMaster/config.json') then
    IMconfig = parseJson(readByteArray('ItemMaster/config.json'))
end

function IM_autoUpdate(bool,silent)
    if file:exists('ItemMaster/config.json') then
        IMconfig = parseJson(readByteArray('ItemMaster/config.json'))
    end
    IMconfig.allow_autoupdate = bool
    writeByteArray('ItemMaster/config.json',toJson(IMconfig))
    if bool then
        if not silent then
            message('Auto-Update §aenabled§r, restart the avatar to check for ItemMaster updates.\nYou can disable this at any time in the §bItemMaster Settings§r or by running "§b/figura run IM_autoUpdate(false)§r" in chat.')
        end
    else
        if not silent then
            message('Auto-Update §cdisabled§r, you can enable this by running "§b/figura run IM_autoUpdate(true)§r" in chat.')
        end
    end
end

if not file:mkdirs('ItemMaster/assets') and file:exists('ItemMaster/assets/VERSION') then
    if IMconfig.allow_autoupdate then
        checkVersion()
    else
        IM_autoUpdate(false,true)
    end
else
    if IMconfig.allow_autoupdate then
        checkVersion()
    else
        message('This may be your first time running ItemMaster.\nThe entire code (other than the updater) is stored outside of your avatar, but in order to use it you need to download it from Github first. You can do that manually, or by running\n"§b/figura run IM_autoUpdate(true)§r" in chat.')
        IM_autoUpdate(false,true)
    end
end


