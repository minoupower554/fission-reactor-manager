local s = require('components.state')
local c = require('config')

return function()
    while true do
        local _, monitor_id, x, y = os.pullEvent("monitor_touch")
        if monitor_id == c.reactor_display then
            if y == s.height and x<=10 then
                s.trip_reset = true
            elseif y == s.height and x>=s.width-5 then
                s.reactor_state = not s.reactor_state
            end
        end
    end
end
