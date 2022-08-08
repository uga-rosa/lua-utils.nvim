local utils = require("lua-utils.utils")
local assertf = utils.assertf
local assert_type = utils.assert_type

---@generic T
---@param value `T`
---@param default T
---@return T
local function set_default(value, default)
    if value == nil then
        return default
    end
    return value
end

---============================================
---                 CLASS
---============================================

---An Wrapped array whose elements are all of the same type T.
---@class Seq
---@field private _data any[]
---@field private _len integer
---@field private _type correct_type
local Seq = {}
Seq.__index = Seq

---Returns the entire raw array.
---Getter for _data
---@generic T
---@return T[]
function Seq:unpack()
    return self._data
end

---Returns the length of the Seq.
---Getter for _len
---@return integer
function Seq:len()
    return self._len
end

---Returns the type of the item of the Seq.
---Getter for _type
---@return string
function Seq:type()
    return self._type
end

---@param self Seq
---@return string
Seq.__tostring = function(self)
    local data = vim.inspect(self._data)
    data = "[" .. data:sub(2, -2) .. "]"
    return ("Seq<%s>%s#%s"):format(self._type, data, self._len)
end

---@param t1 table
---@param t2 table
local function table_equal(t1, t2)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then
        return false
    end
    if ty1 ~= "table" and ty2 ~= "table" then
        return t1 == t2
    end

    local keySet = {}
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not table_equal(v1, v2) then
            return false
        end
        keySet[k1] = true
    end
    for k2, _ in pairs(t2) do
        if not keySet[k2] then
            return false
        end
    end
    return true
end

---@param s1 Seq
---@param s2 Seq
---@return boolean
Seq.__eq = function(s1, s2)
    if s1._len ~= s2._len then
        return false
    end
    return table_equal(s1._data, s2._data)
end

---@param s1 Seq
---@param s2 Seq
---@return Seq
Seq.__concat = function(s1, s2)
    assertf(s1._type == s2._type, "Attempted to combine different types of Seq")
    local new = {}
    for i, v in ipairs(s1._data) do
        new[i] = v
    end
    for _, v in ipairs(s2._data) do
        table.insert(new, v)
    end
    return Seq.new(new, s1._type)
end

---============================================
---                 METHOD
---============================================

---============================================
---             BASIC OPERATION
---============================================

local zero_values = {
    boolean = false,
    number = 0,
    integer = 0,
    float = 0.0,
    string = "",
    table = {},
    array = {},
}

---Generates Seq from array.
---@param arr any[] | Seq
---@param typename? correct_type #Default: type(arr[1])
---@return Seq
function Seq.new(arr, typename)
    if getmetatable(arr) == Seq then
        ---@cast arr Seq
        return arr
    end

    ---@cast arr any[]
    assert_type(arr, "array")
    assertf(not (typename == nil and #arr == 0), "Ambiguous type")
    typename = set_default(typename, type(arr[1]))

    for _, v in ipairs(arr) do
        assert_type(v, typename)
    end

    return setmetatable({
        _data = arr,
        _len = #arr,
        _type = typename,
    }, Seq)
end

---Generates Seq from type, length, and initial value.
---If the initial value is omitted, it is automatically set according to type.
---@param typename correct_type
---@param len integer
---@param init? any
---@return Seq
---
---Example:
---local seqString = Seq.new("string", 4, "hi")
---print(seqString)
--- => Seq<string>[ "hi", "hi", "hi", "hi" ]
function Seq.newWith(typename, len, init)
    init = set_default(init, zero_values[typename])
    assert_type(init, typename, true)
    assert_type(len, "non_negative_integer")

    local data = {}
    for i = 1, len do
        data[i] = init
    end

    return setmetatable({
        _data = data,
        _len = len,
        _type = typename,
    }, Seq)
end

---Asserts index.
---@param len integer
---@param i integer
local function assert_index(len, i)
    assert_type(len, "integer")
    assert_type(i, "integer")
    -- Out of bounds
    assertf(i >= 1 and i <= len, "Index (%s) out of bounds", i)
end

---Returns the i-th item of Seq 's'.
---@param pos integer
---@return any
function Seq:get(pos)
    assert_index(self._len, pos)
    return self._data[pos]
end

---Set the i-th value.
---@param pos integer
---@param value any
function Seq:set(pos, value)
    assert_index(self._len, pos)
    assertf(pos ~= self._len, "To append item, use 'add' method")
    self._data[pos] = value
end

---Add item 'x' into Seq 's' at a specifix position.
---*destructive*
---@param x any
---@param pos? integer #If i is omitted, added at the end of 's'.
function Seq:add(x, pos)
    assert_type(x, self._type)
    if pos == nil then
        table.insert(self._data, x)
    else
        assert_index(self._len, pos)
        table.insert(self._data, pos, x)
    end
    self._len = self._len + 1
end

---Insert items of Seq 'src' into Seq 's' at a specific position.
---*destructive*
---@generic T
---@param src Seq | T[]
---@param pos? integer #If i is omitted, added at the end of 'dst'.
function Seq:insert(src, pos)
    src = Seq.new(src, self._type)
    assertf(self._type == src._type, "Attempted to insert different types of Seq")

    if pos == nil then
        for _, v in ipairs(src._data) do
            table.insert(self._data, v)
        end
    else
        assert_index(self._len, pos)
        for i = 1, src._len do
            table.insert(self._data, pos + i - 1, src._data[i])
        end
    end
    self._len = self._len + src._len
end

---Deletes the items from i-th to j-th (including the ends of the range).
---*destructive*
---@generic T
---@param i integer
---@param j? integer #Default: Same as 'i'
function Seq:delete(i, j)
    assert_index(self._len, i)
    j = set_default(j, i)
    assert_index(self._len, j)
    assertf(i <= j, "i (%s) must be less than or equal to j (%s)", i, j)

    for _ = i, j do
        table.remove(self._data, i)
    end
    self._len = self._len - (j - i + 1)
end

---Get the slice of Seq 's' from i-th to j-th (including the ends of the range).
---@param s Seq | any[]
---@param i integer
---@param j? integer #Default: Same as 'i'
---@return Seq
function Seq.slice(s, i, j)
    s = Seq.new(s)
    assert_index(s._len, i)
    j = set_default(j, i)
    assert_index(s._len, j)
    assertf(i <= j, "i (%s) must be less than or equal to j (%s)", i, j)

    local result = {}
    for k = i, j do
        table.insert(result, s._data[k])
    end

    return Seq.new(result, s._type)
end

---Similier to table.remove().
---@param pos? integer #Default: self:len()
---@return Seq
function Seq:pop(pos)
    pos = set_default(pos, self._len)
    assert_index(self._len, pos)
    self._len = self._len - 1
    return table.remove(self._data, pos)
end

---============================================
---                 UTILITIES
---============================================

---Checks if every item fulfills 'pred'.
---@generic T
---@param s Seq | T[]
---@param pred fun(x: T): boolean
---@return boolean
function Seq.all(s, pred)
    s = Seq.new(s)
    assert_type(pred, "function")

    for _, v in ipairs(s._data) do
        if not pred(v) then
            return false
        end
    end
    return true
end

---Checks if at least one item fulfills 'pred'.
---@generic T
---@param s Seq | T[]
---@param pred fun(x: T): boolean
---@return boolean
function Seq.any(s, pred)
    s = Seq.new(s)
    assert_type(pred, "function")

    for _, v in ipairs(s._data) do
        if pred(v) then
            return true
        end
    end
    return false
end

---Returns the number of occurrences of the item 'x' in the Seq 's'.
---@generic T
---@param s Seq | T[]
---@param x T
---@return integer
function Seq.count(s, x)
    s = Seq.new(s)
    assert_type(x, s._type)

    local c = 0
    for _, v in ipairs(s._data) do
        if v == x then
            c = c + 1
        end
    end
    return c
end

---Returns a new sequence without duplicates.
---@generic T
---@param s Seq | T[]
---@return Seq
function Seq.deduplicate(s)
    s = Seq.new(s)

    ---@type table<any, boolean>
    local set = {}
    ---@type any[]
    local new = {}
    for _, v in ipairs(s._data) do
        if not set[v] then
            set[v] = true
            table.insert(new, v)
        end
    end
    return Seq.new(new, s._type)
end

---Returns a new Seq with all the items of 's' that fulfill the predicate 'pred'.
---@generic T
---@param s Seq | T[]
---@param pred fun(x: T): boolean
---@return Seq
function Seq.filter(s, pred)
    s = Seq.new(s)
    assert_type(pred, "function")

    local new = {}
    for _, v in ipairs(s._data) do
        if pred(v) then
            table.insert(new, v)
        end
    end
    return Seq.new(new, s._type)
end

---Keeps the items in the passed sequence 's' if they fulfill the predicate 'pred'.
---*destructive*
---@generic T
---@param pred fun(x: T): boolean
function Seq:keepIf(pred)
    self = Seq.filter(self, pred)
end

---Returns a new sequence with the results of the 'op' function applied to every item in the sequence 's'.
---@generic T, S
---@param s Seq | T[]
---@param op fun(x: T): S
---@return Seq
function Seq.map(s, op)
    s = Seq.new(s)
    assert_type(op, "function")

    local new = {}
    for i, v in ipairs(s._data) do
        new[i] = op(v)
    end
    return Seq.new(new)
end

---Applies 'op' to every item in the sequence 's' modifying it directly.
---*destructive*
---@generic T, S
---@param op fun(x: T): S
function Seq:apply(op)
    self = Seq.map(self, op)
end

return Seq
