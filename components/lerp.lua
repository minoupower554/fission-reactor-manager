---@param start number the start to interpolate from
---@param stop number the end to interpolate to
---@param factor number the interpolation factor between 0 and 1
---@return number result the result of the interpolation
return function(start, stop, factor)
    return start+(stop-start)*factor
end
