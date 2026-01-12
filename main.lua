sleep(1) -- avoid crashing on nil peripherals when rebooting after server restart
require('types') ---#remove
local round = require('components.round') ---#include
local lerp_clamp = require('components.lerp_clamp') ---#include
local trim = require('components.trim') ---#include
local c = require('config')
local s = require('components.state') ---#include
local crash_protection = require('modules.crash_handler') ---#include
local reactor_manager = require('modules.reactor_manager') ---#include
local turbine_manager = require('modules.turbine_manager') ---#include
local write_manager = require('modules.write_manager') ---#include
local press_manager = require('modules.press_manager') ---#include
local chat_command_manager = require('modules.commands_manager') ---#include

local function main()
    if c.enable_chat_box and c.chat_box_commands then
        parallel.waitForAll(reactor_manager, turbine_manager, write_manager, press_manager, chat_command_manager)
    else
        parallel.waitForAll(reactor_manager, turbine_manager, write_manager, press_manager)
    end
end

xpcall(main, crash_protection)
