---@param t table
---@return string
return function(t)
    local parts = {}

    -- detect array-like table
    local is_array = true
    local count = 0

    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            is_array = false
            break
        end
        count = count + 1
    end

    if is_array then
        -- check for gaps
        for i = 1, count do
            if t[i] == nil then
                is_array = false
                break
            end
        end
    end

    if is_array then
        for i, v in ipairs(t) do
            parts[#parts + 1] = tostring(i) .. "=" .. tostring(v)
        end
    else
        for k, v in pairs(t) do
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end

    return "{" .. table.concat(parts, "; ") .. "}"
end