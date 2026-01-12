local s = require('components.state')
local c = require('config')
local trim = require('components.trim')

return function()
    while true do
        local _, user, msg, _, hidden, _ = os.pullEvent("chat")
        if user:lower() == c.username:lower() and hidden then ---@diagnostic disable-line
            msg = trim(msg)
            if msg == "reactor start" then
                if not s.reactor_state then
                    s.reactor_state = true
                    s.chatbox.sendMessageToPlayer("reactor starting", c.username, "reactor")
                else
                    s.chatbox.sendMessageToPlayer("reactor already running", c.username, "reactor")
                end
            elseif msg == "reactor stop" then
                if s.reactor_state then
                    s.reactor_state = false
                    s.chatbox.sendMessageToPlayer("reactor shutting down", c.username, "reactor")
                else
                    s.chatbox.sendMessageToPlayer("reactor not running", c.username, "reactor")
                end
            end
        end
    end
end
