---@param x number the number to round
---@param step number the step to round to
---@return number result the result of the rounding
return function(x, step)
    return math.floor(x/step+0.5)*step
end
