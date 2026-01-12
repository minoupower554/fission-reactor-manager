local s = require('components.state')
local c = require('config')
local round = require('components.round')
local lerp_clamp = require('components.lerp_clamp')

return function()
    s.load.setEnergyUsage(0)

    local max_energy = s.turbine.getMaxEnergy()
    if c.dummy_load_max == "auto" then
        c.dummy_load_max = s.turbine.getMaxProduction()/1e6
    end
    if s.turbine.getMaxProduction() > c.dummy_load_max*1e6 then
        print("Warning: the dummy load maximum is lower than the production capacity of the turbine")
    end
    local start_frac = c.dummy_load_start/100

    while true do
        local current_energy = s.turbine.getEnergy()
        s.queue_write("info", "none", "turbine_buffer_level", (round(current_energy/1e6, 0.1)).."MJ")
        local fill = current_energy/max_energy
        local usage = 0
        if fill > start_frac then
            local t = (fill-start_frac)/(1-start_frac)
            usage = lerp_clamp(0, c.dummy_load_max*1e6, t)
        end

        s.load.setEnergyUsage(usage)
        s.queue_write("info", "none", "resistive_heater_load", (round(usage/1e3, 0.1)).."kJ/t")
        local current_prod = s.turbine.getProductionRate()
        local prod_print = ""
        if current_prod > 1000*1e3 then
            prod_print = (round(current_prod/1e6, 0.1)).."MJ/t"
        else
            prod_print = (round(current_prod/1e3, 0.1)).."kJ/t"
        end
        s.queue_write("info", "none", "turbine_prod_rate", prod_print)
        os.sleep(0.05)
    end
end
