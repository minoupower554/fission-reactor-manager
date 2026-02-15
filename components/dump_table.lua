--- turn a table into a string, throws when invalid arguments are passed
---@param t table The table to convert
---@param pretty boolean? Whether to write a pretty multiline string
---@param indent number? The number of spaces to use per level deeper into tables, ignored in non-pretty mode and defaults to 4
---@return string
return function(t, pretty, indent)
    if type(t) ~= "table" then error("InvalidArgumentError: The first argument has to be a table", 2) end
    if type(pretty) == "nil" then
        pretty = false
    elseif type(pretty) ~= "boolean" then
        error("InvalidArgumentError: the second argument has to be a boolean", 2)
    end
    if type(indent) == "nil" then
        indent = 4
    elseif type(indent) ~= "number" or math.abs(indent)~=indent or indent%1~=0 then
        error("the indent has to be a valid positive integer or nil", 2)
    end
    local function recurse(tab, depth, seen)
        if #tab == 0 then
            return "{}"
        end
        local is_array = true
        local count = 1

        for k, _ in pairs(tab) do
            if type(k) ~= "number" then
                is_array = false
                break
            elseif k%1~=0 then
                is_array = false
                break
            elseif k~=count then
                is_array = false
                break
            end
            count = count + 1
        end

        local result = ""
        if pretty then
            result = "{\n"
        else
            result = "{"
        end

        local prefix = (" "):rep(indent*depth+indent)

        if is_array then
            for _, v in ipairs(tab) do
                if pretty then
                    if type(v) == "table" then
                        if seen[tostring(v)] then
                            result = result.."<circular reference>"..",\n"
                        else
                            seen[tostring(v)] = true
                            result = result..prefix..recurse(v, depth+1, seen)..",\n"
                        end
                    else
                        result = result..prefix..v..",\n"
                    end
                else
                    if type(v) == "table" then
                        if seen[tostring(v)] then
                            result = result.."<circular reference>"..", "
                        else
                            seen[tostring(v)] = true
                            result = result..recurse(v, depth+1, seen)..", "
                        end
                    else
                        result = result..v..", "
                    end
                end
            end
        else
            for k, v in pairs(tab) do
                if pretty then
                    if type(v) == "table" then
                        if seen[v] then
                            result = result..prefix..k..": <circular reference>"..",\n"
                        else
                            result = result..prefix..k..": "..recurse(v, depth+1, seen)..",\n"
                        end
                    else
                        result = result..prefix..k..": "..v..",\n"
                    end
                else
                    if type(v) == "table" then
                        if seen[v] then
                            result = result..k..": <circular reference>"..", "
                        else
                            result = result..k..": "..recurse(v, depth+1, seen)..", "
                        end
                    else
                        result = result..k..": "..v..", "
                    end
                end
            end
        end

        if pretty then
            result = result:sub(1, -3)..(" "):rep(indent*depth).."\n}"
        else
            result = result:sub(1, -3).."}"
        end

        return result
    end
    local seen = {}
    local result = recurse(t, 0, seen)
    return result
end
