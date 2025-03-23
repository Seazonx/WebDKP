------------------------------------------------------------------------
-- WebDKP Standby Processing
-- Handles functions related to standby players
------------------------------------------------------------------------
-- Work in progres . . . Zevious
------------------------------------------------------------------------


-- ===========================================================================================
-- Toggle someone as standby
-- ===========================================================================================
function WebDKP_Standby_GUIToggle(state, playername, playerGuid)

    local tableid = WebDKP_GetTableid();

    -- If the playername was not passed then check the edit box
    if playername == nil or playername == "" then
        playername = WebDKP_Standby_FrameAddStandby:GetText();
    end
    -- If we still don't have a valid name check if someone is selected
    if playername == nil or playername == "" then
        playernametable = WebDKP_GetSelectedPlayers(1);
        if playernametable ~= nil then
            playername = playernametable[0]["name"];
        end
    end
    if playername == nil or playername == "" then
        WebDKP_Print(WebDKP.translations.Standby_Print);

        -- If the name is good then do this
    else
        if state == "add" then
            -- We want to flag this player as being in standby

            -- Check to see if this player is already in the table
            if WebDKP_DkpTable[playername] == nil or WebDKP_DkpTable[playername].class == nil then
                if (playerGuid ~= nil) then
                    local playerClass = select(1, GetPlayerInfoByGUID(playerGuid))
                    if WebDKP_DkpTable[playername] == nil then
                        WebDKP_DkpTable[playername] = {
                            ["dkp_" .. tableid] = 0,
                            ["class"] = playerClass,
                            ["standby"] = 1,
                            ["cantrim"] = false,
                        }
                    else
                        WebDKP_DkpTable[playername]["class"] = playerClass
                        WebDKP_DkpTable[playername]["standby"] = 1
                    end

                    WebDKP_SendWhisper(playername, WebDKP.translations.Standby_SendWhisper);
                    WebDKP_UpdateTableToShow();
                    WebDKP_UpdateTable();
                else
                    -- Add this player to the table
                    local frame = CreateFrame("frame")
                    frame:RegisterEvent("CHAT_MSG_SYSTEM");
                    frame:SetScript("OnEvent", function(self, event, text)
                        --WebDKP_Print(event .. ":" .. text)
                        if event == "CHAT_MSG_SYSTEM" then
                            if string.find(text, "[" .. playername .. "]") or string.find(text, "共计0个玩家") then
                                self:UnregisterEvent("CHAT_MSG_SYSTEM");
                                self = nil
                            else
                                return
                            end
                            local _, totalCount = C_FriendList.GetNumWhoResults();
                            local playerClass
                            for i = 1, totalCount do
                                local p = C_FriendList.GetWhoInfo(i)
                                if p.fullName == playername then
                                    playerClass = p.classStr
                                    break
                                end
                            end
                            if playerClass == nil then
                                WebDKP_Print("未找到名为:[" .. playername .. "]的在线玩家")
                                return
                            end

                            if WebDKP_DkpTable[playername] == nil then
                                WebDKP_DkpTable[playername] = {
                                    ["dkp_" .. tableid] = 0,
                                    ["class"] = playerClass,
                                    ["standby"] = 1,
                                    ["cantrim"] = false,
                                }
                            else
                                WebDKP_DkpTable[playername]["class"] = playerClass
                                WebDKP_DkpTable[playername]["standby"] = 1
                            end
                            WebDKP_SendWhisper(playername, WebDKP.translations.Standby_SendWhisper);
                            WebDKP_UpdateTableToShow();
                            WebDKP_UpdateTable();
                        end
                    end)
                    C_FriendList.SetWhoToUi(false)
                    C_FriendList.SendWho('n-\"' .. playername .. '\"')
                end
            else
                -- Change their standby state appropiately
                WebDKP_DkpTable[playername]["standby"] = 1;
                WebDKP_SendWhisper(playername, WebDKP.translations.Standby_SendWhisper);
            end


        end
        if state == "remove" then
            -- We want to remove this player from being listed as standby
            if WebDKP_DkpTable[playername] == nil then
                -- This person doesn't exist
                WebDKP_Print(WebDKP.translations.Standby_Print2);
            else
                -- Change their standby state appropiately
                WebDKP_DkpTable[playername]["standby"] = 0;
                WebDKP_SendWhisper(playername, WebDKP.translations.Standby_SendWhisper2);
            end

        end
        WebDKP_UpdateTableToShow();
        WebDKP_UpdateTable();
    end


end

-- ===========================================================================================
-- Set everyone's standby status to 0
-- ===========================================================================================
function WebDKP_Standby_Reset()

    for k, v in pairs(WebDKP_DkpTable) do
        if (type(v) == "table") then
            v["standby"] = 0;
        end

    end

    WebDKP_UpdateTableToShow();
    WebDKP_UpdateTable();

end