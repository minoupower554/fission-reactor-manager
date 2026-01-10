require('types')
local c = require('config')
local crash_protection = require('components.crash_handler')
local reactor_manager = require('components.reactor_manager')
local turbine_manager = require('components.turbine_manager')
local write_manager = require('components.write_manager')
local press_manager = require('components.press_manager')
local chat_command_manager = require('components.commands_manager')

local function main()
    if c.enable_chat_box and c.chat_box_commands then
        parallel.waitForAll(reactor_manager, turbine_manager, write_manager, press_manager, chat_command_manager)
    else
        parallel.waitForAll(reactor_manager, turbine_manager, write_manager, press_manager)
    end
end

xpcall(main, crash_protection)
