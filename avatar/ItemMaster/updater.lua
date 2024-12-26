if not host:isHost() then
    return
end

local branch = 'main'
local debugmode = true


--#region Promise

---@param func fun()
---@param time number|fun():boolean
---@vararg any
local function delay(func, time, ...)
    local timer = 0
    local id = "delay-" .. math.random()
    local args = {...}

    local function execute()
        func(table.unpack(args))
        events.WORLD_TICK:remove(id)
    end

    events.WORLD_TICK:register(function ()
        timer = timer + 1
        if type(time) == "function" then
            if time() then
                execute()
            end
        elseif timer >= time then
            execute()
        end
    end, id)

    return function(_func, _time, ...)
        return delay(_func, time + _time, ...)
    end
end

---@param func fun(i: integer)
---@param time number|fun(i: integer): boolean
---@param done? fun(i: integer)
local function run(func, time, done)
    local id = "run-" .. math.random()
    local runner = nil
    local function finish(i)
        events.WORLD_TICK:remove(id)
        if done then
            done(i)
        end
    end
    if type(time) == "function" then
        function runner(i)
            (time(i) and finish or func)(i)
        end
    else
        local i = 0
        function runner()
            (i >= time and finish or func)(i)
            i = i + 1
        end
    end
    events.WORLD_TICK:register(runner, id)
end

---@class Promise
---@field callbacks fun(...: any)[]
---@field errbacks fun(...: any)[]
---@field fulfilled boolean
---@field rejected boolean
---@field result any
local Promise = {}
Promise.__index = Promise

---@param executor fun(resolve: fun(...: any), reject: fun(...: any))
function Promise.new(executor)
    local self = setmetatable({}, Promise)
    self.callbacks = {}
    self.errbacks = {}
    self.fulfilled = false
    self.rejected = false
    self.result = {}

    local function resolve(...)
        if self.fulfilled or self.rejected then return end
        self.fulfilled = true
        self.result = {...}
        for i = 1, #self.callbacks do
            delay(self.callbacks[i], 0, ...)
        end
        self.callbacks = {}
    end

    local function reject(...)
        if self.fulfilled or self.rejected then return end
        self.rejected = true
        self.result = {...}
        for i = 1, #self.errbacks do
            delay(self.errbacks[i], 0, ...)
        end
        self.errbacks = {}
    end

    executor(resolve, reject)
    return self
end

---@param future Future
---@param timeout? integer
function Promise.await(future, timeout)
    return Promise.new(function(resolve, reject)
        local start = client.getSystemTime()
        delay(function()
            local value = future:getValue()
            if value then
                resolve(value:getData(), value:getHeaders())
            else
                reject()
            end
        end, function()
            return future:isDone() or (timeout and client.getSystemTime() - start >= timeout) or false
        end)
    end)
end

---@param url string
---@param timeout? integer
function Promise.awaitGet(url, timeout)
    return Promise.await(net.http:request(url):method("GET"):send(), timeout)
end

---@param ... Promise
function Promise.awaitAll(...)
    local promises = {...}
    return Promise.new(function(resolve, reject)
        local results = {}
        local total = #promises
        local completed = 0

        local function resolver(index)
            return function(...)
                completed = completed + 1
                results[index] = {...}
                if completed == total then
                    resolve(results)
                end
            end
        end

        local function rejecter(reason)
            reject(reason)
        end

        for i = 1, #promises do
            promises[i]:then_(resolver(i), rejecter)
        end
    end)
end

---@param callback? fun(data: any, headers: any): Promise?
---@param errback? fun(reason: any): Promise?
function Promise:then_(callback, errback)
    local chained = Promise.new(function(resolve, reject)
        local function fulfill(...)
            if callback then
                local result = callback(...)
                if result and getmetatable(result) == Promise then
                    result:then_(resolve, reject)
                else
                    resolve(result)
                end
            else
                resolve(...)
            end
        end

        local function fail(...)
            if errback then
                local result = errback(...)
                if result and getmetatable(result) == Promise then
                    result:then_(resolve, reject)
                else
                    reject(result)
                end
            else
                reject(...)
            end
        end

        if self.fulfilled then
            delay(fulfill, 10, table.unpack(self.result))
        elseif self.rejected then
            delay(fail, 10, table.unpack(self.result))
        else
            self.callbacks[#self.callbacks + 1] = fulfill
            self.errbacks[#self.errbacks + 1] = fail
        end
    end)

    return chained
end

---@param errback fun(reason: any): Promise?
function Promise:catch(errback)
    return self:then_(nil, errback)
end

local downloads = {}
---@param stream InputStream
---@param headers HttpHeaders
local function asyncBuffer(stream, headers, callback)
    local limit = headers["content-length"] and tonumber(headers["content-length"][1]) or 0
    local buffer = data:createBuffer(limit)
    local done = false
    local progress = 0
    run(function ()
        local read = buffer:readFromStream(stream, stream:available())
        local next = stream:read()
        if next == -1 then
            done = true
        else
            buffer:write(next)
        end
        progress = progress + read + 1
        downloads[stream] = { count = progress, limit = limit }
    end, function ()
        return done
    end, function ()
        buffer:setPosition(0)
        callback(buffer, progress)
        downloads[stream] = nil
    end)
end

local function readStreamAsync(stream, headers, callback)
    return Promise.new(function(resolve, reject)
        asyncBuffer(stream, headers, function(buffer, length)
            local result = callback(buffer, length)
            resolve(result)
        end)
    end)
end

---@param callback fun(value: string, headers: HttpHeaders): Promise?
---@param errback? fun(reason: any): Promise?
function Promise:thenByteArray(callback, errback)
    return self:then_(function(stream, headers)
        return readStreamAsync(stream, headers, function(buffer, length)
            return buffer:readByteArray(length)
        end):then_(callback, errback)
    end, errback)
end

---@param callback fun(value: any): Promise?
---@param errback? fun(reason: any): Promise?
function Promise:thenJson(callback, errback)
    return self:thenByteArray(function(value)
        return callback(parseJson(value))
    end, errback)
end

--#endregion


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
local IMconfig = {}
if file:exists('ItemMaster/config.json') then
    IMconfig = parseJson(readByteArray('ItemMaster/config.json'))
end

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

local function IMrun()  --Runner
    local IM = readByteArray('ItemMaster/ItemMaster.lua')
    local environment = {
        read = readByteArray,
        write = writeByteArray,
        message = message,
        autoUpdate = IM_autoUpdate,
        debugmode = debugmode,
        version = localversion,
        IMconfig = IMconfig,
        delete = recursiveDelete
    }
    setmetatable(environment,{
        __index = _G
    })
    load(IM,nil,environment)()
end

local function checkNetworking()
    if net:isNetworkingAllowed() then
        if net:isLinkAllowed('https://api.github.com') and net:isLinkAllowed('https://raw.githubusercontent.com') then
            return true
        else
            message('Host "api.github.com" and/or "raw.githubusercontent.com" are not whitelisted. Update skipped.', "red")
            IMrun()
        end
    else
        message('Networking API is disabled. Update skipped.', "red")
        IMrun()
    end
    return false
end




function IM_autoUpdate(bool,silent)
    if file:exists('ItemMaster/config.json') then
        IMconfig = parseJson(readByteArray('ItemMaster/config.json'))
    end
    IMconfig.allow_autoupdate = bool
    writeByteArray('ItemMaster/config.json',toJson(IMconfig))
    if bool then
        if not silent then
            message('Auto-Update §aenabled§r, reload the avatar to check for ItemMaster updates.\nYou can disable this at any time in the §bItemMaster Settings§r or by running "§b/figura run IM_autoUpdate(false)§r" in chat.')
        end
    else
        if not silent then
            message('Auto-Update §cdisabled§r, you can enable this by running "§b/figura run IM_autoUpdate(true)§r" in chat.')
        end
    end
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
                    message('Updating... (' .. totalFetch + leftToFetch .. '/' .. totalFetch .. ')','white',true)
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
                            if debugmode then message(leftToFetch .. ', Written to: ItemMaster/' .. v.path) end
                            if string.find(v.path, "^assets/") then
                                leftToFetch = leftToFetch + 1
                                if leftToFetch == 0 then
                                    message('Updated successfully.','white',true)
                                    IMrun()
                                end
                            end
                            --log(leftToFetch)
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
        :thenByteArray(function(str)
            if localversion < tonumber(str) then
                if debugmode then message('Currently installed version is outdated, updating to ' .. str .. '_' .. branch .. '...') else
                    message('Updating to v' .. str .. '..', nil,true)
                end
                localversion = str
                fetchAssets()
            else
                if debugmode then message('Currently installed version is up to date.', "white") end
                IMrun()
            end
        end)
    end
end


if debugmode then
    function IM_versionDebug(num)
        file:mkdirs('ItemMaster/assets')
        writeByteArray('ItemMaster/assets/VERSION',tostring(num))
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
