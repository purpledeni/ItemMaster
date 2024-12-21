if not host:isHost() then
    return
end

local branch = 'main'

local Promise = require("ItemMaster.Promise")
local HTTP = require("ItemMaster.http")

--Promise.awaitGet("https://randomfox.ca/floof/"):thenJson(function(json)
--    return Promise.awaitGet(json.image)
--end):then64(function(data)
--    -- `data` is base64 image data
--end)

-- a breakdown of the previous code
--Promise.awaitGet("https://api.github.com/repos/purpledeni/ItemMaster/git/trees/main/assets?recursive=1") -- returns a Promise that sends an HTTP request and resolves when it finishes. This website returns JSON with a link to an image.
--:thenJson(function(json) -- when the request has finished, this function is called with a table containing the body.
--    --log(json)    
--    return Promise.awaitGet(json.tree[2].url) -- we return a new Promise. Because my implementation supports chaining, the next function refers to this second Promise instead of the first one.
--end):thenString(function(data) -- when the second request has finished, this function is called with base64 data. 
--    log(parseJson(data).content)-- now we can parse this as a texture, audio, etc.
--end)

local function fetch(url, type)
    if type == 'raw' then
        HTTP.get(url,function(text)
            log(text)
        end,'string')
    elseif type == 'tree' then
        Promise.awaitGet(url)
        :thenJson(function(json)
            log(json)
        end)
    end
end

local function message(str,color,actionbar)
    if actionbar then
        host:setActionbar('["[IM] ",{"text":"' .. str .. '","color":"' .. color .. '"}]')
    else
        printJson('["[ItemMaster] : ",{"text":"' .. str .. '","color":"' .. color .. '"}]')
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

local function checkVersion()
    if checkNetworking() then
        
    end
end


local function fetchAssets()
    if checkNetworking() then
        fetch('https://raw.githubusercontent.com/purpledeni/ItemMaster/main/LICENSE', 'raw')
        fetch('https://api.github.com/repos/purpledeni/ItemMaster/git/trees/main?recursive=1', 'tree')
    end
end


if not file:mkdirs('ItemMaster/assets') and file:exists('ItemMaster/assets/VERSION') then
    checkVersion()
else
    fetchAssets()
end
