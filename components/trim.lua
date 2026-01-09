---@param s string The string to trim
---@return string result The trimmed string
return function(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end
