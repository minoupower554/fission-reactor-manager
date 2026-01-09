require('types')
local lerp_clamp = require('components.lerp_clamp')
local c = require('config')

---@overload fun(level: string, field: string, log_message: nil)
---@overload fun(level: string, field: nil, log_message: string)
---@param level '"info"'|'"warn"'|'"error"'
---@param field '"reactor_temp"'|'"reactor_cool_level_percent"'|'"turbine_prod_rate"'|'"turbine_buffer_level"'|nil
---@param log_message string|nil
local function queue_write(level, field, log_message)
    os.queueEvent("screen_write", level, field, log_message)
end

local reactor = peripheral.wrap(c.reactor_logic_port_id) -- defining these outside the main function so the crash handler can use them
local e_coolant_relay = peripheral.wrap(c.e_coolant_relay_id)
local turbine = peripheral.wrap(c.turbine_valve_id)
local load = peripheral.wrap(c.resistive_heater_id)

---@cast reactor ReactorPeripheral
---@cast e_coolant_relay RedstoneRelayPeripheral
---@cast turbine TurbinePeripheral
---@cast load ResistiveHeaterPeripheral

local function reactor_manager()
    print("running...")

    if reactor.getStatus() then
        print("stopping reactor for initialization")
        reactor.scram()
        print("waiting 4 seconds for reactor to stabilize post shutdown...")
        sleep(4)
    end

    if reactor.getMaxBurnRate() < c.desired_burn_rate then
        print("desired burn rate is set higher than the reactor is able to run at, please lower the desired burn rate")
        return
    end

    local temp = 0
    local last_temp = 0
    local roc_active = false
    local trip = false
    local e_cooling = false
    local reactor_trip_already_logged = false
    local trip_reset_already_logged = false
    local not_enough_coolant_already_logged = false

    while true do
        if rs.getInput(c.redstone_trip_reset_side) then
            if trip then
                print("trip reset successfully")
                trip = false
                trip_reset_already_logged = true
            else
                if not trip_reset_already_logged then
                    print("the reactor is not tripped")
                    trip_reset_already_logged = true
                end
            end
        end
        if trip then
            if reactor.getStatus() then
                reactor.scram()
            end
        end
        if rs.getInput(c.redstone_reactor_start_side) then
            if not reactor.getStatus() then
                if not trip then
                    if reactor.getCoolantFilledPercentage()>c.minimum_required_coolant/100 then
                        trip_reset_already_logged = false
                        reactor_trip_already_logged = false
                        not_enough_coolant_already_logged = false
                        print("starting reactor")
                        reactor.activate()
                        local timer = os.startTimer(c.startup_timeout)
                        repeat
                            local _, id = os.pullEvent("timer")
                        until id == timer
                        roc_active = true
                        print("rate of change protection armed")
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
                print("disarming rate of change protection")
                roc_active = false
                print("shutting down reactor")
                reactor.scram()
            end
        end
        last_temp = temp
        temp = reactor.getTemperature()
        if temp>=c.overheat_cutoff then
            if trip == false then
            trip = true
            e_cooling = true
            print("temperature threshold trip")
            end
        end

        if not roc_active then
            goto rate_of_change_skip
        end
        if temp-last_temp>c.rate_of_change_margin then
            if trip == false then
                trip = true
                e_cooling = true
                print("rate of change protection trip")
                print("temperature delta:", temp-last_temp)
            end
        end
        ::rate_of_change_skip::

        if e_cooling then
            e_coolant_relay.setOutput(c.e_coolant_relay_side, true)
        end
        if e_coolant_relay.getOutput(c.e_coolant_relay_side) then
            if temp < c.e_coolant_disable then
                e_cooling = false
                e_coolant_relay.setOutput(c.e_coolant_relay_side, false)
            end
        end
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
        return
    end
    print("fatal: the main script crashed. error: "..tostring(err))
    if reactor.getStatus() then
        print("scramming reactor")
        reactor.scram()
    end
    if e_coolant_relay.getOutput(c.e_coolant_relay_side) then
        print("warning: emergency cooling was active and has been disabled")
        e_coolant_relay.setOutput(c.e_coolant_relay_side, false)
    end
    print("writing crash report, see current.log if the error message exceeds the frame size")
    local info = debug.getinfo(1, "S")
    local source = info.source
    if source:sub(1,1) == "@" then
        source = source:sub(2)
        source = fs.getDir(source)
    else
        print("not running as file, writing to rootfs")
        source = "/"
    end
    local path = fs.combine(source, "fission_reactor_controller_crash.log")
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
    if turbine.getMaxProduction() > c.dummy_load_max*1e6 then
        print("Warning: the dummy load maximum is lower than the production capacity of the turbine")
    end

    load.setEnergyUsage(0)

    local max_energy = turbine.getMaxEnergy()
    local start_frac = c.dummy_load_start/100

    while true do
        local current_energy = turbine.getEnergy()
        local fill = current_energy/max_energy
        local usage = 0
        if fill > start_frac then
            local t = (fill-start_frac)/(1-start_frac)
            usage = lerp_clamp(0, c.dummy_load_max*1e6, t)
        end

        load.setEnergyUsage(usage)
    end
end

local function gui_manager()
    while true do
        local event, level, field, log_message = os.pullEvent("screen_write")
    end
end

local function main()
    parallel.waitForAll(reactor_manager, turbine_manager, gui_manager)
end

xpcall(main, crash_protection)
