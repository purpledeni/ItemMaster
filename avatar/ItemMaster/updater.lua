if not host:isHost() then
    return
end

local branch = 'main'
local Promise = require("ItemMaster.Promise")
local debugmode = true

local function message(str,color,actionbar)
    if actionbar then
        host:setActionbar('["[IM] ",{"text":"' .. str .. '","color":"' .. color .. '"}]')
    else
        printJson('["[ItemMaster] ",{"text":"' .. str .. '","color":"' .. color .. '"}]')
    end
end

local function checkNetworking()
    if net:isNetworkingAllowed() then
        if net:isLinkAllowed('https://api.github.com') and net:isLinkAllowed('https://raw.githubusercontent.com') then
            return true
        else
            message('Host \\"api.github.com\\" or \\"raw.githubusercontent.com\\" not whitelisted.', "red")
            return false
        end
    else
        message('Networking API disabled.', "red")
        return false
    end
end


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

local function checkVersion()
    if checkNetworking() then
        --fetch('https://raw.githubusercontent.com/purpledeni/ItemMaster/' .. branch .. '/assets/VERSION', 'raw')
        Promise.awaitGet('https://raw.githubusercontent.com/purpledeni/ItemMaster/' .. branch .. '/assets/VERSION')
        :thenString(function(str)
            log(tonumber(readByteArray('ItemMaster/assets/VERSION')))
        end)
    end
end

local function fetchAssets()
    if checkNetworking() then
        recursiveDelete('ItemMaster/assets',false)
        --fetch('https://api.github.com/repos/purpledeni/ItemMaster/git/trees/main?recursive=1', 'tree')
        Promise.awaitGet('https://api.github.com/repos/purpledeni/ItemMaster/git/trees/' .. branch .. '?recursive=1')
        :thenJson(function(json)
            table.sort(json.tree, function(a,b) 
                if a.type == 'tree' and b.type == 'blob' then
                    return true -- tree comes before blob
                else
                    return false
                end
             end)
            for i, v in pairs(json.tree) do
                if string.find(v.path, "^assets/") then
                    if v.type == 'tree' then
                        if file:mkdirs('ItemMaster/' .. v.path) then
                            if debugmode then message('Created folder : ItemMaster/' .. v.path, 'white') end
                        end
                    elseif v.type == 'blob' then
                        --file:writeString()
                        Promise.awaitGet('https://raw.githubusercontent.com/purpledeni/ItemMaster/' .. branch .. '/' .. v.path)
                        :thenByteArray(function(str)
                            log(str)
                            writeByteArray('ItemMaster/' .. v.path, str)
                            if debugmode then message('Written to : ItemMaster/' .. v.path, 'white') end
                        end)
                    end
                    log(v.path)
                end
            end
        end)
    end
end


if not file:mkdirs('ItemMaster/assets') and file:exists('ItemMaster/assets/VERSION') then
    checkVersion()
else
    fetchAssets()
end


