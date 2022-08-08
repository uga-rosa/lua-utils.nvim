local Seq = require("lua-utils.seq")

---Seq consisting of numbers only.
---@class Vector : Seq
---@field _data number[]
---@field _type nil
local Vector = setmetatable({}, { __index = Seq })
Vector.__index = Vector

---Constructor
---@param arr number[]
---@param skipValidation boolean
---@return Vector
---@return Error?
function Vector.new(arr, skipValidation)
    local seq, err = Seq.newWith(arr, skipValidation)
    if err then
        return Vector.new({}, true), err
    end

    if seq:type() ~= "number" then
        return Vector.new({}, true)
    end

    local vec = setmetatable(seq, Vector)
    return vec
end

return Vector
