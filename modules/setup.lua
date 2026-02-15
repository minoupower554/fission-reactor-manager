local c = require('config')

return function()
    if peripheral.isPresent(c.reactor_logic_port_id) then
        if peripheral.getType(c.reactor_logic_port_id)=="fissionReactorLogicAdapter" then
            print("Reactor Logic Adapter: valid")
        else
            print("Reactor Logic Adapter: invalid")
            error("Reactor Logic Adapter has to be be a mekanism Fission Reactor Logic Adapter")
        end
    else
        print("Reactor Logic Adapter: not found")
        error("Reactor Logic Adapter is required")
    end
    if peripheral.isPresent(c.turbine_valve_id) then
        if peripheral.getType(c.turbine_valve_id) == "turbineValve" then
            print("Turbine Valve: valid")
        else
            print("Turbine Valve: invalid")
            error("Turbine Valve has to be be a mekanism Industrial Turbine Valve")
        end
    else
        print("Turbine Valve: not found")
        error("Turbine Valve is required")
    end
    if peripheral.isPresent(c.e_coolant_relay_id) then
        if peripheral.getType(c.e_coolant_relay_id) == "redstone_relay" then
            print("Emergency Cooling Relay: valid")
        else
            print("Emergency Cooling Relay: invalid")
            error("Emergency Cooling Relay has to be be a computercraft redstone relay")
        end
    else
        print("Emergency Cooling Relay: not found")
        error("Emergency Cooling Relay is required")
    end
    if peripheral.isPresent(c.resistive_heater_id) then
        if peripheral.getType(c.resistive_heater_id) == "resistiveHeater" then
            print("Dummy Load Heater: valid")
        else
            print("Dummy Load Heater: invalid")
            error("Dummy Load Heater has to be be a mekanism Resistive Heater")
        end
    else
        print("Dummy Load Heater: not found")
        error("Dummy Load Heater is required")
    end

    if c.enable_chat_box then
        if peripheral.isPresent(c.chatbox_id) then
            if peripheral.getType(c.chatbox_id) == "chatBox" then
                print("Chat Box: valid")
            else
                print("Chat Box: invalid")
                error("Chat Box has to be be an Advanced Peripherals ChatBox")
            end
        else
            print("Chat Box: not found")
            error("Chat Box is required (as per config)")
        end
    else
        print("Chat Box: disabled by config")
    end
end
