local s = require('components.state')
local c = require('config')
local round = require('components.round')

return function()
    print("running...")

    if s.reactor.getStatus() then
        print("stopping reactor for initialization")
        s.reactor.scram()
        print("waiting 2 seconds for reactor to stabilize post shutdown...")
        sleep(2)
    end

    if s.reactor.getMaxBurnRate() < c.desired_burn_rate then
        print("desired burn rate is set higher than the reactor is able to run at, please lower the desired burn rate")
        return
    end

    local temp = 0
    local last_temp = 0
    local roc_active = false
    local e_cooling = false

    s.queue_write("info", "none", "trip_status", "no")
    s.queue_write("warn", "none", "roc_state", "disarmed")

    while true do
        if s.trip_reset then
            if s.trip then
                s.trip = false
                s.trip_reset = false
                s.queue_write("info", "trip reset successfully", "trip_status", "no")
                s.queue_write("warn", "none", "roc_state", "disarmed")
            end
        end
        if s.trip then
            s.queue_write("error", "none", "trip_status", "yes")
            if s.reactor.getStatus() then
                s.reactor.scram()
            end
            s.reactor_state = false
        end
        if s.reactor_state then
            if not s.reactor.getStatus() then
                if not s.trip then
                    if s.reactor.getCoolantFilledPercentage()>c.minimum_required_coolant/100 then
                        s.queue_write("info", "starting reactor")
                        s.reactor.activate()
                        local timer = os.startTimer(c.startup_timeout)
                        repeat
                            local _, id = os.pullEvent("timer")
                        until id == timer
                        roc_active = true
                        s.queue_write("warn", "rate of change protection armed", "roc_state", "armed")
                        temp = s.reactor.getTemperature()
                        last_temp = temp
                    else
                        s.queue_write("warn", "the reactor does not have enough coolant, refusing startup")
                    end
                else
                    s.queue_write("warn", "the reactor is tripped, refusing startup")
                end
            end
        else
            if s.reactor.getStatus() then
                s.queue_write("info", "shutting down reactor")
                s.queue_write("warn", "disarming rate of change protection", "roc_state", "disarmed")
                roc_active = false
                s.reactor.scram()
            end
        end
        last_temp = temp
        temp = s.reactor.getTemperature()
        s.queue_write("info", "none", "reactor_temp", (round(temp-273.15, 0.1)).."C")
        local coolant_level = round(s.reactor.getCoolantFilledPercentage()*100, 0.01)
        if coolant_level < 10 then
            s.queue_write("error", "none", "reactor_cool_level_percent", coolant_level.."%")
        elseif coolant_level < 30 then
            s.queue_write("warn", "none", "reactor_cool_level_percent", coolant_level.."%")
        else
            s.queue_write("info", "none", "reactor_cool_level_percent", coolant_level.."%")
        end

        if temp>=c.overheat_cutoff then
            if s.trip == false then
                s.trip = true
                e_cooling = true
                s.queue_write("info", "none", "last_trip_type", "Temperature Threshold exceeded")
                s.queue_write("error", "temperature threshold trip")
            end
        end

        if roc_active then
            if temp-last_temp>c.rate_of_change_margin then
                if s.trip == false then
                    s.trip = true
                    e_cooling = true
                    s.queue_write("error", "none", "roc_state", "active")
                    s.queue_write("error", "rate of change protection trip")
                    s.queue_write("info", "none", "last_trip_type", "Rate of Change Margin exceeded")
                    s.queue_write("info", "temperature delta: "..temp-last_temp)
                end
            end
        end

        if e_cooling then
            s.e_coolant_relay.setOutput(c.e_coolant_relay_side, true)
        end
        if s.e_coolant_relay.getOutput(c.e_coolant_relay_side) then
            if temp < c.e_coolant_disable then
                e_cooling = false
                s.e_coolant_relay.setOutput(c.e_coolant_relay_side, false)
            end
        end
        s.reactor.setBurnRate(c.desired_burn_rate)
        os.sleep(0.05)
    end
end
