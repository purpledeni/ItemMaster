---@class List
---@operator call(any[]): List
local List = {}
List.__index = List

---@param tbl any[]?
---@return List
function List.new(tbl)
    local self = setmetatable(tbl or {}, List)
    return self
end

---@param a integer
---@param b integer
---@return integer[]
local function range(a, b)
    return { ("."):rep(b):gsub("().", ("").char):sub(a):byte(1, -1) }
end
---@param start integer
---@param stop integer
---@param step integer?
function List.range(start, stop, step)
    step = step or 1
    if step == 1 and start >= 0 and stop <= 255 and stop >= start then
        return List.new(range(start, stop))
    else
        local list = List.new()
        for i = start, stop, step do
            list:push(i)
        end
        return list
    end
end

function List:raw()
    local raw = table.pack(table.unpack(self))
    raw.n = nil
    return raw
end

function List:copy()
    return List.new(self:raw())
end

function List:clear()
    self = List.new()
    return self
end

---@generic T
---@param func fun(self: List): T
---@return T
function List:apply(func)
    return func(self)
end

---@param func fun(self: List): any
function List:tap(func)
    func(self)
    return self
end

---@param value any
function List:push(value)
    self[#self+1] = value
    return self
end

---@param conditon boolean
---@param value any
function List:push_if(conditon, value)
    if conditon then
        self:push(value)
    end
    return self
end

---@param condition boolean
---@param value any
function List:push_nt(condition, value)
    if not condition then
        self:push(value)
    end
    return self
end

---@return any
function List:pop()
    local n = #self
    local value = self[n]
    self[n] = nil
    return value
end

---@param value any
function List:remove(value)
    for i = 1, #self do
        if self[i] == value then
            table.remove(self, i)
            return self
        end
    end
    return self
end

---@param func fun(value: any): any
function List:each(func)
    for i = 1, #self do
        func(self[i])
    end
    return self
end

---@param func fun(value: any, i: integer): any
function List:each_i(func)
    for i = 1, #self do
        func(self[i], i)
    end
    return self
end

---@param func fun(value: any): any
function List:map(func)
    local new_list = List.new()
    for i = 1, #self do
        new_list[i] = func(self[i])
    end
    return new_list
end

---@param func fun(value: any): any?
function List:filter(func)
    local new_list = List.new()
    local head = 1
    for i = 1, #self do
        local value = self[i]
        if func(value) then
            new_list[head] = value
            head = head + 1
        end
    end
    return new_list
end

function List:filter_out(func)
    local new_list = List.new()
    local head = 1
    for i = 1, #self do
        local value = self[i]
        if not func(value) then
            new_list[head] = value
            head = head + 1
        end
    end
    return new_list
end

---@param func fun(value: any): any
function List:filter_map(func)
    local new_list = List.new()
    local head = 1
    for i = 1, #self do
        local value = self[i]
        local new_value = func(value)
        if new_value then
            new_list[head] = new_value
            head = head + 1
        end
    end
    return new_list
end

---@param callback fun(v: any): any[]
function List:flat_map(callback)
    local new_list = List.new()
    local head = 1
    for i = 1, #self do
        local result = callback(self[i])
        for j = 1, #result do
            new_list[head] = result[j]
            head = head + 1
        end
    end
    return new_list
end

function List:flatten()
    local new_list = List.new()
    local head = 1
    for i = 1, #self do
        local result = self[i]
        for j = 1, #result do
            new_list[head] = result[j]
            head = head + 1
        end
    end
    return new_list
end

---@param distinctor fun(v: any): any
function List:group_by(distinctor)
    local grouped = {}
    local heads = {}
    for i = 1, #self do
        local value = self[i]
        local key = distinctor(value)
        local group = grouped[key]
        if not group then
            group = {}
            grouped[key] = group
            heads[key] = 1
        end
        local head = heads[key] + 1
        group[head] = value
        heads[key] = head
    end
    return List.new(grouped)
end

---@generic V
---@param func fun(value: V): number|integer|string
---@return V
function List:min_by(func)
    if #self == 0 then return nil end
    local min_value = self[1]
    local min_result = func(min_value)
    for i = 2, #self do
        local value = self[i]
        local result = func(value)
        if result < min_result then
            min_value = value
            min_result = result
        end
    end
    return min_value
end

---@generic V
---@param func fun(value: V): number|integer|string
---@return V
function List:max_by(func)
    if #self == 0 then return nil end
    local max_value = self[1]
    local max_result = func(max_value)
    for i = 2, #self do
        local value = self[i]
        local result = func(value)
        if result > max_result then
            max_value = value
            max_result = result
        end
    end
    return max_value
end

function List:random()
    if #self == 0 then return nil end
    return self[rng.int(1, #self)]
end

function List:unique()
    local new_list = List.new()
    local seen = {}
    local head = 1
    for i = 1, #self do
        local value = self[i]
        if not seen[value] then
            new_list[head] = value
            seen[value] = true
            head = head + 1
        end
    end
    return new_list
end

---@return integer
function List:count()
    return #self
end

---@return number
function List:sum()
    local sum = 0
    for i = 1, #self do
        sum = sum + self[i]
    end
    return sum
end

---@param separator string?
---@return string
function List:join(separator)
    return table.concat(self, separator)
end

---@param func fun(value: any): boolean
---@return boolean
function List:all(func)
    for i = 1, #self do
        if not func(self[i]) then
            return false
        end
    end
    return true
end

---@param func fun(value: any): boolean
---@return boolean
function List:any(func)
    for i = 1, #self do
        if func(self[i]) then
            return true
        end
    end
    return false
end

---@param value any
function List:contains(value)
    for i = 1, #self do
        if self[i] == value then
            return true
        end
    end
    return false
end

---@generic T
---@param func fun(accumulator: T, value: any): T
---@param initial T
---@return T
function List:reduce(func, initial)
    local accumulator = initial
    for i = 1, #self do
        accumulator = func(accumulator, self[i])
    end
    return accumulator
end

---@param func (fun(a: any, b: any): boolean)?
function List:sort(func)
    table.sort(self, func)
    return self
end

---@param transformer fun(v: any): number|integer|string
function List:sort_by(transformer)
    local lookup = {}
    for i = 1, #self do
        local element = self[i]
        lookup[element] = transformer(element)
    end
    return self:sort(function (a, b)
        return lookup[a] < lookup[b]
    end)
end

---@param n integer
function List:take(n)
    local new = table.pack(table.unpack(self, 1, n))
    new.n = nil
    return List.new(new)
end

---@param n integer
function List:skip(n)
    local new = table.pack(table.unpack(self, n + 1))
    new.n = nil
    return List.new(new)
end

---@param n integer
function List:take_last(n)
    local len = #self
    local new = table.pack(table.unpack(self, len - n + 1, len))
    new.n = nil
    return List.new(new)
end

---@param func fun(value: any): boolean
---@return integer?
function List:index_where(func)
    for i = 1, #self do
        if func(self[i]) then
            return i
        end
    end
    return nil
end

---@param func fun(value: any): boolean
---@return integer?
function List:final_index_where(func)
    for i = #self, 1, -1 do
        if func(self[i]) then
            return i
        end
    end
    return nil
end

---@param other List
function List:append(other)
    local n = #self
    for i = 1, #other do
        n = n + 1
        self[n] = other[i]
    end
    return self
end

_G.list = setmetatable({}, {
    __call = function(_, tbl)
        return List.new(tbl)
    end,
    __index = List
})