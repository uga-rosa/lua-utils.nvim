---@class Regex
---@field _pattern string
local Regex = {}
Regex.__index = Regex

local regex = {}

---Returns Regex object.
---Note: the capture is the region between `\zs` and `\ze`, as it is a Vim regular expression.
---@param pat string
---@return Regex
function regex.re(pat)
    vim.validate({ pat = { pat, "s" } })
    return setmetatable({
        _pattern = pat,
    }, Regex)
end

---Similar to string.find().
---Unlike string.find(), a negative number in init will be converted to 1.
---Also, return the matched string as the third return value even if it is not captured.
---@param s string
---@param pattern string
---@param init? integer
---@return integer? start
---@return integer? end
---@return string? matched
function regex.find(s, pattern, init)
    vim.validate({
        s = { s, "s" },
        pattern = { pattern, "s" },
        init = { init, "n", true },
    })
    init = vim.F.if_nil(init, 1)
    ---Lua is 1-index, but vim is 0-index
    init = init - 1

    local pos = vim.fn.matchstrpos(s, pattern, init)
    local mat, start, end_ = unpack(pos)
    if start == -1 then
        return
    end
    start = start + 1
    return start, end_, mat
end

---Similar to string.match().
---Unlike string.match(), a negative number in init will be converted to 1.
---@param s string
---@param pattern string
---@param init? integer
---@return string?
function regex.match(s, pattern, init)
    vim.validate({
        s = { s, "s" },
        pattern = { s, "s" },
        init = { init, "n", true },
    })
    init = vim.F.if_nil(init, 1)
    ---Lua is 1-index, but vim is 0-index
    init = init - 1

    local mat = vim.fn.matchstr(s, pattern, init)
    if mat ~= "" then
        return mat
    end
end

---Similar to string.gmatch().
---@param s string
---@param pattern string
---@return function
function regex.gmatch(s, pattern)
    vim.validate({
        s = { s, "s" },
        pattern = { pattern, "s" },
    })
    local pos = 1
    return function()
        local _, end_, matched = regex.find(s, pattern, pos)
        if end_ then
            pos = end_ + 1
            return matched
        end
    end
end

---Wrapper for substitute().
---Unlike string.gsub(), it only accepts a string in `repl`.
---@param s string
---@param pattern string
---@param repl string
---@param flag? string
---@return string
function regex.gsub(s, pattern, repl, flag)
    vim.validate({
        s = { s, "s" },
        pattern = { pattern, "s" },
        repl = { repl, "s" },
        flag = { flag, "s", true },
    })

    return vim.fn.substitute(s, pattern, repl, flag)
end

---Similar to vim.gsplit().
---@param s string
---@param pattern string
---@return function
function regex.gsplit(s, pattern)
    vim.validate({
        s = { s, "s" },
        pattern = { pattern, "s" },
    })

    local init = 1
    local done = false

    local function _pass(i, j, ...)
        if i then
            assert(j + 1 > init, "Infinite loop detected")
            local seg = s:sub(init, i - 1)
            init = j + 1
            return seg, ...
        else
            done = true
            return s:sub(init)
        end
    end

    return function()
        if done or (s == "" and pattern == "") then
            return
        end
        if pattern == "" then
            if init == #s then
                done = true
            end
            return _pass(init + 1, init)
        end
        return _pass(regex.find(s, pattern, init))
    end
end

---Similar to vim.split().
---@param s string
---@param pattern string
---@return string[]
function regex.split(s, pattern)
    vim.validate({
        s = { s, "s" },
        pattern = { pattern, "s" },
    })

    local t = {}
    for w in regex.gsplit(s, pattern) do
        table.insert(t, w)
    end
    return t
end

---========================================
---              METHOD
---========================================

---Method version of regex.find().
---
---Similar to string.find().
---Unlike string.find(), a negative number in init will be converted to 1.
---Also, return the matched string as the third return value even if it is not captured.
---@param s string
---@param init? integer
---@return integer? start
---@return integer? end
---@return string? matched
function Regex:find(s, init)
    return regex.find(s, self._pattern, init)
end

---Method version of regex.match().
---
---Similar to string.match().
---Unlike string.match(), a negative number in init will be converted to 1.
---@param s string
---@param init? integer
---@return string?
function Regex:match(s, init)
    return regex.match(s, self._pattern, init)
end

---Method version of regex.gmatch().
---
---Similar to string.gmatch().
---@param s any
---@return function
function Regex:gmatch(s)
    return regex.gmatch(s, self._pattern)
end

---Method version of regex.gsub().
---
---Wrapper for substitute().
---Unlike string.gsub(), it only accepts a string in `repl`.
---@param s string
---@param repl string
---@param flag? string
---@return string
function Regex:gsub(s, repl, flag)
    return regex.gsub(s, self._pattern, repl, flag)
end

---Method version of regex.gsplit().
---
---Similar to vim.gsplit().
---@param s string
---@return function
function Regex:gsplit(s)
    return regex.gsplit(s, self._pattern)
end

---Method version of regex.split().
---
---Similar to vim.split().
---@param s string
---@return string[]
function Regex:split(s)
    return regex.split(s, self._pattern)
end

return regex
