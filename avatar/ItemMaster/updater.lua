if not host:isHost() then
    return
end

local branch = 'main'
local Promise = require("ItemMaster.Promise")
local debugmode = false

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

local localversion = file:exists('ItemMaster/assets/VERSION') and tonumber(readByteArray('ItemMaster/assets/VERSION')) or -1

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
            '§3[IM] ',
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

local leftToFetch = 0
local totalFetch = 0
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
                    leftToFetch = leftToFetch - 1
                    totalFetch = totalFetch + 1
                    message('Updating... (' .. totalFetch - leftToFetch .. '/' .. totalFetch .. ')','white',true)
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
                            --log(leftToFetch)
                        end)
                    end
                    leftToFetch = leftToFetch + 1
                    if leftToFetch == 0 then
                        message('Updated successfully.','white',true)
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
                localversion = str
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

if debugmode then
    function IM_versionDebug(num)
        file:mkdirs('ItemMaster/assets')
        writeByteArray('ItemMaster/assets/VERSION',tostring(num))
    end
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
    if IMconfig.allow_autoupdate == true then
        checkVersion()
    else
        if IMconfig.allow_autoupdate == nil then
            message('§bThis may be your first time running ItemMaster.')
        end
        printJson(toJson({
            "§3[IM] §rSince the entire code (other than the updater) is stored outside of your avatar (to not clog up space), in order to use it you need to download it from GitHub first.\nYou can ",
            {
                text = '§b§ndo that manually',
                clickEvent = {
                    action = "open_url",
                    value = "https://github.com/purpledeni/ItemMaster"
                },
                hoverEvent = {
                    action = "show_text",
                    value = "https://github.com/purpledeni/ItemMaster\n§8(Click)"
                }
            },
            ' §7(instructions in README.md)§r, or by running ',
            {
                text = '§b§nthis command§r',
                clickEvent = {
                    action = 'suggest_command',
                    value = '/figura run IM_autoUpdate(true)'
                },
                hoverEvent = {
                    action = "show_text",
                    value = '/figura run IM_autoUpdate(true)\n§8(Click)'
                }
            },
            ' in chat.'
        }))
        IM_autoUpdate(false,true)
    end
end


