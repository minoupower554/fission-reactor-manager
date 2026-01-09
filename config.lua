local auto = "auto"
local side = {front="front",back="back",left="left",right="right",top="top",bottom="bottom"}
local config = {}

config.reactor_logic_port_id = "fissionReactorLogicAdapter_0" -- the reactor logic port id for reactor control
config.e_coolant_relay_id = "redstone_relay_3" -- the redstone relay id for the emergency cooling, make sure you have a torch to invert the signal as it activates the redstone signal when requesting emergency cooling.
config.e_coolant_relay_side = side.front -- the side to toggle the emergency cooling reservoir injection on the redstone relay. accepted values are the same as redstone_reactor_start_side. note that the side with the "face" is the front, not the side thats facing to you when placing
config.desired_burn_rate = 1 -- in millibuckets per tick
config.startup_timeout = 0.5 -- the timeframe in seconds between reactor startup and when rate of change protection activates, adjust this if your reactor takes longer to start
config.rate_of_change_margin = 2 -- how high the temperature difference has to be for rate of change protection to trigger, leave it at the default unless your reactor temperature varies a lot
config.e_coolant_disable = 450 -- the temperature at which emergency cooling gets disabled after it has been triggered
config.overheat_cutoff = 1200 -- leave this at the default unless you know what you're doing
config.minimum_required_coolant = 30 -- minimum required coolant in the tank in percent
config.turbine_valve_id = "turbineValve_1" -- the turbine valve id to use to interact with the turbine
config.resistive_heater_id = "resistiveHeater_2" -- the resistive heater id to use as the dummy load
config.dummy_load_start = 80 -- at what energy level in the buffer the program should start ramping up the dummy load in percent, interpolated from this value to buffer maximum
config.dummy_load_max = auto -- the maximum energy the load is allowed to take in MJ, this is the set load when the energy buffer is at 100%, set to auto for it to automatically use the turbine's maximum production rate
config.reactor_display = side.top -- the screen to put the gui on, can be either a side or a network ID. the screen has to be 3x2 and an advanced screen

return config
