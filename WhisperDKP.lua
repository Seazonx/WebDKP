------------------------------------------------------------------------
-- WHISPER DKP
------------------------------------------------------------------------
-- This file contains methods related to WhisperDKP functionality. 
------------------------------------------------------------------------

-- ================================
-- Places a hook on incoming whispers to the chat message box. 
-- We can use this to disguise our whisper messages
-- ================================
function WebDKP_AddMessageEventFilters()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",
            function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13)
                -- if ( arg1 and arg2 ) then
                -- whisper too me
                if (WebDKP_IsWebDKPWhisper(arg2, arg1)) then
                    -- don't display whispercast whisper
                    return true
                end
            end
    )

    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM",
            function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13)
                -- whisper I am sending
                if (string.find(arg1, "^WebDKP: ")
                        or string.find(arg1, "!Sending")
                        or string.find(arg1, "!SendingAuto")
                ) then
                    -- hide whispers that I am sending
                    return true
                end
            end
    )
end


-- ================================
-- Event handler for regular chat whisper messages
-- Responds to the players whisper with a whisper telling
-- them their current dkp. 
-- ================================
function WebDKP_WhisperDKP_Event(arg1, arg2, playerGuid)
    local tableid = WebDKP_GetTableid();
    local name = arg2;
    local trigger = arg1;
    --    WebDKP_Print(string.format("WebDKP_WhisperDKP_Event %s %s",arg1,arg2))
    if (WebDKP_IsWebDKPWhisper(name, trigger)) then
        -- its a valid whisper for us. Now to determine what type of whisper
        if (string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP) == 1) then
            -- THEY WANT THEIR DKP
            -- look up this player in our dkp table and see if we can find their information
            local main = WebDKP_GetMain(name, true);
            if (WebDKP_DkpTable[main] == nil) then
                -- not in our system, send them message
                WebDKP_SendWhisper(name, WebDKP.translations.WhisperDKP1);
                WebDKP_SendWhisper(name, WebDKP.translations.WhisperDKP2);
            else
                -- they are in the table, get them their dkp
                local dkp = WebDKP_GetDKP(main, tableid);
                local tier = floor((dkp - 1) / WebDKP_TierInterval);
                if (dkp == 0) then
                    tier = 0;
                end
                WebDKP_SendWhisper(name, WebDKP.translations.WhisperDKP3 .. dkp);
                WebDKP_SendWhisper(name, WebDKP.translations.WhisperDKP2);
            end
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP1) == 1) then
            -- THEY WANT THE DKP OF PEOPLE IN THE CURRENT GROUP
            local filter = WebDKP_GetWhisperFiltersFromMessage(trigger);
            --WebDKP_SendWhisper(name, "DKP List");
            --WebDKP_SendWhisper(name, "DKP : Tier Name(Class) ");
            --WebDKP_SendWhisper(name, "==============================");
            WebDKP_WhisperSortedList(name, true, filter);
            --elseif (trigger == "!help") then
            -- THEY WANT HELP / LIST OF COMMANDS
            --WebDKP_SendWhisper(name, "可用命令:");
            --WebDKP_SendWhisper(name, "mydkp - 获取你的当前dkp");
            --WebDKP_SendWhisper(name, "查询 - 组中的dkp列表");
            --DLL Removed WebDKP_SendWhisper(name,"!listall - List dkp of guild (BIG)");
            --WebDKP_SendWhisper(name, "!help - This menu");
            --WebDKP_SendWhisper(name, "通过在‘查询’后面附加职业名来限制列表");
            --WebDKP_SendWhisper(name, "如: '查询 LR' 只列出猎人的DKP");
            --WebDKP_SendWhisper(name, "如: '查询 LR QS' 只列出LR和QS的DKP");
        elseif (trigger == WebDKP.translations.triggerWhisperDKP2) then
            -- They want to be added as standby
            WebDKP_Standby_GUIToggle("add", name, playerGuid)
        elseif (trigger == WebDKP.translations.triggerWhisperDKP3) then
            -- THEY WANT HELP / LIST OF COMMANDS
            WebDKP_Standby_GUIToggle("remove", name)
        elseif (trigger == WebDKP.translations.triggerWhisperDKP4) then
            -- They want their attendance info
            if WebDKP_CharRaidInfo[name] ~= nil then
                local total_raids = WebDKP_CharRaidInfo[name]["total_raids"];
                local attended_raids = WebDKP_CharRaidInfo[name]["raids_attended"];
                local percent = WebDKP_CharRaidInfo[name]["percent"];
                WebDKP_SendWhisper(name, WebDKP.translations.WhisperDKP4 .. attended_raids .. WebDKP.translations.WhisperDKP5 .. total_raids .. WebDKP.translations.WhisperDKP6 .. percent .. " %");
            else
                WebDKP_SendWhisper(name, WebDKP.translations.WhisperDKP7);
            end

        end
    end
end

-- ================================
-- Returns true if the passed whisper is a whisper directed
-- towards web dkp
-- ================================
function WebDKP_IsWebDKPWhisper(name, trigger)
    -- if it has webdkp in it, its an outgoing message. ignore it

    if (string.find(string.lower(trigger), "WebDKP:")) then
        return false;
    end
    if (string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP4) == 1 or
            --string.find(string.lower(trigger), "!help") == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP1) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP2) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerWhisperDKP3) == 1 or
            string.find(trigger, "!Sending") == 1 or
            string.find(trigger, "!SendingAuto") == 1
    ) then
        return true
    end

    return false
end


-- ================================
-- Helper method for the whisper features. 
-- Sends the player a list of dkp for people either in the current
-- group or in the guild
-- ================================
function WebDKP_WhisperSortedList(toPlayer, limitToGroup, classFilter)
    local tableid = WebDKP_GetTableid();
    if (classFilter == nil) then
        classFilter = {};
    end
    -- increment through the dkp table and move data over
    local tableToWhisper = {};
    for k, v in pairs(WebDKP_DkpTable) do
        if (type(v) == "table") then
            local playerName = k;
            local playerClass = v["class"];
            local playerDkp = WebDKP_GetDKP(playerName, tableid);
            if (playerDkp ~= nil) then
                local playerTier = floor((playerDkp - 1) / WebDKP_TierInterval);
                if (playerDkp == 0) then
                    playerTier = 0;
                end
                -- if it should be displayed (passes filter) add it to the table
                if (WebDKP_PassesWhisperFilter(playerName, playerClass, playerDkp, playerTier, limitToGroup, classFilter)) then
                    tinsert(tableToWhisper, { playerName = playerName, playerClass = playerClass, playerDkp = playerDkp, playerTier = playerTier });
                end
            end
        end
    end
    -- we now have our table to whisper
    -- sort it
    table.sort(
            tableToWhisper,
            function(a1, a2)
                if (a1 and a2) then
                    if (a1.playerDkp == a2.playerDkp) then
                        return a1.playerName >= a2.playerName;
                    else
                        return a1.playerDkp <= a2.playerDkp;
                    end
                end
            end
    );

    -- display it
    for k, v in pairs(tableToWhisper) do
        if (v.playerName ~= nil and v.playerClass ~= nil and v.playerDkp ~= nil) then
            WebDKP_SendWhisper(toPlayer, v.playerDkp .. " : " .. v.playerName .. " ( " .. v.playerClass .. " ) ");
        end
    end
end

-- ================================
-- Checks to see if a given entry passes a set of whisper filters
-- ================================
function WebDKP_PassesWhisperFilter(name, class, dkp, tier, limitToGroup, filter)
    class = WebDKP.translations.CLASS_LOCALIZED_TO_ENG_MAP[class]
    -- check the limit to group
    if (limitToGroup) then
        if (not WebDKP_PlayerInGroup(name)) then
            return false;
        end
    end
    -- now check the filters
    if (filter["showall"]) then
        return true;
    else
        -- return true if the class entry is not equal to nil, meaning it should be displayed
        if (class == nil) then
            return false;
        end
        return (not (filter[string.lower(class)] == nil));
    end


end

-- ================================
-- Scans a whisper message to determine what filters are being used. 
-- Returns a filter object that can be passed to WebDKP_WhisperSortedList
-- ================================
function WebDKP_GetWhisperFiltersFromMessage(message)
    local filter = {};
    filter["druid"] = string.find(string.lower(message), "druid");
    filter["hunter"] = string.find(string.lower(message), "hunter");
    filter["mage"] = string.find(string.lower(message), "mage");
    filter["rogue"] = string.find(string.lower(message), "rogue");
    filter["shaman"] = string.find(string.lower(message), "shaman");
    filter["paladin"] = string.find(string.lower(message), "paladin");
    filter["priest"] = string.find(string.lower(message), "priest");
    filter["warrior"] = string.find(string.lower(message), "warrior");
    filter["warlock"] = string.find(string.lower(message), "warlock");

    --localized alias check
    if WebDKP_GetTableSize(filter) == 0 then
        local findAliasKeyWord
        for k, v in pairs(WebDKP.translations.CLASS_ALIAS_TO_ENG_MAP) do
            findAliasKeyWord = string.find(string.upper(message), " " .. k)
            if findAliasKeyWord ~= nil then
                filter[v] = findAliasKeyWord
            end
        end
    end

    --localized name check
    if WebDKP_GetTableSize(filter) == 0 then
        local findLocalizedWord
        for k, v in pairs(WebDKP.translations.CLASS_LOCALIZED_TO_ENG_MAP) do
            findLocalizedWord = string.find(string.upper(message), " " .. k)
            if findLocalizedWord ~= nil then
                filter[string.lower(v)] = findLocalizedWord
            end
        end
    end


    --    for k, v in pairs(filter) do
    --        WebDKP_Print(string.format("filter %s %d",k,v))
    --    end


    -- If no filters were passed, everything should be nill. In that case
    -- just display everyone
    if (filter["druid"] == nil and filter["hunter"] == nil and filter["mage"] == nil and
            filter["rogue"] == nil and filter["shaman"] == nil and filter["paladin"] == nil and
            filter["priest"] == nil and filter["warrior"] == nil and filter["warlock"] == nil) then
        filter["showall"] = true;
    else
        filter["showall"] = false;
    end
    return filter;
end