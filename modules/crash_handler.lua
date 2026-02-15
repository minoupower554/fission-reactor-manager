local s = require('components.state')
local c = require('config')

---@param err any
return function(err)
    if tostring(err) == "Terminated" then
        print("stopped by user...")
        if s.reactor.getStatus() then
            print("shutting down reactor")
            s.reactor.scram()
        end
        if not s.e_coolant_relay.getOutput(c.e_coolant_relay_side) then
            print("warning: emergency cooling was active and has been disabled")
            s.e_coolant_relay.setOutput(c.e_coolant_relay_side, true)
        end
        s.load.setEnergyUsage(0)
        return
    end
    local msg = "fatal: the main script crashed. error: "..tostring(err)
    print(msg)
    if c.enable_chat_box then
        local serialized = textutils.serializeJSON({text=msg, color="red"})
        s.chatbox.sendFormattedMessageToPlayer(serialized, c.username, "reactor crash handler")
    end
    if s.reactor.getStatus() then
        print("scramming reactor")
        s.reactor.scram()
    end
    if not s.e_coolant_relay.getOutput(c.e_coolant_relay_side) then
        print("warning: emergency cooling was active and has been disabled")
        s.e_coolant_relay.setOutput(c.e_coolant_relay_side, true)
    end
    s.load.setEnergyUsage(0)
    print("writing crash report, see last_crash.log")
    local info = debug.getinfo(1, "S")
    local src = info.source
    if src:sub(1,1) == "@" then
        src = src:sub(2)
        src = fs.getDir(src)
    else
        print("not running as file, writing to rootfs")
        src = "/"
    end
    local path = fs.combine(src, "last_crash.log")
    local handle = fs.open(path, "w")
    if handle then
        handle.writeLine(tostring(err))
        handle.close()
    end
end
