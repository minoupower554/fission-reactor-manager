---@param start number the start to interpolate from
---@param stop number the end to interpolate to
---@param factor number the interpolation factor between 0 and 1
---@return number result the result of the interpolation
return function(start, stop, factor)
    if factor < 0 then
        factor = 0
    elseif factor > 1 then
        factor = 1
    end
    return require('components.lerp')(start, stop, factor)
end