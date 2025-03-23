------------------------------------------------------------------------
-- BIDDING	
------------------------------------------------------------------------
-- Contains methods related to bidding and the bidding gui.
------------------------------------------------------------------------


local WebDKP_BidList = {    };            -- Will hold the bids placed during run time
local WebDKP_bidInProgress = false;            -- Bid in progress?.
local WebDKP_RollInProgress = false;            -- Roll in progress?
WebDKP_bidItem = "";                    -- Item name being bid on
WebDKP_bidItemLink = "";                            -- This is the item link for the chat window.
local WebDKP_bidCountdown = 0;                -- How many seconds until bid ends on its own
local WebDKP_startingBid = 0;                -- the default starting bid if something cannot be found in the loot table (NOT the current starting bid which is read from the gui)
WebDKP_lastBidItem = "";                -- The last item that was bidded on and actually awarded. Flagged so that auto fill will not to show a popup when it is given out
WebDKP_Rolls = {};                    -- Store the rolls
WebDKP_Roll_Total = 1;
defaultBIPmsg = WebDKP.translations.defaultBIPmsg
defaultSBIPmsg = WebDKP.translations.defaultSBIPmsg
defaultRIPmsg = WebDKP.translations.defaultRIPmsg


-- Data structure for sorting the table 
WebDKP_BidSort = {
    ["curr"] = 2, -- the column to sort
    ["way"] = 1                    -- Desc
};

do
    local loot_buttons = {  };
    local loot_button_call = {  };
    for i = 1, 4 do
        loot_buttons[i] = _G["LootButton" .. i];

        loot_button_call[i] = CreateFrame("Button", nil, loot_buttons[i],"BackdropTemplate");
        loot_button_call[i]:SetSize(32, 32);
        loot_button_call[i]:EnableMouse(true);
        loot_button_call[i]:RegisterForClicks("AnyUp");
        loot_button_call[i].backdropInfo = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 2,
            edgeSize = 2,
            insets = { left = 1, right = 1, top = 1, bottom = 1, }
        };
        loot_button_call[i]:ApplyBackdrop()
        loot_button_call[i]:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
        loot_button_call[i]:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0);
        loot_button_call[i]:SetPoint("RIGHT", loot_buttons[i], "LEFT", -10, 0);
        loot_button_call[i]:SetScript("OnClick", function(self)
            local slot = self:GetParent().slot;
            local slot_type = GetLootSlotType(slot);
            --[[
                0: LOOT_SLOT_NONE
                1: LOOT_SLOT_ITEM
                2: LOOT_SLOT_MONEY
                3: LOOT_SLOT_CURRENCY
            ]]
            if slot_type == 1 then
                local link = GetLootSlotLink(slot);
                local _, _, id = strfind(link, "item:(%d+)");
                id = tonumber(id);
                local icon, name, quanty, _, quality = GetLootSlotInfo(slot);
                WebDKP_Bid_ToggleUI();
                WebDKP_BidFrameItem:SetText(link)
                --print(link, icon, name, quanty, _, quality)
            end
        end);

        local text = loot_button_call[i]:CreateFontString(nil, "OVERLAY");
        text:SetFont(GameFontNormal:GetFont(), 12, "OUTLINE");
        text:SetPoint("CENTER");
        text:SetText("[拍]");
    end
end

-- ================================
-- Toggles displaying the bidding panel
-- ================================
function WebDKP_Bid_ToggleUI()
    if (WebDKP_BidFrame:IsShown()) then
        WebDKP_BidFrame:Hide();
    else
        WebDKP_BidFrame:Show();

        WebDKP_BidFrameBid:Show();
        WebDKP_BidFrameDKP:Show();
        WebDKP_BidFramePost:Show();
        WebDKP_BidFrameStartingBid:Show();
        WebDKP_BidFrameTop3Button:Show();
        WebDKP_BidFrameTitle:Show();
        WebDKP_BidFrameScrollFrame:Show();

        local time = WebDKP_BidFrameTime:GetText();
        if (time == nil or time == "") then
            WebDKP_BidFrameTime:SetText("0");
        end

    end
end

-- ================================
-- Shows the Bid UI
-- ================================
function WebDKP_Bid_ShowUI()
    WebDKP_BidFrame:Show();
    local time = WebDKP_BidFrameTime:GetText();
    if (time == nil or time == "") then
        WebDKP_BidFrameTime:SetText("0");
    end

end

-- ================================
-- Hides the Bid UI
-- ================================
function WebDKP_Bid_HideUI()
    WebDKP_BidFrame:Hide();
end

-- ================================
-- Called when mouse goes over a dkp line entry. 
-- If that player is not selected causes that row
-- to become 'highlighted'
-- ================================
function WebDKP_Bid_HandleMouseOver(self)
    local this = self;
    local playerBid = 0;
    local playerName = getglobal(this:GetName() .. "Name"):GetText();

    playerBid = getglobal(this:GetName() .. "Bid"):GetText() + 0;
    if playerBid == nil then
        playerBid = 0;
    end
    local selected = WebDKP_Bid_IsSelected(playerName, playerBid);

    if (not selected) then
        getglobal(this:GetName() .. "Background"):SetVertexColor(0.2, 0.2, 0.7, 0.5);
    end
end

-- ================================
-- Called when a mouse leaves a dkp line entry. 
-- If that player is not selected, causes that row
-- to return to normal (none highlighted)
-- ================================
function WebDKP_Bid_HandleMouseLeave(self)
    local this = self;
    local playerBid = 0;
    local playerName = getglobal(this:GetName() .. "Name"):GetText();
    playerBid = getglobal(this:GetName() .. "Bid"):GetText() + 0;
    if playerBid == nil then
        playerBid = 0;
    end
    local selected = WebDKP_Bid_IsSelected(playerName, playerBid);
    if (not selected) then
        getglobal(this:GetName() .. "Background"):SetVertexColor(0, 0, 0, 0);
    end
end

-- ================================
-- Called when the user clicks on a player entry. Causes 
-- that entry to either become selected or normal
-- and updates the dkp table with the change
-- ================================
function WebDKP_Bid_SelectPlayerToggle(self)
    local this = self;

    local playerName = getglobal(this:GetName() .. "Name"):GetText();

    local playerBid2 = 0;

    playerBid2 = getglobal(this:GetName() .. "Bid"):GetText() + 0;
    if playerBid2 == nil then
        playerBid2 = 0;
    end

    -- we need to search through the table and figure out which one was selected
    -- an entry is considered a unique name / bid pair
    -- once we find an entry we can toggle its selection state
    for key, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Name"] ~= nil and v["Bid"] ~= nil) then
                if (v["Name"] == playerName and WebDKP_ROUND(v["Bid"], 2) == playerBid2) then
                    if (v["Selected"] == true) then
                        v["Selected"] = false;
                        getglobal(this:GetName() .. "Background"):SetVertexColor(0.2, 0.2, 0.7, 0.5);
                    else
                        -- deselect all the others on the table
                        WebDKP_Bid_DeselectAll();

                        v["Selected"] = true;
                        getglobal(this:GetName() .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
                    end
                end
            end
        end
    end

    WebDKP_Bid_UpdateTable();

end

-- ================================
-- Returns true if the given player name / bid value is selected
-- in the bid list table. false otherwise. 
-- ================================
function WebDKP_Bid_IsSelected(playerName, playerBid)
    playerBid = playerBid + 0;
    playerbidcompare = 0;
    for key, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Name"] ~= nil and v["Bid"] ~= nil) then
                playerbidcompare = v["Bid"];
                playerbidcompare = tonumber(playerbidcompare);
                playerbidcompare = WebDKP_ROUND(playerbidcompare, 2);
                if (v["Name"] == playerName and playerbidcompare == playerBid) then
                    return v["Selected"];
                end
            end
        end
    end
    return false;
end

-- ================================
-- Deselects all entries in the table
-- ================================
function WebDKP_Bid_DeselectAll()

    for key, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Name"] ~= nil and v["Bid"] ~= nil) then
                v["Selected"] = false;
            end
        end
    end
end

-- ================================
-- Called when a player clicks on a column header on the table
-- Changes the sorting options / asc&desc. 
-- Causes the table display to be refreshed afterwards
-- to player instantly sees changes
-- ================================
function WebDKP_Bid_SortBy(id)
    if (WebDKP_BidSort["curr"] == id) then
        WebDKP_BidSort["way"] = abs(WebDKP_BidSort["way"] - 1);
    else
        WebDKP_BidSort["curr"] = id;
        if (id == 1) then
            WebDKP_BidSort["way"] = 0;
        elseif (id == 2) then
            WebDKP_BidSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
        elseif (id == 3) then
            WebDKP_BidSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
        else
            WebDKP_BidSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
        end

    end
    -- update table so we can see sorting changes
    WebDKP_Bid_UpdateTable();
end



-- ================================
-- Rerenders the sorted table to the screen. This is called 
-- on a few instances - when the scroll frame throws an 
-- event or when bids are placed or when a bid ends. 
-- General structure:
-- First runs through the table to display and puts the data
-- into a temp array to work with
-- Then uses sorting options to sort the temp array
-- Calculates the offset of the table to determine
-- what information needs to be displayed and in what lines 
-- of the table it should be displayed
-- ================================
function WebDKP_Bid_UpdateTable()
    -- Copy data to the temporary array
    local entries = { };
    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Name"] ~= nil and v["Bid"] ~= nil and v["DKP"] ~= nil and v["Post"] ~= nil) then

                tinsert(entries, { v["Name"], v["Bid"], v["DKP"], v["Post"], v["Date"], v["Roll"], v["Spec"], v["GuildRank"] }); -- copies over name, bid, dkp, dkp-bid,date,roll,spec, and guild rank
            end
        end
    end

    -- SORT
    table.sort(
            entries,
            function(a1, a2)
                if (a1 and a2) then
                    if (a1 == nil) then
                        return 1 > 0;
                    elseif (a2 == nil) then
                        return 1 < 0;
                    end
                    if (WebDKP_BidSort["way"] == 1) then
                        if (a1[WebDKP_BidSort["curr"]] == a2[WebDKP_BidSort["curr"]]) then
                            return a1[1] > a2[1];
                        else
                            return a1[WebDKP_BidSort["curr"]] > a2[WebDKP_BidSort["curr"]];
                        end
                    else
                        if (a1[WebDKP_BidSort["curr"]] == a2[WebDKP_BidSort["curr"]]) then
                            return a1[1] < a2[1];
                        else
                            return a1[WebDKP_BidSort["curr"]] < a2[WebDKP_BidSort["curr"]];
                        end
                    end
                end
            end
    );

    local numEntries = getn(entries);
    local offset = FauxScrollFrame_GetOffset(WebDKP_BidFrameScrollFrame);
    FauxScrollFrame_Update(WebDKP_BidFrameScrollFrame, numEntries, 13, 13);

    -- Run through the table lines and put the appropriate information into each line
    for i = 1, 13, 1 do
        local line = getglobal("WebDKP_BidFrameLine" .. i);
        local nameText = getglobal("WebDKP_BidFrameLine" .. i .. "Name");
        local bidText = getglobal("WebDKP_BidFrameLine" .. i .. "Bid");
        local dkpText = getglobal("WebDKP_BidFrameLine" .. i .. "DKP");
        local postBidText = getglobal("WebDKP_BidFrameLine" .. i .. "Post");
        local rollText = getglobal("WebDKP_BidFrameLine" .. i .. "Roll");
        local SpecText = getglobal("WebDKP_BidFrameLine" .. i .. "Spec");
        local GuildRankText = getglobal("WebDKP_BidFrameLine" .. i .. "GuildRank");
        local index = i + FauxScrollFrame_GetOffset(WebDKP_BidFrameScrollFrame);

        if (index <= numEntries) then
            local playerName = entries[index][1];
            local date = entries[index][5];
            local charname = entries[index][1];
            line:Show();
            nameText:SetText(charname);
            if WebDKP_DkpTable[charname] == nil then
                WebDKP_DkpTable[charname] = {};
            end
            if WebDKP_DkpTable[charname]["class"] ~= nil then
                local charclass = WebDKP_DkpTable[charname]["class"];
                charclass = string.upper(charclass);
                charclass = string.gsub(charclass, " ", "");
                local englishClass = WebDKP.translations.CLASS_LOCALIZED_TO_ENG_MAP[charclass]
                if englishClass ~= nil then
                    local rPerc, gPerc, bPerc, argbHex = GetClassColor(string.upper(englishClass))
                    nameText:SetTextColor(rPerc, gPerc, bPerc);
                end
            end

            bidText:SetText(WebDKP_ROUND(entries[index][2], 2));
            dkpText:SetText(WebDKP_ROUND(entries[index][3], 2));
            postBidText:SetText(WebDKP_ROUND(entries[index][3], 2));
            rollText:SetText(entries[index][6]);
            SpecText:SetText(entries[index][7]);
            GuildRankText:SetText(entries[index][8]);
            -- kill the background of this line if it is not selected
            if (WebDKP_BidList[playerName .. date] and (not WebDKP_BidList[playerName .. date]["Selected"])) then
                getglobal("WebDKP_BidFrameLine" .. i .. "Background"):SetVertexColor(0, 0, 0, 0);
            else
                getglobal("WebDKP_BidFrameLine" .. i .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
            end
        else
            -- if the line isn't in use, hide it so we dont' have mouse overs
            line:Hide();
        end
    end
end

-- ================================
-- Handles chat messages directed towards bidding. This includes
-- placing a bid and remotly starting / stopping a bid.
-- ================================
function WebDKP_Bid_Event(arg1, arg2, isWhisper)
    local name = arg2;
    local flag = 0;
    -- if strfind(strlower(arg1), "^%s*sh%s*$") or strfind(strlower(arg1), "^%s*showhand%s*$") then
    --     arg1 = WebDKP.translations.triggerBID .. 
    -- end
    if WebDKP_bidInProgress and tonumber(arg1) ~= nil then
        arg1 = WebDKP.translations.triggerBID .. arg1
    end
    local trigger = arg1;
    local dkp = 0;
    if (WebDKP_IsBidChat(name, trigger)) then
        local cmd, subcmd = WebDKP_GetCmd(trigger);
        cmd, subcmd = WebDKP_GetCommaCmd(subcmd);
        startbiddingcmd = cmd;
        cmd = tonumber(cmd);


        -- SOMEONE HAS PLACED A BID
        if (string.find(string.lower(trigger), WebDKP.translations.triggerBID) == 1) then
            if cmd == nil then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper1);
            else
                if (WebDKP_bidInProgress == false) then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper2);
                elseif (cmd == "" or cmd == nil) then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper3);
                elseif ((cmd) < WebDKP_GetStartingBid()) then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper4 .. WebDKP_GetStartingBid());
                elseif (WebDKP_Options["BidFixedBidding"] == 1) then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper5);
                elseif (WebDKP_Options["DisableBid"] == 1) then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper6);
                else
                    flag = WebDKP_Bid_HandleBid(name, cmd, "NA");
                    if flag == 1 then
                        WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper7 .. cmd .. WebDKP.translations.SendWhisper8);
                    end
                end
            end
            -- SOMEONE WANTS TO BID ALL THEIR DKP
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerSH1) or string.find(string.lower(trigger), WebDKP.translations.triggerSH2) or string.find(string.lower(trigger), WebDKP.translations.triggerSH3)) then
            local dkp = WebDKP_GetDKP(name);
            if not isWhisper then
                WebDKP_SendAnnouncement(name .. WebDKP.translations.showhandannounce .. dkp, WebDKP_GetTellLocation());
            end
            if (WebDKP_bidInProgress == false) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper2);
            elseif (dkp < WebDKP_GetStartingBid()) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper9 .. WebDKP_GetStartingBid());
            elseif (WebDKP_Options["BidFixedBidding"] == 1) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper10);
            else
                flag = WebDKP_Bid_HandleBid(name, dkp, "NA");
                if flag == 1 then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper7 .. dkp .. WebDKP.translations.SendWhisper8);
                end
            end
            -- SOMEONE WANTS TO BID FOR MAIN SPEC
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerMAINTLENT) == 1) then

            if (WebDKP_bidInProgress == false) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper2);
            elseif (cmd == "" or cmd == nil) then
                cmd = 0;
                flag = WebDKP_Bid_HandleBid(name, cmd, "Main");
                if flag == 1 then
                    if WebDKP_Options["BidFixedBidding"] == 1 then
                        WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper11);
                    else
                        WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper12 .. cmd .. WebDKP.translations.SendWhisper8);
                    end
                end
            elseif (cmd < WebDKP_GetStartingBid()) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper13 .. WebDKP_GetStartingBid());
            elseif (WebDKP_Options["BidFixedBidding"] == 1) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper10);
            else
                flag = WebDKP_Bid_HandleBid(name, cmd, "Main");
                if flag == 1 then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper12 .. cmd .. WebDKP.translations.SendWhisper8);
                end
            end

            -- SOMEONE WANTS TO BID FOR OFF SPEC
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerOFFTLENT) == 1) then
            if (WebDKP_bidInProgress == false) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper2);
            elseif (cmd == "" or cmd == nil) then
                cmd = 0;
                WebDKP_Bid_HandleBid(name, cmd, "Off");
                if WebDKP_Options["BidFixedBidding"] == 1 then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper14);
                else
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper15 .. cmd .. WebDKP.translations.SendWhisper8);
                end
            elseif (cmd < WebDKP_GetStartingBid()) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper9 .. WebDKP_GetStartingBid());
            elseif (WebDKP_Options["BidFixedBidding"] == 1) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper16);
            else
                flag = WebDKP_Bid_HandleBid(name, cmd, "Off");
                if flag == 1 then
                    WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper15 .. cmd .. WebDKP.translations.SendWhisper8);
                end
            end

            -- THEY WANT THE BIDDING TO START
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerBIDDINGTOSTART) == 1) then
            if (WebDKP_bidInProgress == true) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper17);
            elseif (startbiddingcmd == "" or startbiddingcmd == nil) then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper18);
            else
                WebDKP_Bid_StartBid(startbiddingcmd, subcmd);
                WebDKP_BidFrameBidButton:SetText(WebDKP.translations.framestopbinding);
            end

            -- THEY WANT THE BIDDING TO STOP
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerBIDDINGTOSTOP) == 1) then
            if (WebDKP_bidInProgress == false) then
                WebDKP_SendWhisper(name, "There is no bid in progress for you to cancel");
            else
                WebDKP_Bid_StopBid();
                WebDKP_BidFrameBidButton:SetText(WebDKP.translations.framestartbinding);
            end
            -- SOMEONE NEEDS AN ITEM (FOR FIXED BIDDING ONLY - BIDS ALL THEY HAVE)
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerNEED) == 1 and WebDKP_Options["BidFixedBidding"] == 1) then
            dkp = WebDKP_GetDKP(name); -- bid all their dkp. in a fixed bid they will only be charged the cost from the loot table - this is just for ordering
            if dkp == nil then
                dkp = 0;
            end

            -- Check to see if custom percent is enabled for !need and if it is take the % of the DKP.
            if WebDKP_Options["AllNeed"] == 1 and WebDKP_Options["TurnBase"] == 1 then
                dkp = WebDKP_ROUND(dkp * ((tonumber(WebDKP_Options["NeedDKP"])) / 100), 0);
            end
            flag = WebDKP_Bid_HandleBid(name, dkp, "Main");
            if flag == 1 then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper12 .. dkp .. WebDKP.translations.SendWhisper8);
            end

            -- SOMEONE GREEDS AN ITEM (FOR FIXED BIDDING ONLY - BIDS ALL THEY HAVE)
        elseif (string.find(string.lower(trigger), WebDKP.translations.triggerGREED) == 1 and WebDKP_Options["BidFixedBidding"] == 1) then
            dkp = WebDKP_GetDKP(name); -- bid all their dkp. in a fixed bid they will only be charged the cost from the loot table - this is just for ordering
            if dkp == nil then
                dkp = 0;
            end
            -- Check to see if 50% bidding is enabled for !greed and if it is take 50% of the DKP.
            if WebDKP_Options["FiftyGreed"] == 1 and WebDKP_Options["TurnBase"] == 1 then

                dkp = WebDKP_ROUND(dkp * ((tonumber(WebDKP_Options["GreedDKP"])) / 100), 0);
            end
            flag = WebDKP_Bid_HandleBid(name, dkp, "Off");
            if flag == 1 then
                WebDKP_SendWhisper(name, WebDKP.translations.SendWhisper15 .. dkp ..WebDKP.translations.SendWhisper8);
            end

        end
    end
end

-- ================================
-- Gets the current starting bid from the gui
-- ================================
function WebDKP_GetStartingBid()
    local start = WebDKP_BidFrameStartingBid:GetText();
    if (start == nil or start == "") then
        start = 0;
    end
    return start + 0; -- add + 0 to convert it to an int


end

-- ================================
-- Returns true if the passed whisper is a chat message directed
-- towards web dkp bidding
-- ================================
function WebDKP_IsBidChat(name, trigger)
    if (string.find(string.lower(trigger), WebDKP.translations.triggerBID2) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerSH1) or
            string.find(string.lower(trigger), WebDKP.translations.triggerSH2) or
            string.find(string.lower(trigger), WebDKP.translations.triggerSH3) or
            string.find(string.lower(trigger), WebDKP.translations.triggerMAINTLENT) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerOFFTLENT) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerBIDDINGTOSTART) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerBIDDINGTOSTOP) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerNEED) == 1 or
            string.find(string.lower(trigger), WebDKP.translations.triggerGREED) == 1
    ) then
        return true
    end
    return false
end

-- ================================
-- Triggers Bidding to Start
-- ================================
function WebDKP_Bid_StartBid(item, time)
    if item ~= "" and item ~= nil then

        WebDKP_BidFrameBidButton:SetText(WebDKP.translations.framestopbinding);
        WebDKP_BidList = {};
        if (time == "" or time == nil or time == "0" or time == " ") then
            time = 0;
        end

        local quality, itemName, itemLink, itemLevel = WebDKP_GetItemInfo(item);
        WebDKP_bidItem = itemName;
        WebDKP_bidItemLink = itemLink;
        WebDKP_BidFrameItem:SetText(itemName);
        WebDKP_BidFrameTime:SetText(time);
        WebDKP_Bid_ItemNameChanged();


        -- if the options ask for it, also make an announcement in a raid warning
        if (WebDKP_Options["BidAnnounceRaid"] == 1) then
            WebDKP_SendAnnouncement(WebDKP.translations.SendAnnouncement, "RAID_WARNING");
        end
        WebDKP_AnnounceBidStart(itemLink, time, WebDKP_GetStartingBid());

        WebDKP_bidInProgress = true;
        WebDKP_BidFrameItem:SetText(itemLink);

        WebDKP_Bid_UpdateTable();
        WebDKP_Bid_ShowUI();

        if (time ~= 0) then
            WebDKP_bidCountdown = time;
            WebDKP_Bid_UpdateFrame:Show();
        else
            WebDKP_Bid_UpdateFrame:Hide();
        end
    else
        WebDKP_Print(WebDKP.translations.ItemName_Print);
    end

end


-- ================================
-- Stops the current bidding
-- ================================
function WebDKP_Bid_StopBid()
    local totalbids = 0;
    WebDKP_Bid_UpdateFrame:Hide();                        -- stop any countdowns
    WebDKP_BidFrame_Countdown:SetText("");

    WebDKP_BidFrameBidButton:SetText(WebDKP.translations.framestartbinding);            -- fix the button text
    local bidder, bid = WebDKP_Bid_GetHighestBid();                -- find highest bidder (not used any more)
    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            totalbids = totalbids + 1;
        end
    end
    WebDKP_AnnounceBidEnd(WebDKP_bidItem, bidder, bid, totalbids);            -- make the announcement

    WebDKP_bidInProgress = false;
    WebDKP_Bid_ShowUI();                            -- show the bid gui

end


-- ================================
-- Handles a bid placed by a player. 
-- ================================
function WebDKP_Bid_HandleBid(playerName, bidAmount, spec)
    local flag = 0;
    local postDkp = 0;
    if WebDKP_DkpTable[playerName] == nil then
        WebDKP_DkpTable[playerName] = {};
    end
    -- if a bid is not in progress ignore it
    if (WebDKP_bidInProgress) then
        --load up some information about the player
        local dkp = WebDKP_GetDKP(playerName);            -- how much dkp do they have now

        startingBid = WebDKP_GetStartingBid();
        postDkp = dkp - bidAmount;            -- what they will have if they spend this

            if startingBid == nil or startingBid == "" then
            startingBid = 0;
        end

        local postDkp2 = dkp - startingBid;            -- Do they have enough based on the starting bid?
        bidAmount = bidAmount + 0;                -- make sure bid amount is an int
        local date = date("%Y-%m-%d %H:%M:%S");        -- record when this bid was placed
        local guildrank = WebDKP_GetGuildRank(playerName);    -- Gets the guild rank
        -- check to see if we should reject this bid if it makes the user go into negative balance
        if (postDkp < 0 and WebDKP_Options["BidAllowNegativeBids"] == 0) then
            WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper19);
            WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper20 .. dkp);
            -- check to see if we should reject their !need because the startingBid/cost is too high
        elseif (postDkp2 < 0 and WebDKP_Options["BidAllowNegativeBids"] == 0) then
            WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper21 .. startingBid);
        else
            --Set the success flag to return
            flag = 1;
            -- If there is no existing Roll data then set it to NA.
            --if WebDKP_BidList[playerName..date] == nil then
            --	WebDKP_BidList[playerName..date] = {};
            --	WebDKP_BidList[playerName..date]["Roll"] = 0;
            --end
            -- bid is ok, we can go ahead and record it
            WebDKP_BidList[playerName .. date] = {            -- place their bid in the bid table (combine it with the date so 1 player can have multiple bids / unique indices in the table)
                ["Name"] = playerName,
                ["Bid"] = bidAmount,
                ["DKP"] = dkp,
                ["Post"] = postDkp,
                ["Date"] = date,
                ["Roll"] = "NA",
                ["Spec"] = spec,
                ["GuildRank"] = guildrank;
            }

            if (WebDKP_BidList[playerName .. date]["Selected"] == nil) then
                WebDKP_BidList[playerName .. date]["Selected"] = false;
            end

            WebDKP_Bid_UpdateTable();

            WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper24);

            -- if they bid too low we should tell them
            local highBidder, highBid = WebDKP_Bid_GetHighestBid();
            if (highBidder == playerName and WebDKP_Options["BidNotifyLowBids"] == 1) then
                WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper22);
            elseif (highBidder ~= playerName and WebDKP_Options["BidNotifyLowBids"] == 1) then
                WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper23 .. highBid .. " dkp.");
            end

        end
        return flag;
    else
        WebDKP_SendWhisper(playerName, WebDKP.translations.SendWhisper2);
    end
end

-- ================================
-- Returns the highest bidder and what they bid. 
-- ================================
function WebDKP_Bid_GetHighestBid()
    local highestBidder = nil;
    local highestBid = nil;

    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Bid"] ~= nil) then
                if highestBid == nil then
                    highestBidder = v["Name"];
                    highestBid = v["Bid"];
                elseif (v["Bid"] > highestBid) then
                    highestBidder = v["Name"];
                    highestBid = v["Bid"];

                end
            end
        end
    end
    return highestBidder, highestBid;
end

-- ================================
-- Returns the top 3 bidders and what they bid. 
-- ================================
function WebDKP_Bid_GetTopThree()
    local highestBidder = nil;
    local highestBidder2 = nil;
    local highestBidder3 = nil;
    local highestBid = 0;
    local highestBid2 = 0;
    local highestBid3 = 0;

    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Bid"] ~= nil) then
                if (v["Bid"] > highestBid) then
                    highestBidder = v["Name"];
                    highestBid = v["Bid"];
                elseif (v["Bid"] > highestBid2 and v["Bid"] ~= highestBid) then
                    highestBidder2 = v["Name"];
                    highestBid2 = v["Bid"];
                elseif (v["Bid"] > highestBid3 and v["Bid"] ~= highestBid and v["Bid"] ~= highestBid2) then
                    highestBidder3 = v["Name"];
                    highestBid3 = v["Bid"];

                end
            end
        end
    end
    return highestBidder, highestBidder2, highestBidder3, highestBid, highestBid2, highestBid3;
end



-- ===============================================================================
-- Returns the highest roller and what they rolled. 
-- ===============================================================================
function WebDKP_Bid_GetHighestRoll()
    local highestRoller = WebDKP.translations.NOone;
    local highestRoll = 0;

    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Roll"] ~= nil and v["Roll"] ~= "NA") then
                if (v["Roll"] > highestRoll) then
                    highestRoller = v["Name"];
                    highestRoll = v["Roll"];

                end
            end
        end
    end
    return highestRoller, highestRoll;
end

-- ================================
-- Method invoked when the user clicks the award button the on 
-- bid frame. Finds the first person who is selected
-- and awards them the item. 
-- ================================
function WebDKP_Bid_AwardSelected()
    -- find out who is selected
    local player, bid, spec = WebDKP_Bid_GetSelected();
    local _, item, link = WebDKP_GetItemInfo(WebDKP_bidItem);
    local startingBid = WebDKP_BidFrameStartingBid:GetText();
    if startingBid ~= nil then
        startingBid = tonumber(startingBid);
    end
    -- Check to see if the persons bid is less than the startingBid or minimum. If it is then Negative Bids must be enabled so change their bid to the startingBid value for the confirmation box.
    if startingBid ~= nil and bid < startingBid then
        bid = startingBid;
    end

    -- if someone is selected, award them the item via the award class
    if (player == nil) then
        WebDKP_Print(WebDKP.translations.Nochoice_Print);
        PlaySound(847);
    else
        --since we are awarding, stop the bid
        if (WebDKP_bidInProgress) then
            WebDKP_Bid_StopBid();
        end

        if (WebDKP_Options["BidFixedBidding"] == 1 and WebDKP_Options["TurnBase"] == 0) then
            if spec == "Main" then
                bid = WebDKP_GetLootTableCost(WebDKP_bidItem);
            elseif spec == "Off" and WebDKP_Options["FiftyGreed"] == 1 then
                multval = (tonumber(WebDKP_Options["GreedDKP"]) / 100);

                tablevalue = WebDKP_GetLootTableCost(WebDKP_bidItem);
                if tablevalue == nil then
                    tablevalue = WebDKP_GetDKP(player);
                end
                bid = WebDKP_ROUND(tablevalue * multval, 0);
            else
                bid = WebDKP_GetLootTableCost(WebDKP_bidItem);
            end
        end

            -- check the options to see if we need to display a confirmation box
        if (WebDKP_Options["BidConfirmPopup"] == 1 or bid == nil) then
            if (WebDKP_Options["BidFixedBidding"] == 1 and bid == nil) then
                WebDKP_Bid_ShowConfirmFrame(WebDKP.translations.ShowAwardtext .. player .. " " .. link .. WebDKP.translations.ShowAwardtext3, 0);
            elseif WebDKP_Options["BidFixedBidding"] == 1 then
                WebDKP_Bid_ShowConfirmFrame(WebDKP.translations.ShowAwardtext .. player .. " " .. link .. WebDKP.translations.ShowAwardtextfor .. bid .. WebDKP.translations.ShowAwardtext4, bid);
            else
                WebDKP_Bid_ShowConfirmFrame(WebDKP.translations.ShowAwardtext .. player .. " " .. link .. WebDKP.translations.ShowAwardtextfor .. bid .. WebDKP.translations.ShowAwardtext5, bid);
            end

        else
            WebDKP_Bid_AwardPerson(bid);

        end
    end
end


-- ================================
-- Auto Assign the Loot Item. 
-- Auto Give the Item. 
-- Added by Zevious (Bronzebeard)
-- Updated for MOP..GetMasterLootCandidate now requires slotID (worgames)
-- ================================
function Auto_Assign_Item_Player(player)
    local _, item, link = WebDKP_GetItemInfo(WebDKP_bidItem);

    for li = 1, GetNumLootItems() do
        local lootIcon, lootName, lootQuantity, rarity, locked = GetLootSlotInfo(li);
        if (lootName == item) then
            for ci = 1, GetNumGroupMembers() do
                candidate = GetMasterLootCandidate(li, ci);
                -- name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(ci);
                if (candidate == player) then
                    GiveMasterLoot(li, ci);
                    ci = GetNumGroupMembers() + 1;
                    li = GetNumLootItems() + 1
                end
            end
        end
    end
end


-- ================================
-- Event handler for the start / stop bid button. 
-- This button toggles between states when clicked. 
-- ================================
function WebDKP_Bid_ButtonHandler()
    -- clear the rolling in case rolling and bidding are monitored at the same time
    WebDKP_RollInProgress = false;
    for i = 1, WebDKP_Roll_Total, 1 do
        WebDKP_Rolls[i] = nil;
    end
    WebDKP_Roll_Total = 1;

    if (WebDKP_bidInProgress) then
        WebDKP_Bid_StopBid();
    else

        local item = WebDKP_BidFrameItem:GetText();
        local time = WebDKP_BidFrameTime:GetText();
        WebDKP_Bid_StartBid(item, time);

    end
end



-- ================================
-- Event handler for the start / stop roll button. 
-- This button toggles between states when clicked. 
-- ================================
function WebDKP_Roll_Initiate()
    if (WebDKP_RollInProgress) then
        WebDKP_Roll_Stop();
    else
        local item = WebDKP_BidFrameItem:GetText();
        local time = WebDKP_BidFrameTime:GetText();
        WebDKP_Roll_Start(item, time);
    end
end




-- ================================
-- Method invoked when the user clicks the award button the on 
-- bid frame. Finds the first person who is selected
-- and awards them the item. 
-- ================================
function WebDKP_Bid_GetSelected()
    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            if (v["Selected"] == true) then
                return v["Name"], v["Bid"], v["Spec"];
            end
        end
    end
    return nil, 0;
end


-- ================================
-- Event handler for the bidding update frame. The update frame is visible (and calling this method)
-- when a timer value was specified. The addon countdowns until 0 - and when it reaches 0 it stops
-- the current bid
-- ================================
function WebDKP_Bid_OnUpdate(self, elapsed)
    local this = self;
    this.TimeSinceLastUpdate = this.TimeSinceLastUpdate + elapsed;

    if (this.TimeSinceLastUpdate > 1.0) then

        -- Check to see if a roll is in progress and if so get the highest roller
        if WebDKP_RollInProgress == true then
            highest_roller, high_roll = WebDKP_Bid_GetHighestRoll();
        end
        this.TimeSinceLastUpdate = 0;
        -- decrement the count down
        WebDKP_bidCountdown = WebDKP_bidCountdown - 1;
        --WebDKP_Print(WebDKP_bidCountdown);
        WebDKP_BidFrame_Countdown:SetText(WebDKP.translations.framelefttimetext .. WebDKP_bidCountdown .. WebDKP.translations.framelefttimesecondtext);
        highest_bidder, high_bid = WebDKP_Bid_GetHighestBid();
        if highest_bidder == nil then
            highest_bidder = WebDKP.translations.NOone;
            high_bid = 0;
        end
        local _, _, link = WebDKP_GetItemInfo(WebDKP_bidItem);
        local announceText = WebDKP_Options["EditDuringAnnounce"];

        if WebDKP_bidInProgress == true and WebDKP_Options["SilentBidding"] == 0 then
            rollmessage = "";
            if announceText ~= "" and announceText ~= nil then
                rollmessage = announceText;
            else
                rollmessage = defaultBIPmsg;
            end
            rollmessage = string.gsub(rollmessage, "$name", highest_bidder);
            rollmessage = string.gsub(rollmessage, "$dkp", high_bid);
            rollmessage = string.gsub(rollmessage, "$item", link);

            if (WebDKP_bidCountdown == 45) then
                -- 45 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "45");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 30) then
                -- 30 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "30");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 15) then
                -- 15 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "15");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 5) then
                -- 5 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "5");
                WebDKP_SendAnnouncementDefault(rollmessage);
            elseif (WebDKP_bidCountdown == 4) then
                -- 4 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "4");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 3) then
                -- 3 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "3");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 2) then
                -- 2 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "2");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 1) then
                -- 1 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "1");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown <= 0) then
                -- countdown reached 0

                -- stop the bidding!
                WebDKP_Bid_StopBid();
            end
        elseif WebDKP_bidInProgress == true and WebDKP_Options["SilentBidding"] == 1 then
            rollmessage = "";
            if announceText ~= "" and announceText ~= nil then
                rollmessage = announceText;
            else
                rollmessage = defaultSBIPmsg;
            end

            rollmessage = string.gsub(rollmessage, "$name", highest_bidder);
            rollmessage = string.gsub(rollmessage, "$dkp", high_bid);
            rollmessage = string.gsub(rollmessage, "$item", link);

            if (WebDKP_bidCountdown == 45) then
                -- 45 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "45");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 30) then
                -- 30 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "30");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 15) then
                -- 15 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "15");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 5) then
                -- 5 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "5");
                WebDKP_SendAnnouncementDefault(rollmessage);
            elseif (WebDKP_bidCountdown == 4) then
                -- 4 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "4");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 3) then
                -- 3 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "3");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 2) then
                -- 2 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "2");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 1) then
                -- 1 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "1");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown <= 0) then
                -- countdown reached 0

                -- stop the bidding!
                WebDKP_Bid_StopBid();
            end

        else
            announceRollText = WebDKP_Options["EditRollAnnounce"];
            rollmessage = "";
            if announceRollText ~= "" and announceRollText ~= nil then
                rollmessage = announceRollText;
            else
                rollmessage = defaultRIPmsg;
            end
            rollmessage = string.gsub(rollmessage, "$name", highest_roller);
            rollmessage = string.gsub(rollmessage, "$roll", high_roll);
            rollmessage = string.gsub(rollmessage, "$item", link);
            if (WebDKP_bidCountdown == 45) then
                -- 45 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "45");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 30) then
                -- 30 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "30");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 15) then
                -- 15 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "15");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 5) then
                -- 5 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "5");
                WebDKP_SendAnnouncementDefault(rollmessage);
            elseif (WebDKP_bidCountdown == 4) then
                -- 4 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "4");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 3) then
                -- 3 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "3");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 2) then
                -- 2 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "2");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown == 1) then
                -- 1 seconds left
                rollmessage = string.gsub(rollmessage, "$time", "1");
                WebDKP_SendAnnouncementDefault(rollmessage);

            elseif (WebDKP_bidCountdown <= 0) then
                -- countdown reached 0

                WebDKP_Roll_Stop();

            end
        end
    end
end

-- ================================
-- Invoked when a user uses shift/alt/ctrl+click to display item details.
-- As long as a bid is not in progress and the bid gui is displayed, 
-- fill the item information into the form
-- ================================
function WebDKP_Bid_ItemChatClick(link, text, button)

    if (IsControlKeyDown() or IsAltKeyDown() or IsShiftKeyDown()) then
        if (WebDKP_BidFrame:IsShown() and WebDKP_bidInProgress == false) then
            local _, itemName, itemLink = WebDKP_GetItemInfo(link);
            WebDKP_BidFrameItem:SetText(itemLink);
            WebDKP_bidItemLink = itemLink;
            -- fill in the starting bid if we can find it
            startingBid = WebDKP_GetLootTableCost(itemName);

            if (startingBid ~= nil) then
                WebDKP_BidFrameStartingBid:SetText(startingBid);
            else
                -- Nothing at this time
            end
        end
    end
end

-- ================================
-- Called when the user enters a new item name in the item name textbox. 
-- Checks to see if it can autoload a new starting bid
-- Checks to see if the Item Level Multi and Slot level Multi are enabled
-- ================================
function WebDKP_Bid_ItemNameChanged()
    local itemName = WebDKP_BidFrameItem:GetText();

    startingBid = WebDKP_GetLootTableCost(itemName);

    if (startingBid ~= nil) then
        startingBid = WebDKP_ROUND(startingBid, 1);
        WebDKP_BidFrameStartingBid:SetText(startingBid);
    else
        -- Nothing at this time
    end
end

-- ================================
-- Confirm Frame
-- ================================
function WebDKP_Bid_ShowConfirmFrame(title, cost)
    PlaySound(850);
    WebDKP_BidConfirmFrame:Show();

    WebDKP_BidConfirmFrameTitle:SetText(title);
    if (cost ~= nil) then
        WebDKP_BidConfirmFrameCost:SetText(cost);
    else
        WebDKP_BidConfirmFrameCost:SetText(0);
    end
end

-- ================================
-- Awards the currently selected player the currently 
-- ================================
function WebDKP_Bid_AwardPerson(cost)
    local player, _ = WebDKP_Bid_GetSelected();
    local percentcost = string.find(cost, "%%");
    local percentflag = 0;
    local tableid = WebDKP_GetTableid();
    local points = 0;

    if percentcost ~= nil then

        -- This means they are entering a percent so calculate the proper cost
        -- Substitute the % with "" so we are left with just the number as a string
        cost = string.gsub(cost, "%%", "")
        cost = tonumber(cost);
        percentflag = 1;

    end

    if WebDKP_Options["AutoGive"] == 1 then
        Auto_Assign_Item_Player(player);
    end
    points = cost * -1;
    if percentflag == 1 then
        --local actualname = player[0]["name"];
        cost = (cost / 100) * WebDKP_DkpTable[player]["dkp_" .. tableid] * -1;
        points = WebDKP_ROUND(cost, 2);
    end

    --put this into a points table for the add dkp method
    local playerTable = {};
    playerTable[0] = {}
    playerTable[0]["name"] = player;
    playerTable[0]["class"] = WebDKP_GetPlayerClass(player);
    --award the item

    --local _,itemName,itemLink = WebDKP_GetItemInfo(WebDKP_bidItem);
    WebDKP_AddDKP(points, WebDKP_bidItemLink, "true", playerTable)
    WebDKP_AnnounceAwardItem(points, WebDKP_bidItemLink, player);

    WebDKP_UpdateTableToShow();

    -- Update the table so we can see the new dkp status
    WebDKP_UpdateTable();       --update the gui

    PlaySound(120);

   -- WebDKP_Bid_HideUI();

    -- record this item as having been given in a bid
    WebDKP_lastBidItem = WebDKP_bidItem;
end

-- ================================
-- Process rolling
-- Added by Zevious (Bronzebeard)
-- ================================
function WebDKP_ProcessRoll(player, roll, min_roll, max_roll)
    roll = tonumber(roll);
    min_roll = tonumber(min_roll);
    max_roll = tonumber(max_roll);
    local RolledFlag = 0;
    local date = date("%Y-%m-%d %H:%M:%S");
    local dkp = WebDKP_GetDKP(player);
    local guildrank = WebDKP_GetGuildRank(player);

    if WebDKP_RollInProgress == true or (WebDKP_BidInProgress == True and WebDKP_Options["BidandRoll"] == 1) then
        -- Check Boundaries (1-100)
        if (min_roll == 1 and max_roll == 100) then
            for i = 1, WebDKP_Roll_Total, 1 do
                if (WebDKP_Rolls[i] == player) then
                    RolledFlag = 1;
                end
            end

            if RolledFlag == 0 then
                WebDKP_Roll_Total = WebDKP_Roll_Total + 1;
                WebDKP_Rolls[WebDKP_Roll_Total] = player
                WebDKP_BidList[player .. date] = {            -- Add to main Table
                    ["Name"] = player,
                    ["Bid"] = 0,
                    ["DKP"] = dkp,
                    ["Post"] = 0,
                    ["Date"] = date,
                    ["Roll"] = roll,
                    ["Spec"] = "Roll",
                    ["GuildRank"] = guildrank;
                }
                WebDKP_Bid_UpdateTable();

            end

        end

    end

end

-- ================================
-- Triggers Rolling to Start
-- Added by Zevious (Bronzebeard)
-- ================================
function WebDKP_Roll_Start(item, time)

    if item ~= "" and item ~= nil then

        WebDKP_BidFrameRollButton:SetText(WebDKP.translations.framestoprolling);

        WebDKP_BidList = {};
        if (time == "" or time == nil or time == "0" or time == " ") then
            time = 0;
        end

        local quality, itemName, itemLink = WebDKP_GetItemInfo(item);
        WebDKP_bidItem = itemName;
        WebDKP_bidItemLink = itemLink;
        WebDKP_BidFrameItem:SetText(itemName);
        WebDKP_BidFrameTime:SetText(time);
        WebDKP_Bid_ItemNameChanged();


        -- if the options ask for it, also make an announcement in a raid warning
        if (WebDKP_Options["BidAnnounceRaid"] == 1) then
            WebDKP_SendAnnouncement(WebDKP.translations.framestartrolling, "RAID_WARNING");
        end
        WebDKP_AnnounceRollStart(itemLink, time);

        WebDKP_RollInProgress = true;
        WebDKP_BidFrameItem:SetText(itemLink);

        WebDKP_Bid_UpdateTable();

        WebDKP_Bid_ShowUI();

        if (time ~= 0) then
            WebDKP_bidCountdown = time;
            WebDKP_Bid_UpdateFrame:Show();
        else
            WebDKP_Bid_UpdateFrame:Hide();
        end
    else
        WebDKP_Print(WebDKP.translations.startrolling_Print);
    end

end


-- ================================
-- Stops the current rolling
-- Added by Zevious (Bronzebeard)
-- ================================
function WebDKP_Roll_Stop()
    local totalrolls = 0;
    WebDKP_Bid_UpdateFrame:Hide();                        -- stop any countdowns
    WebDKP_BidFrame_Countdown:SetText("");
    for key_name, v in pairs(WebDKP_BidList) do
        if (type(v) == "table") then
            totalrolls = totalrolls + 1;
        end
    end
    WebDKP_BidFrameRollButton:SetText(WebDKP.translations.framestartrolling);        -- fix the button text
    WebDKP_AnnounceRollEnd(WebDKP_bidItem, bidder, bid, totalrolls);    -- make the announcement
    WebDKP_RollInProgress = false;
    WebDKP_Bid_ShowUI();                            -- show the bid gui
    for i = 1, WebDKP_Roll_Total, 1 do
        WebDKP_Rolls[i] = nil;
    end
    WebDKP_Roll_Total = 1;
end

-- ================================
-- Called when you Toggle the Turn Base DKP button
-- Added by Zevious (Bronzebeard)
-- ================================
function WebDKP_Turn_Base()
    WebDKP_Options_ToggleOption("TurnBase");
    if WebDKP_Options["BidFixedBidding"] == 0 then
        WebDKP_BiddingOptions_FrameToggleBidFixedBidding:SetChecked(true);
        WebDKP_Options_ToggleOption("BidFixedBidding");
    end

end

-- ================================
-- Called when you Toggle the Fixed Bidding System
-- Added by Zevious (Bronzebeard)
-- ================================
function WebDKP_Fixed_Bidding()
    WebDKP_Options_ToggleOption("BidFixedBidding");
    if WebDKP_Options["TurnBase"] == 1 then
        WebDKP_BiddingOptions_FrameToggleTurnBase:SetChecked(false);
        WebDKP_Options_ToggleOption("TurnBase");
    end

end

