local utils = {}

---@generic T
---@param value `T`
---@param default T
---@return T
function utils.set_default(value, default)
    if value == nil then
        return default
    end
    return value
end

---Error with formatted message
---@param msg string
---@param ... any
function utils.errorf(msg, ...)
    local args = { ... }
    if #args > 0 then
        for i, a in ipairs(args) do
            args[i] = vim.inspect(a)
        end
        msg = string.format(msg, unpack(args))
    end
    error(msg, 2)
end

---Assert with formatted message.
---@param v boolean
---@param msg string
---@param ... any
function utils.assertf(v, msg, ...)
    local args = { ... }
    if #args > 0 then
        for i, a in ipairs(args) do
            args[i] = vim.inspect(a)
        end
        msg = string.format(msg, unpack(args))
    end
    if not v then
        error(msg, 2)
    end
end

---In addition to the type_utils, the following are also included.
--- - number
--- - natural
--- - zero
--- - non_negative_integer
--- - negative_integer
---@alias correct_type
--- | '"nil"'
--- | '"boolean"'
--- | '"number"'
--- | '"integer"'
--- | '"natural"'
--- | '"zero"'
--- | '"non_negative_integer"'
--- | '"negative_integer"'
--- | '"float"'
--- | '"string"'
--- | '"function"'
--- | '"userdata"'
--- | '"thread"'
--- | '"table"'
--- | '"array"'

local is_correct_type = {
    ["nil"] = true,
    boolean = true,
    number = true,
    integer = true,
    non_negative_integer = true,
    negative_integer = true,
    natural = true,
    float = true,
    string = true,
    ["function"] = true,
    userdata = true,
    thread = true,
    table = true,
    array = true,
}

---Check if 'tn' is a predefined type name.
---@param tn correct_type
function utils.assert_type_name(tn)
    utils.assertf(is_correct_type[tn], "Invalid type name: %s", tn)
end

---@alias type_utils
--- | '"nil"'
--- | '"boolean"'
--- | '"integer"'
--- | '"float"'
--- | '"string"'
--- | '"function"'
--- | '"userdata"'
--- | '"thread"'
--- | '"table"'
--- | '"array"'

---Similar functions to the built-in type(), but with the addition of the following.
--- - array: A table whose keys are sequentially numbered from 1.
--- - integer: An integer.
--- - float: A decimal.
---'integer' or 'float' is returned, so 'number' is never returned.
---@param obj any
---@return type_utils
function utils.type(obj)
    local type_name = type(obj)

    if type_name == "table" then
        -- Check if an array
        -- An empty table ('{}') is determined to be a table.
        if next(obj) == nil then
            return "table"
        end

        local i = 0
        for _ in pairs(obj) do
            i = i + 1
            if obj[i] == nil then
                return "table"
            end
        end
        return "array"
    elseif type_name == "number" then
        -- Check if an integer
        if (obj % 1) .. "" == "0" then
            return "integer"
        else
            return "float"
        end
    end

    return type_name
end

---Check if a type of 'obj' is 'expect_type'.
---@param obj any
---@param expect_type correct_type
---@param optional? boolean #Whether nil is acceptable.
function utils.assert_type(obj, expect_type, optional)
    utils.assert_type_name(expect_type)

    if optional and obj == nil then
        return
    end

    local actual_type
    if expect_type == "number" then
        actual_type = type(obj)
    else
        actual_type = utils.type(obj)
        if actual_type == "integer" then
            if expect_type == "natural" or expect_type == "zero" then
                if obj > 0 then
                    actual_type = "natural"
                elseif obj == 0 then
                    actual_type = "zero"
                else
                    actual_type = "negative_integer"
                end
            elseif expect_type == "non_negative_integer" or expect_type == "negative_integer" then
                if obj >= 0 then
                    actual_type = "non_negative_integer"
                else
                    actual_type = "negative_integer"
                end
            elseif expect_type == "float" then
                actual_type = "float"
            end
        end
    end
    utils.assertf(
        expect_type == actual_type,
        "Wrong type of `%s`, expected %s, but %s",
        obj,
        expect_type,
        actual_type
    )
end

---Check if a is nil
---@param a any
function utils.assert_not_nil(a)
    utils.assertf(a ~= nil, "Assertion: nil check")
end

return utils
