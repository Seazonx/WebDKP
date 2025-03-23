------------------------------------------------------------------------
-- TimedAward	
------------------------------------------------------------------------
-- Contains methods related to timed awards and the timed awards gui frame. 
-- TimedAwards provide a method to automatically award dkp at certain timed
-- intervals. Players can either set an award to continouously be made or 
-- for a 1 time award to be done after so many minutes.
--
-- Note, values for this module are contained in the WebDKP_Options datastructure. 
-- Important ones: "TimedAwardInProgress" and "TimedAwardTimer"
------------------------------------------------------------------------


local WebDKP_Current_Encounter_Id
local WebDKP_Current_Encounter_Start_Time
local WebDKP_Current_Encounter_End_Time

function WebDKP_Award_Encounter_Start(encounterID)
    WebDKP_Current_Encounter_Id = encounterID
    WebDKP_Current_Encounter_Start_Time = time()
end

function WebDKP_Award_Encounter_End(encounterID)
    if encounterID == WebDKP_Current_Encounter_Id then
        WebDKP_Current_Encounter_End_Time = time()
    end
end

-- =====================================================================
-- Performs an automatted award by awarding everyone in the current group the 
-- amount of dkp specified in the timed Boss Award Dkp box
-- Added by Zevious (Bronzebeard)
-- =====================================================================
function WebDKP_BossAward_PerformAward(encounterID, encounterName)
    if (WebDKP_Options["AwardBossDKP"] == 1) then
        local instanceID = select(8, GetInstanceInfo())
        local bossMapDKPKey = WebDKP.translations.BOSS_MAP[instanceID]
        if bossMapDKPKey ~= nil then
            local bossName = string.gsub(encounterName, "%s+", "")
            if bossName == "" or bossName == nil then
                bossName = string.format("[%d]unknown name", encounterID)
            end
            if encounterID == WebDKP_Current_Encounter_Id
                    and WebDKP_Current_Encounter_Start_Time ~= nil
                    and WebDKP_Current_Encounter_End_Time ~= nil then
                bossName = bossName .. string.format("(%ds)", WebDKP_Current_Encounter_End_Time - WebDKP_Current_Encounter_Start_Time)
            end
            WebDKP_AwardDKP(bossMapDKPKey, bossName);
        end
    end
end

-- ================================
-- Awards DKP
-- input - Boss/fight name to show on dkp
-- ================================
function WebDKP_AwardDKP(bossMapDKPKey, BossName)
    local dkp = tonumber(WebDKP_Options[bossMapDKPKey])
    --WebDKP_Print(dkp);
    if (dkp == 0 and WebDKP_Options["AwardBossDKPIgnoreZero"] == 1) then
        WebDKP_Print(string.format(WebDKP.translations.AwardBossDKPIgnoreZero_Print, GetRealZoneText(), BossName))
        do
            return
        end
    end

    for _, v in pairs(WebDKP_WebOptions) do
        s = ((SG ~= nil and SG == v) or (next(WebDKP_Tables) == nil))
        if s then
            break
        end
    end
    if not s then
        return
    end

    -- 加分弹框确认
    WebDKP_ShowAwardFrame(
            WebDKP.translations.AddDKPReason_BOSS .. BossName,
            dkp,
            "",
            "",
            function(cost, player, link)
                WebDKP_UpdatePlayersInGroup();
                WebDKP_AddDKP(cost, WebDKP.translations.AddDKPReason_BOSS .. BossName, "false", WebDKP_PlayersInGroup);
                if WebDKP_Options["AwardBossDKP_Include_Standby"] == 1 then
                    local t = {  };
                    for name, v in pairs(WebDKP_DkpTable) do
                        if v.standby == 1 and WebDKP_PlayersInGroupStatus[name] == nil then
                            tinsert(t, { name = name, class = v.class, });
                        end
                    end
                    WebDKP_AddDKP(cost, WebDKP.translations.AddDKPReason_BOSS .. BossName, "false", t);
                end
                WebDKP_AnnounceBossAward(cost, BossName);
                WebDKP_Refresh()
            end
    )
end

-- ================================
-- Toggles displaying the timed award panel
-- ================================
function WebDKP_TimedAward_ToggleUI()
    if (WebDKP_TimedAwardFrame:IsShown()) then
        WebDKP_TimedAwardFrame:Hide();
    else
        WebDKP_TimedAwardFrame:Show();
        local time = WebDKP_TimedAwardFrameTime:GetText();
        if (time == nil or time == "") then
            WebDKP_TimedAwardFrameTime:SetText("5");
        end
        local dkp = WebDKP_TimedAwardFrameDkp:GetText();
        if (dkp == nil or dkp == "") then
            WebDKP_TimedAwardFrameDkp:SetText("0");
        end
    end
end


-- ================================
-- Toggles displaying mini timer
-- ================================
function WebDKP_TimedAward_ToggleMiniTimer()
    if (WebDKP_TimedAward_MiniFrame:IsShown()) then
        WebDKP_TimedAward_MiniFrame:Hide();
        WebDKP_Options["TimedAwardMiniTimer"] = 0;
    else
        WebDKP_TimedAward_MiniFrame:Show();
        WebDKP_Options["TimedAwardMiniTimer"] = 1;
    end
end

-- ================================
-- Shows the Bid UI
-- ================================
function WebDKP_TimedAward_ShowUI()
    WebDKP_TimedAwardFrame:Show();
    local time = WebDKP_TimedAwardFrameTime:GetText();
    if (time == nil or time == "") then
        WebDKP_TimedAwardFrameTime:SetText("0");
    end
    local dkp = WebDKP_TimedAwardFrameDkp:GetText();
    if (dkp == nil or dkp == "") then
        WebDKP_TimedAwardFrameTime:SetText("0");
    end
end

-- ================================
-- Hides the Bid UI
-- ================================
function WebDKP_TimedAward_HideUI()
    WebDKP_TimedAwardFrame:Hide();
end

-- ================================
-- Triggers The Timer to Start / Stop
-- ================================
function WebDKP_TimedAward_ToggleTimer()
    if (WebDKP_Options["TimedAwardInProgress"] == true) then
        --Stop the timer
        WebDKP_Options["TimedAwardInProgress"] = false;
        WebDKP_TimedAwardFrameStartStopButton:SetText(WebDKP.translations.StartStopButtonText);
        WebDKP_TimedAward_UpdateFrame:Hide();
        WebDKP_TimedAward_UpdateText();

    else
        WebDKP_Options["TimedAwardInProgress"] = true;            --Start the timer

        if (WebDKP_Options["TimedAwardTimer"] == 0) then
            local time = WebDKP_TimedAwardFrameTime:GetText();
            if (time == nil or time == "") then
                time = 5;
            end
            WebDKP_Options["TimedAwardTimer"] = time * 60;
        end

        WebDKP_TimedAwardFrameStartStopButton:SetText(WebDKP.translations.StartStopButtonText2);
        WebDKP_TimedAward_UpdateFrame:Show();
        WebDKP_TimedAward_UpdateText();
    end
end

-- ================================
-- Resets the timer to start counting from scartch again
-- ================================
function WebDKP_TimedAward_ResetTimer()
    local time = WebDKP_TimedAwardFrameTime:GetText();
    if (time == nil or time == "") then
        time = 5;
    end
    WebDKP_Options["TimedAwardTimer"] = time * 60;
    WebDKP_TimedAward_UpdateText();
end


-- ================================
-- Event handler for the bidding update frame. The update frame is visible (and calling this method)
-- when a timer value was specified. The addon countdowns until 0 - and when it reaches 0 it stops
-- the current bid
-- ================================
function WebDKP_TimedAward_OnUpdate(self, elapsed)
    local this = self;
    this.TimeSinceLastUpdate = this.TimeSinceLastUpdate + elapsed;

    if (this.TimeSinceLastUpdate > 1.0) then
        this.TimeSinceLastUpdate = 0;
        -- decrement the count down
        WebDKP_Options["TimedAwardTimer"] = WebDKP_Options["TimedAwardTimer"] - 1;

        WebDKP_TimedAward_UpdateText();

        --update the gui

        if (WebDKP_Options["TimedAwardTimer"] <= 0) then
            -- countdown reached 0
            WebDKP_TimedAward_PerformAward();

            -- if we are set to repeat the awards, go ahead and start the timer again
            if (WebDKP_Options["TimedAwardRepeat"] == 1) then

                WebDKP_TimedAward_ResetTimer();
            else
                -- it was a one time award, stop everything so we don't start going into negative numbers
                WebDKP_Options["TimedAwardInProgress"] = false;
                WebDKP_TimedAwardFrameStartStopButton:SetText(WebDKP.translations.StartStopButtonText);
                WebDKP_TimedAward_UpdateFrame:Hide();
            end
        end
    end
end

-- ================================
-- Updates the timer gui to show how many minutes / seconds are left
-- ================================
function WebDKP_TimedAward_UpdateText()

    local toDisplay = "";
    local minutes = floor(WebDKP_Options["TimedAwardTimer"] / 60);
    local seconds = WebDKP_Options["TimedAwardTimer"] % 60;

    if (minutes > 0) then
        toDisplay = toDisplay .. minutes .. ":";
    end
    if (seconds < 10) then
        seconds = "0" .. seconds;
    end
    toDisplay = toDisplay .. seconds;

    WebDKP_TimedAwardFrameTimeLeft:SetText(WebDKP.translations.TimeFlag .. toDisplay);
    WebDKP_TimedAward_MiniFrameTimeLeft:SetText(toDisplay);

end


-- ================================
-- Performs an automatted award by awarding everyone in the current group the
-- amount of dkp specified in the timed award gui box. Should be
-- called when the auto timer finishes
-- ================================
function WebDKP_TimedAward_PerformAward()
    WebDKP_UpdatePlayersInGroup();
    local allplayers = WebDKP_PlayersInGroup;
    local numPlayers = WebDKP_GetTableSize(WebDKP_PlayersInGroup);
    local dkp = WebDKP_TimedAwardFrameDkp:GetText();
    if (dkp == nil or dkp == "") then
        dkp = 0;
    end
    dkp = tonumber(dkp);

    -- Check to see if standby players should count and if any are in standby
    if WebDKP_Options["TimedStandby"] == 1 then
        for k, v in pairs(WebDKP_DkpTable) do
            if (type(v) == "table") then
                local playerName = k;
                local playerClass = v["class"];
                local playerStandby = v["standby"];
                if playerStandby ~= nil and playerStandby == 1 then
                    numPlayers = numPlayers + 1;
                    allplayers[numPlayers] = {
                        ["name"] = playerName,
                        ["class"] = playerClass,
                    };

                end

            end
        end
    end

    WebDKP_AddDKP(dkp, WebDKP.translations.ReasonTimedAward, "false", WebDKP_PlayersInGroup);
    WebDKP_UpdateTableToShow();
    WebDKP_UpdateTable();

    WebDKP_AnnounceTimedAward(WebDKP_TimedAwardFrameTime:GetText(), dkp);

    WebDKP_Refresh()

end