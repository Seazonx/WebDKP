------------------------------------------------------------------------
-- GROUP FUNCTIONS
------------------------------------------------------------------------
-- This file contains methods related to working with the dkp table
-- and the current group. 
-- Contained in here are methods to:
-- *	Scan your group to find out what players are currently in it
-- *	Update the 'table to show' which determines the dkp table to show based on members
-- of your group, the current dkp table, and any filters that are selected
-- *	Update the gui with the table to show
------------------------------------------------------------------------

-- ================================
-- Rerenders the table to the screen. This is called 
-- on a few instances - when the scroll frame throws an 
-- event or when filters are applied or when group
-- memebers change. 
-- General structure:
-- First runs through the table to display and puts the data
-- into a temp array to work with
-- Then uses sorting options to sort the temp array
-- Calculates the offset of the table to determine
-- what information needs to be displayed and in what lines 
-- of the table it should be displayed
-- ================================
function WebDKP_UpdateTable()
    table.sort(WebDKP_DkpTableToShow, function(a1, a2)
        if a1 == nil or a2 == nil then
            return true
        end

        local result = true
        if (WebDKP_LogSort["curr"] == "name") then
            result = a1.playerName > a2.playerName
        elseif (WebDKP_LogSort["curr"] == "class") then
            if (tostring(a1.playerClass) ~= tostring(a2.playerClass)) then
                result = tostring(a1.playerClass) > tostring(a2.playerClass)
            else
                result = a1.playerName > a2.playerName
            end
        elseif (WebDKP_LogSort["curr"] == "dkp") then
            if (tonumber(a1.playerDkp) ~= tonumber(a2.playerDkp)) then
                result = tonumber(a1.playerDkp) > tonumber(a2.playerDkp)
            else
                result = a1.playerName > a2.playerName
            end
        elseif (WebDKP_LogSort["curr"] == "zone") then
            local a1Zone, a2Zone
            if (WebDKP_PlayersInGroupStatus[a1.playerName] ~= nil) then
                a1Zone = WebDKP_PlayersInGroupStatus[a1.playerName]["zone"]
            end
            if (WebDKP_PlayersInGroupStatus[a2.playerName] ~= nil) then
                a2Zone = WebDKP_PlayersInGroupStatus[a2.playerName]["zone"]
            end
            if (tostring(a1Zone) ~= tostring(a2Zone)) then
                result = tostring(a1Zone) > tostring(a2Zone)
            else
                result = a1.playerName > a2.playerName
            end
        end

        if (WebDKP_LogSort["way"] == 0) then
            return result
        else
            return not result
        end
    end);

    local numEntries = getn(WebDKP_DkpTableToShow);
    --WebDKP_Print("Before Update");
    FauxScrollFrame_Update(WebDKP_FrameScrollFrame, numEntries, 22, 20);
    --WebDKP_Print("After Update");
    -- Run through the table lines and put the appropriate information into each line
    for i = 1, 22, 1 do
        local line = getglobal("WebDKP_FrameLine" .. i);
        local nameText = getglobal("WebDKP_FrameLine" .. i .. "Name");
        local classText = getglobal("WebDKP_FrameLine" .. i .. "Class");
        local dkpText = getglobal("WebDKP_FrameLine" .. i .. "DKP");
        local zoneText = getglobal("WebDKP_FrameLine" .. i .. "Zone");
        local rankText = getglobal("WebDKP_FrameLine" .. i .. "Rank");
        local index = i + FauxScrollFrame_GetOffset(WebDKP_FrameScrollFrame);

        if (index <= numEntries) then
            local playerName = WebDKP_DkpTableToShow[index].playerName;
            local classname = WebDKP_DkpTableToShow[index].playerClass;
            line:Show()

            nameText:SetText(WebDKP_DkpTableToShow[index].playerName);
            classText:SetText(classname);

            -- If the class name matches up set the color otherwise leave it as the default color
            local englishClass = WebDKP.translations.CLASS_LOCALIZED_TO_ENG_MAP[classname]
            if englishClass ~= nil then
                local rPerc, gPerc, bPerc, argbHex = GetClassColor(string.upper(englishClass))
                classText:SetTextColor(rPerc, gPerc, bPerc);
                nameText:SetTextColor(rPerc, gPerc, bPerc);
            end

            dkpText:SetText(WebDKP_DkpTableToShow[index].playerDkp);
            -- TODO 会里面级别直接不要了,换成替补标志吧
            local message = ""
            if (WebDKP_PlayersInGroupStatus[playerName] ~= nil) then
                zoneText:SetText(WebDKP_PlayersInGroupStatus[playerName]["zone"])
                -- WebDKP_PlayersInGroupStatus[playerName]["zone"]
                if (WebDKP_PlayersInGroupStatus[playerName]["isDead"]) then
                    message = message .. "(|cffFF0000死亡|r)"
                end
                if (not WebDKP_PlayersInGroupStatus[playerName]["online"]) then
                    message = message .. "(|cffB5B5B5离线|r)"
                end
            else
                zoneText:SetText("")
            end
            if (WebDKP_DkpTable[playerName]["standby"] == 1) then
                message = message .. "(|cff00FE00替补|r)"
            end
            rankText:SetText(message);
            -- kill the background of this line if it is not selected
            if (not WebDKP_DkpTable[playerName]["Selected"]) then
                getglobal("WebDKP_FrameLine" .. i .. "Background"):SetVertexColor(0, 0, 0, 0);
            else
                getglobal("WebDKP_FrameLine" .. i .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
            end
        else
            -- if the line isn't in use, hide it so we dont' have mouse overs
            line:Hide();
        end
    end
end


-- ================================
-- Helper method that determines the table that should be shown. 
-- This runs through the dkp list and checks filters against each entry
-- If an entry passes it is moved to the table to show. If it doesn't pass
-- the test it is ignored. 
-- ================================
function WebDKP_UpdateTableToShow()
    -- first, cleanup anyone who does not belong in the table
    WebDKP_CleanupTable();
    tableid = WebDKP_GetTableid();
    local tableid = WebDKP_GetTableid();
    local slashposition = 0;
    -- clear the old table
    WebDKP_DkpTableToShow = {};
    -- increment through the dkp table and move data over
    for k, v in pairs(WebDKP_DkpTable) do
        if (type(v) == "table") then
            local playerName = k;
            local playerClass = v["class"];
            local playerDkp, lifeTime = WebDKP_GetDKP(playerName, tableid);
            local playerTier = floor((playerDkp - 1) / WebDKP_TierInterval);
            local playerStandby = v["standby"];
            if (playerDkp == 0) then
                playerTier = 0;
            end

            -- if it should be displayed (passes filter) add it to the table
            if (WebDKP_ShouldDisplay(playerName, playerClass, playerDkp, playerTier, playerStandby, lifeTime)) then
                tinsert(WebDKP_DkpTableToShow, {
                    playerName = playerName,
                    playerClass = playerClass,
                    playerDkp = playerDkp,
                    playerTier = playerTier,
                });
            else
                -- if it is not displayed, deselect it automatically for us
                WebDKP_DkpTable[playerName]["Selected"] = false;
            end
        end
    end
    -- now need to run through anyone else who is in our current raid / party
    -- They may not have dkp yet and may not be in our dkp table. Use this oppurtunity
    -- to add them to the table with 0 points and add them to the to display table if appropriate
    -- table to be displayed

    for key, entry in pairs(WebDKP_PlayersInGroup) do
        if (type(entry) == "table") then
            local playerName = entry["name"];
            -- Fixes some sort of weird glitch where the playerName is nil
            if playerName ~= nil then
                -- is this a new person we haven't seen before?
                if (WebDKP_DkpTable[playerName] == nil) then
                    -- new person, they need to be added
                    local playerClass = entry["class"];
                    local playerDkp = 0;
                    local playerTier = 0;
                    WebDKP_MakeSureInTable(playerName, tableid, playerClass, playerDkp)
                    -- do a final check to see if we should display (pass all filters, etc.)
                    if (WebDKP_ShouldDisplay(playerName, playerClass, playerDkp, playerTier)) then
                        tinsert(WebDKP_DkpTableToShow, {
                            playerName = playerName,
                            playerClass = playerClass,
                            playerDkp = playerDkp,
                            playerTier = playerTier,
                        });
                    else
                        WebDKP_DkpTable[playerName]["Selected"] = false;
                    end
                end
            end
        end
    end
end


-- ================================
-- Updates the list of players in our current group.
-- First attempts to get raid data. If user isn't in a raid
-- it checks party data. If user is not in a party there 
-- is no information to get
-- ================================
function WebDKP_UpdatePlayersInGroup()
    -- Updates the list of players currently in the group
    -- First attempts to get this data via a query to the raid.
    -- If that failes it resorts to querying for party data
    local numberInRaid = GetNumGroupMembers();
    local inBattleground = WebDKP_InBattleground();

    WebDKP_PlayersInGroup = {};
    WebDKP_PlayersInGroupStatus = {};
    -- Is a raid going?
    if (numberInRaid > 0 and inBattleground == false) then
        -- Yes! Load raid data...
        for i = 1, numberInRaid do
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
            WebDKP_PlayersInGroup[i] = {
                ["name"] = name,
                ["class"] = class,
            };
            if name ~= nil then
                WebDKP_PlayersInGroupStatus[name] = {
                    ["online"] = online,
                    ["zone"] = zone,
                    ["isDead"] = isDead,
                }
            end
        end
        -- Is a party going?
    else
        -- not in party or raid... go ahead and load yourself
        WebDKP_PlayersInGroup[0] = {
            ["name"] = UnitName("player"),
            ["class"] = UnitClass("player"),
        };
        WebDKP_PlayersInGroupStatus[UnitName("player")] = {
            ["online"] = true,
            ["zone"] = GetRealZoneText(),
            ["isDead"] = false,
        }
    end
end

-- ================================
-- Returns true if the player is currently inside a battle ground
-- instance. 
-- ================================
function WebDKP_InBattleground()

    -- temp vars
    local status, mapName, instanceID, minlevel, maxlevel;

    -- iterate through all of our battle ground queues
    for i = 1, 10 do

        -- return true if anyone of them is active
        status, mapName, instanceID, minlevel, maxlevel, teamSize = GetBattlefieldStatus(i);
        if (status == "active") then
            return true;
        end
    end

    return false;
end

-- ================================
-- Returns true if everyone in the current group is selected. 
-- This is a helper method when displaying messages to chat. 
-- If everyone is selected you can just say "awarded points to everyone"
-- versus listing out everyone who was selected invidiually
-- ================================
function WebDKP_AllGroupSelected()
    -- First try running through the raid and see if they are all selected
    local name, class;
    local numberInRaid = GetNumGroupMembers();
    local numberInParty = GetNumSubgroupMembers();
    if (numberInRaid > 0) then
        for i = 1, numberInRaid do
            name, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i);
            if (not WebDKP_DkpTable[name]["Selected"]) then
                return false;
            end
        end
        return true;
    elseif (numberInParty > 0) then
        for i = 1, numberInParty do
            playerHandle = "party" .. i;
            name = UnitName(playerHandle);
            if (not WebDKP_DkpTable[name]["Selected"]) then
                return false;
            end
        end
        --before we return true we also need to check the current player...
        if (not WebDKP_DkpTable[UnitName("player")]["Selected"]) then
            return false;
        end
        return true;
    end
    -- entire group isn't selected, do things manually
    return false;
end



-- ================================
-- Removes anyone from the table who has 0 DKP. This cleans up anyone who was
-- auto added when they were detected in the group, but didn't actually get anything.
-- ================================
function WebDKP_CleanupTable()

    -- iterate through all players in our table
    for k, v in pairs(WebDKP_DkpTable) do
        if (type(v) == "table") then

            -- if we see a player can be trimmed, and is no longer
            -- in our party, go ahead and trim them. The trim flag would
            -- have been set to false if they were given any points.
            local playerName = k;
            local cantrim = v["cantrim"];
            local inGroup = WebDKP_PlayerInGroup(playerName);

            -- if can trim is not set, assume false ( this would be the
            -- case of a player being added manually on the site then synced)
            if (cantrim == nil) then
                cantrim = false;
            end

            -- if the can trim flag is false, do a second check. Here
            -- we'll see if the player has dkp in any of the tables. If they
            -- don't have dkp anywhere, we can remove them as well
            if (cantrim == false and v["standby"] == 0) then
                local hasDkp = WebDKP_PlayerHasDKP(playerName);
                if (hasDkp == false) then
                    cantrim = true;
                end
            end

            -- 线上拉下来的,替补的  不清除
            if (v["online"] == true)
                    or (v["standby"] == 1) then
                cantrim = false
            end

            -- only remove if they are elegible to be trimmed, and
            -- no longer in the active group
            if (cantrim == true and inGroup == false) then
                WebDKP_DkpTable[playerName] = nil;
            end
        end
    end
end

-- ================================
-- Helper method. Returns true if the current player should be displayed
-- on the table by checking it against current filters
-- ================================
function WebDKP_ShouldDisplay(name, class, dkp, tier, standby, lifeTime)
    --    WebDKP_Print(string.format("name:%s, class:%s, dkp:%s, tier:%s, standby:%s", name, class, tostring(dkp), tostring(tier), tostring(standby)))
    class = WebDKP.translations.CLASS_LOCALIZED_TO_ENG_MAP[class]

    if (name == "Unknown") then
        return false;
    end

    if (WebDKP_Filters[class] == 0) then
        return false;
    end

    if (WebDKP_PlayersInGroupStatus[name] ~= nil) then
        return WebDKP_Filters["Group"] == 1
    end

    if (WebDKP_DkpTable[name] ~= nil and WebDKP_DkpTable[name]["standby"] == 1) then
        return WebDKP_Filters["Standby1"] == 1
    end

    if lifeTime == 0 then
        return false
    end

    return WebDKP_Filters["Others"] == 1
end

-- ==================================================================================
-- Function to determine guild rank if the person is in the users guild
-- ==================================================================================
function WebDKP_GetGuildRank(playerName)

    local playerRank = "PUG";
    local playerIndex = 50;
    for ci = 1, GetNumGuildMembers(true) do
        local guildname, guildrank = GetGuildRosterInfo(ci);
        if guildname == playerName or string.find(guildname, playerName .. "-" .. "(.+)") then
            playerRank = guildrank;
            return playerRank;
            --ci = GetNumGuildMembers(true) + 10;
        end
    end
    return playerRank;
end