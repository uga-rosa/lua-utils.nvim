local utils = require("lua-utils.utils")
local assertf = utils.assertf
local assert_type = utils.assert_type
local assert_not_nil = utils.assert_not_nil

---============================================
---                 CLASS
---============================================

---@class Array any[]

---An Wrapped array whose elements are all of the same type T.
---@class Seq
---@field private _data Array
---@field private _len integer
local Seq = {}
Seq.__index = Seq

---Returns the entire raw array.
---Getter for _data
---@return Array
function Seq:unpack()
    return self._data
end

---Returns the length of the Seq.
---Getter for _len
---@return integer
function Seq:len()
    return self._len
end

---@param self Seq
---@return string
Seq.__tostring = function(self)
    local data = "[" .. table.concat(self._data, ", ") .. "]"
    return "@" .. data
end

---@param s1 Seq
---@param s2 Seq
---@return Seq
Seq.__concat = function(s1, s2)
    local new = {}
    for i, v in ipairs(s1._data) do
        new[i] = v
    end
    for _, v in ipairs(s2._data) do
        table.insert(new, v)
    end
    return Seq.new(new)
end

---============================================
---                 METHOD
---============================================

---============================================
---             BASIC OPERATION
---============================================

---Generates Seq from array.
---@param arr Array | Seq
---@return Seq
function Seq.new(arr)
    if getmetatable(arr) == Seq then
        ---@cast arr Seq
        return arr
    end
    assert_type(arr, "array")

    return setmetatable({
        _data = arr,
        _len = #arr,
    }, Seq)
end

---Generates Seq with a length of `len` and all elements filled with `init`.
---`init` is copied shallowy, so be careful when passing the table.
---`init` is not optional, but can be omitted only when `len` is 0 as an exception.
---@param len integer
---@param init any
---@return Seq
function Seq.newWith(len, init)
    assert_type(len, "non_negative_integer")
    if len == 0 then
        return setmetatable({
            _data = {},
            _len = 0,
        }, Seq)
    end

    assert_not_nil(init)
    local data = {}
    for i = 1, len do
        data[i] = init
    end
    return setmetatable({
        _data = data,
        _len = len,
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
---@param src Array | Seq
---@param pos? integer #If i is omitted, added at the end of 'dst'.
function Seq:insert(src, pos)
    src = Seq.new(src)

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
---@param i integer
---@param j? integer #Default: Same as 'i'
function Seq:delete(i, j)
    assert_index(self._len, i)
    j = vim.F.if_nil(j, i)
    assert_index(self._len, j)
    assertf(i <= j, "i (%s) must be less than or equal to j (%s)", i, j)

    for _ = i, j do
        table.remove(self._data, i)
    end
    self._len = self._len - (j - i + 1)
end

---Get the slice of Seq 's' from i-th to j-th (including the ends of the range).
---@param s Array | Seq
---@param i integer
---@param j? integer #Default: Same as 'i'
---@return Seq
function Seq.slice(s, i, j)
    s = Seq.new(s)
    assert_index(s._len, i)
    j = vim.F.if_nil(j, i)
    assert_index(s._len, j)
    assertf(i <= j, "i (%s) must be less than or equal to j (%s)", i, j)

    local result = {}
    for k = i, j do
        table.insert(result, s._data[k])
    end

    return Seq.new(result)
end

---Similier to table.remove().
---@param pos? integer #Default: self:len()
---@return Seq
function Seq:pop(pos)
    pos = vim.F.if_nil(pos, self._len)
    assert_index(self._len, pos)
    self._len = self._len - 1
    return table.remove(self._data, pos)
end

---============================================
---                 UTILITIES
---============================================

---Checks if every item fulfills 'pred'.
---@param s Array | Seq
---@param pred fun(x: any): boolean
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
---@param s Array | Seq
---@param pred fun(x: any): boolean
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
---@param s Array | Seq
---@param x any
---@return integer
function Seq.count(s, x)
    s = Seq.new(s)

    local c = 0
    for _, v in ipairs(s._data) do
        if v == x then
            c = c + 1
        end
    end
    return c
end

---Returns a new sequence without duplicates.
---@param s Array | Seq
---@return Seq
function Seq.deduplicate(s)
    s = Seq.new(s)

    ---@type table<any, boolean>
    local set = {}
    ---@type Array
    local new = {}
    for _, v in ipairs(s._data) do
        if not set[v] then
            set[v] = true
            table.insert(new, v)
        end
    end
    return Seq.new(new)
end

---Returns a new Seq with all the items of 's' that fulfill the predicate 'pred'.
---@param s Array | Seq
---@param pred fun(x: any): boolean
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
    return Seq.new(new)
end

---Keeps the items in the passed sequence 's' if they fulfill the predicate 'pred'.
---*destructive*
---@param pred fun(x: any): boolean
function Seq:keepIf(pred)
    self = Seq.filter(self, pred)
end

---Returns a new sequence with the results of the 'op' function applied to every item in the sequence 's'.
---@param s Array | Seq
---@param op fun(x: any): any
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
---@param op fun(x: any): any
function Seq:apply(op)
    self = Seq.map(self, op)
end

return Seq
