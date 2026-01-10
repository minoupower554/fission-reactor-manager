local c = require('config')
local s = {}

s.reactor = peripheral.wrap(c.reactor_logic_port_id) -- defining these outside the main function so the crash handler can use them
s.e_coolant_relay = peripheral.wrap(c.e_coolant_relay_id)
s.turbine = peripheral.wrap(c.turbine_valve_id)
s.load = peripheral.wrap(c.resistive_heater_id)
s.screen = peripheral.wrap(c.reactor_display)
s.chatbox = peripheral.wrap(c.chatbox_id)
s.trip_reset = false -- im sure using global state wont bite me later
s.reactor_state = false
s.trip = false
s.width, s.height = s.screen.getSize()

---@param level '"info"'|'"warn"'|'"error"'|string the log level to use, changes the colour of the field on the screen when applicable
---@param log_message string|'"none"' the message to log, use none for no message
---@param field '"reactor_temp"'|'"reactor_cool_level_percent"'|'"turbine_prod_rate"'|'"turbine_buffer_level"'|'"resistive_heater_load"'|'"trip_status"'|'"last_trip_type"'|'"roc_state"'|nil the field to edit, nil for no field edit
---@param value string|nil the value to set the field to, nil for no field edit
function s.queue_write(level, log_message, field, value)
    os.queueEvent("screen_write", level, log_message, field, value)
end

return s
