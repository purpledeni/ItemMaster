if not host:isHost() then
    return
end

local checkFor = {}

local function fetch(url, type)
    local future = net.http:request(url):method("GET"):send()
    log(future)
    checkFor[#checkFor + 1] = {
        future = future,
        type = type
    }
end

function events.tick()
    for i, value in ipairs(checkFor) do
        if value.future:isDone() then
            local result = value.future:getValue()
            log(result:getData(), result:getHeaders())
            table.remove(checkFor,i)
            i = i - 1
        end
    end
end

local function fetchAssets()
    if net:isNetworkingAllowed() then
        local branch = 'main'
        if net:isLinkAllowed('https://api.github.com') then
            fetch('https://api.github.com/repos/purpledeni/ItemMaster/git/trees/' .. branch .. '?recursive=1','table')
        else
            printJson('["[ItemMaster]",{"text":" Host \\"api.github.com\\" not whitelisted, cannot update.","color":"red"}]')
        end
    else
        printJson('["[ItemMaster]",{"text":" Networking API disabled, cannot update.","color":"red"}]')
    end
end


if not file:mkdirs('ItemMaster/assets') and file:exists('ItemMaster/assets/VERSION.txt') then
    -- compare versions with github and continue from there
else
    fetchAssets()
end
