require('types')
local lerp_clamp = require('components.lerp_clamp')
local c = require('config')
local round = require('components.round')
local trim = require('components.trim')

---@param level '"info"'|'"warn"'|'"error"' the log level to use, changes the colour of the field on the screen when applicable
---@param log_message string|'"none"' the message to log, use none for no message
---@param field '"reactor_temp"'|'"reactor_cool_level_percent"'|'"turbine_prod_rate"'|'"turbine_buffer_level"'|'"resistive_heater_load"'|'"trip_status"'|'"last_trip_type"'|'"roc_state"'|nil the field to edit, nil for no field edit
---@param value string|nil the value to set the field to, nil for no field edit
local function queue_write(level, log_message, field, value)
    os.queueEvent("screen_write", level, log_message, field, value)
end

local reactor = peripheral.wrap(c.reactor_logic_port_id) -- defining these outside the main function so the crash handler can use them
local e_coolant_relay = peripheral.wrap(c.e_coolant_relay_id)
local turbine = peripheral.wrap(c.turbine_valve_id)
local load = peripheral.wrap(c.resistive_heater_id)
local screen = peripheral.wrap(c.reactor_display)
local chatbox = peripheral.wrap(c.chatbox_id)
---@cast reactor ReactorPeripheral
---@cast e_coolant_relay RedstoneRelayPeripheral
---@cast turbine TurbinePeripheral
---@cast load ResistiveHeaterPeripheral
---@cast screen MonitorPeripheral
---@cast chatbox ChatBoxPeripheral

local trip_reset = false -- im sure using global state wont bite me later
local reactor_state = false
local trip = false
local width, height = screen.getSize()

local function reactor_manager()
    print("running...")

    if reactor.getStatus() then
        print("stopping reactor for initialization")
        reactor.scram()
        print("waiting 2 seconds for reactor to stabilize post shutdown...")
        sleep(2)
    end

    if reactor.getMaxBurnRate() < c.desired_burn_rate then
        print("desired burn rate is set higher than the reactor is able to run at, please lower the desired burn rate")
        return
    end

    local temp = 0
    local last_temp = 0
    local roc_active = false
    local e_cooling = false
    local reactor_trip_already_logged = false
    local not_enough_coolant_already_logged = false

    queue_write("info", "none", "trip_status", "no")
    queue_write("warn", "none", "roc_state", "disarmed")

    while true do
        if trip_reset then
            if trip then
                trip = false
                trip_reset = false
                queue_write("info", "trip reset successfully", "trip_status", "no")
                queue_write("warn", "none", "roc_state", "disarmed")
            end
        end
        if trip then
            queue_write("error", "none", "trip_status", "yes")
            if reactor.getStatus() then
                reactor.scram()
            end
            reactor_state = false
        end
        if reactor_state then
            if not reactor.getStatus() then
                if not trip then
                    if reactor.getCoolantFilledPercentage()>c.minimum_required_coolant/100 then
                        reactor_trip_already_logged = false
                        not_enough_coolant_already_logged = false
                        queue_write("warn", "starting reactor")
                        reactor.activate()
                        local timer = os.startTimer(c.startup_timeout)
                        repeat
                            local _, id = os.pullEvent("timer")
                        until id == timer
                        roc_active = true
                        queue_write("info", "rate of change protection armed", "roc_state", "armed")
                        temp = reactor.getTemperature()
                        last_temp = temp
                    else
                        if not not_enough_coolant_already_logged then
                            print("the reactor does not have enough coolant, refusing startup")
                            not_enough_coolant_already_logged = true
                        end
                    end
                else
                    if not reactor_trip_already_logged then
                        print("the reactor is tripped, refusing startup")
                        reactor_trip_already_logged = true
                    end
                end
            end
        else
            if reactor.getStatus() then
                queue_write("warn", "disarming rate of change protection", "roc_state", "disarmed")
                roc_active = false
                print("shutting down reactor")
                reactor.scram()
            end
        end
        last_temp = temp
        temp = reactor.getTemperature()
        queue_write("info", "none", "reactor_temp", (round(temp-273.15, 0.1)).."C")
        local coolant_level = round(reactor.getCoolantFilledPercentage()*100, 0.01)
        if coolant_level < 10 then
            queue_write("error", "none", "reactor_cool_level_percent", coolant_level.."%")
        elseif coolant_level < 30 then
            queue_write("warn", "none", "reactor_cool_level_percent", coolant_level.."%")
        else
            queue_write("info", "none", "reactor_cool_level_percent", coolant_level.."%")
        end

        if temp>=c.overheat_cutoff then
            if trip == false then
                trip = true
                e_cooling = true
                queue_write("info", "none", "last_trip_type", "Temperature Threshold exceeded")
                queue_write("error", "temperature threshold trip")
            end
        end

        if roc_active then
            if temp-last_temp>c.rate_of_change_margin then
                if trip == false then
                    trip = true
                    e_cooling = true
                    queue_write("error", "none", "roc_state", "active")
                    queue_write("error", "rate of change protection trip")
                    queue_write("info", "none", "last_trip_type", "Rate of Change Margin exceeded")
                    queue_write("info", "temperature delta: "..temp-last_temp)
                end
            end
        end

        if e_cooling then
            e_coolant_relay.setOutput(c.e_coolant_relay_side, true)
        end
        if e_coolant_relay.getOutput(c.e_coolant_relay_side) then
            if temp < c.e_coolant_disable then
                e_cooling = false
                e_coolant_relay.setOutput(c.e_coolant_relay_side, false)
            end
        end
        os.sleep(0)
    end
end

---@param err any
local function crash_protection(err)
    if tostring(err) == "Terminated" then
        print("stopped by user...")
        if reactor.getStatus() then
            print("shutting down reactor")
            reactor.scram()
        end
        if e_coolant_relay.getOutput(c.e_coolant_relay_side) then
            print("warning: emergency cooling was active and has been disabled")
            e_coolant_relay.setOutput(c.e_coolant_relay_side, false)
        end
        load.setEnergyUsage(0)
        return
    end
    local msg = "fatal: the main script crashed. error: "..tostring(err)
    print(msg)
    if c.enable_chat_box then
        local serialized = textutils.serializeJSON({text=msg, color="red"})
        chatbox.sendFormattedMessageToPlayer(serialized, c.username, "reactor crash handler")
    end
    if reactor.getStatus() then
        print("scramming reactor")
        reactor.scram()
    end
    if e_coolant_relay.getOutput(c.e_coolant_relay_side) then
        print("warning: emergency cooling was active and has been disabled")
        e_coolant_relay.setOutput(c.e_coolant_relay_side, false)
    end
    load.setEnergyUsage(0)
    print("writing crash report, see current.log")
    local info = debug.getinfo(1, "S")
    local source = info.source
    if source:sub(1,1) == "@" then
        source = source:sub(2)
        source = fs.getDir(source)
    else
        print("not running as file, writing to rootfs")
        source = "/"
    end
    local path = fs.combine(source, "current.log")
    if fs.exists(path) then
        print("crash log already exists at '"..path.."'. overriding")
    end
    local handle = fs.open(path, "w")
    if handle then
        handle.writeLine(tostring(err))
        handle.close()
    end
end

local function turbine_manager()
    load.setEnergyUsage(0)

    local max_energy = turbine.getMaxEnergy()
    if c.dummy_load_max == "auto" then
        c.dummy_load_max = turbine.getMaxProduction()/1e6
    end
    if turbine.getMaxProduction() > c.dummy_load_max*1e6 then
        print("Warning: the dummy load maximum is lower than the production capacity of the turbine")
    end
    local start_frac = c.dummy_load_start/100

    while true do
        local current_energy = turbine.getEnergy()
        queue_write("info", "none", "turbine_buffer_level", (round(current_energy/1e6, 1)).."MJ")
        local fill = current_energy/max_energy
        local usage = 0
        if fill > start_frac then
            local t = (fill-start_frac)/(1-start_frac)
            usage = lerp_clamp(0, c.dummy_load_max*1e6, t)
        end

        load.setEnergyUsage(usage)
        queue_write("info", "none", "resistive_heater_load", (round(usage/1e3, 0.1)).."kJ/t")
        queue_write("info", "none", "turbine_prod_rate", (round(turbine.getProductionRate()/1e3, 1)).."kJ/t")
        os.sleep(0)
    end
end

local function write_manager()
    screen.setTextScale(1)
    screen.setTextColor(colors.white)
    screen.setBackgroundColor(colors.black)
    screen.setCursorBlink(false)
    if width ~= 29 or height ~= 12 then
        print("the screen has to be 3x2")
        error("invalid screen size")
    end

    local fields = {
        {reactor_temp="0N/A"},
        {reactor_cool_level_percent="0N/A"},
        {turbine_prod_rate="0N/A"},
        {turbine_buffer_level="0N/A"},
        {resistive_heater_load="0N/A"},
        {"space"},
        {roc_state="0N/A"},
        {trip_status="0N/A"},
        {last_trip_type="0N/A"}
    }
    local pretty_print = {reactor_temp="Reactor Temperature: ",
        reactor_cool_level_percent="Reactor Coolant Level: ",
        turbine_prod_rate="Turbine Production: ",
        turbine_buffer_level="Turbine Power Level: ",
        resistive_heater_load="Dummy Load Usage: ",
        trip_status="Reactor Trip: ",
        last_trip_type="Last Reactor Trip: ",
        roc_state="RoC Prot: "
    }

    while true do
        screen.setCursorPos(1, 1)
        local _, level, log_message, field, value = os.pullEvent("screen_write")
        if field then
            local prefix
            if level == "info" then
                prefix = "0"
            elseif level == "warn" then
                prefix = "1"
            else
                prefix = "e"
            end

            for _, entry in ipairs(fields) do
                if entry[field] ~= nil then
                    entry[field] = prefix..value
                    break
                end
            end
        end
        if log_message ~= "none" then
            if c.enable_chat_box then
                if level == "info" then
                    if c.chat_box_log_level == "info" then
                        chatbox.sendMessageToPlayer(log_message, c.username, "reactor")
                    end
                elseif level == "warn" then
                    if c.chat_box_log_level == "warn" then
                        local serialized = textutils.serializeJSON({text=log_message, color="gold"})
                        chatbox.sendFormattedMessageToPlayer(serialized, c.username, "reactor")
                    end
                elseif level == "error" then
                    local serialized = textutils.serializeJSON({text=log_message, color="red"})
                    chatbox.sendFormattedMessageToPlayer(serialized, c.username, "reactor")
                end
            end
            if level == "info" then
                print(log_message)
            elseif level == "warn" then
                term.setTextColor(colors.orange)
                print(log_message)
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.red)
                print(log_message)
                term.setTextColor(colors.white)
            end
        end
        screen.clear()
        for i, v in ipairs(fields) do
            for k, v in pairs(v) do
                if type(k) == "number" then -- for empty lines
                    goto continue
                end
                screen.setCursorPos(1, i)
                local str = v:sub(2)
                local print_string = pretty_print[k]..str
                local blit = v:sub(1, 1)
                if print_string:len() > width then
                    local split = {}
                    local total_length = 0
                    for part in print_string:gmatch("([^ ]+)") do
                        part = part.." "
                        total_length = total_length+part:len()
                        if total_length > width then
                            table.insert(split, "newline_abcd1234randomcharacterssotheresnochanceofitclashing")
                            total_length = 0
                        end
                        table.insert(split, part)
                    end
                    for _, v in ipairs(split) do
                        if v == "newline_abcd1234randomcharacterssotheresnochanceofitclashing" then
                            local _, y = screen.getCursorPos()
                            screen.setCursorPos(1, y+1)
                            goto continue_multiline_blit
                        end
                        screen.blit(v, blit:rep(v:len()), ("f"):rep(v:len()))
                        ::continue_multiline_blit::
                    end
                else
                    screen.blit(print_string, blit:rep(print_string:len()), ("f"):rep(print_string:len()))
                end
                ::continue::
            end
        end
        screen.setCursorPos(1, height)
        if trip then
            screen.setBackgroundColor(colors.green)
        else
            screen.setBackgroundColor(colors.red)
        end
        screen.write("TRIP RESET")
        if reactor_state then
            screen.setBackgroundColor(colors.red)
        else
            screen.setBackgroundColor(colors.green)
        end
        screen.setCursorPos(width-5, height)
        screen.write("TOGGLE")
        screen.setBackgroundColor(colors.black)
    end
end

local function press_manager()
    while true do
        local _, monitor_id, x, y = os.pullEvent("monitor_touch")
        if monitor_id == c.reactor_display then
            if y == height and x<=10 then
                trip_reset = true
            elseif y == height and x>=width-5 then
                reactor_state = not reactor_state
            end
        end
    end
end

local function chat_command_handler()
    while true do
        local _, user, msg, _, hidden, _ = os.pullEvent("chat")
        if user:lower() == c.username and hidden then ---@diagnostic disable-line
            msg = trim(msg)
            if msg == "reactor start" then
                if not reactor_state then
                    reactor_state = true
                    chatbox.sendMessageToPlayer("reactor starting", c.username, "reactor")
                else
                    chatbox.sendMessageToPlayer("reactor already running", c.username, "reactor")
                end
            elseif msg == "reactor stop" then
                if reactor_state then
                    reactor_state = false
                    chatbox.sendMessageToPlayer("reactor shutting down", c.username, "reactor")
                else
                    chatbox.sendMessageToPlayer("reactor not running", c.username, "reactor")
                end
            end
        end
    end
end

local function main()
    if c.enable_chat_box and c.chat_box_commands then
        parallel.waitForAll(reactor_manager, turbine_manager, write_manager, press_manager, chat_command_handler)
    else
        parallel.waitForAll(reactor_manager, turbine_manager, write_manager, press_manager)
    end
end

xpcall(main, crash_protection)
