local s = require('components.state')
local c = require('config')

return function()
    s.screen.setTextScale(1)
    s.screen.setTextColor(colors.white)
    s.screen.setBackgroundColor(colors.black)
    s.screen.setCursorBlink(false)
    if s.width ~= 29 or s.height ~= 12 then
        print("the screen has to be 3x2")
        error("invalid screen size")
    end
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
    local logging, err = fs.open(path, "w")
    if logging == nil then
        error("failed to open log file, error message: "..err)
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
        s.screen.setCursorPos(1, 1)
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
            logging.writeLine("["..level:upper().."]: "..log_message) ---@diagnostic disable-line -- this cannot be nil
            if c.enable_chat_box then
                if level == "info" then
                    if c.chat_box_log_level == "info" then
                        s.chatbox.sendMessageToPlayer(log_message, c.username, "reactor")
                    end
                elseif level == "warn" then
                    if c.chat_box_log_level == "warn" then
                        local serialized = textutils.serializeJSON({text=log_message, color="gold"})
                        s.chatbox.sendFormattedMessageToPlayer(serialized, c.username, "reactor")
                    end
                elseif level == "error" then
                    local serialized = textutils.serializeJSON({text=log_message, color="red"})
                    s.chatbox.sendFormattedMessageToPlayer(serialized, c.username, "reactor")
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
        s.screen.clear()
        for i, v in ipairs(fields) do
            for k, v in pairs(v) do
                if type(k) == "number" then -- for empty lines
                    goto continue
                end
                s.screen.setCursorPos(1, i)
                local str = v:sub(2)
                local print_string = pretty_print[k]..str
                local blit = v:sub(1, 1)
                if print_string:len() > s.width then
                    local split = {}
                    local total_length = 0
                    for part in print_string:gmatch("([^ ]+)") do
                        part = part.." "
                        total_length = total_length+part:len()
                        if total_length > s.width then
                            table.insert(split, "newline_abcd1234randomcharacterssotheresnochanceofitclashing")
                            total_length = 0
                        end
                        table.insert(split, part)
                    end
                    for _, v in ipairs(split) do
                        if v == "newline_abcd1234randomcharacterssotheresnochanceofitclashing" then
                            local _, y = s.screen.getCursorPos()
                            s.screen.setCursorPos(1, y+1)
                            goto continue_multiline_blit
                        end
                        s.screen.blit(v, blit:rep(v:len()), ("f"):rep(v:len()))
                        ::continue_multiline_blit::
                    end
                else
                    s.screen.blit(print_string, blit:rep(print_string:len()), ("f"):rep(print_string:len()))
                end
                ::continue::
            end
        end
        s.screen.setCursorPos(1, s.height)
        if s.trip then
            s.screen.setBackgroundColor(colors.green)
        else
            s.screen.setBackgroundColor(colors.red)
        end
        s.screen.write("TRIP RESET")
        if s.reactor_state then
            s.screen.setBackgroundColor(colors.red)
        else
            s.screen.setBackgroundColor(colors.green)
        end
        s.screen.setCursorPos(s.width-5, s.height)
        s.screen.write("TOGGLE")
        s.screen.setBackgroundColor(colors.black)
    end
end
