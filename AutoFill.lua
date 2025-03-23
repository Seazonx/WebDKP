------------------------------------------------------------------------
-- AUTO FILL Tasks
------------------------------------------------------------------------
-- This file contains methods related to auto filling in information in your dkp
-- form when items drop
------------------------------------------------------------------------

-- ================================
-- Helper structure that maps rarity of an item back to its rank
-- ================================
WebDKP_RarityTable = {
    [0] = -1,
    [1] = 0,
    [2] = 1,
    [3] = 2,
    [4] = 3,
    [5] = 4
};

local frames = {  };
-- ================================
-- An event that is triggered when loot is taken. If auto fill 
-- is enabled, this must check to see:
-- 1 - what item dropped and fill it in the item input
-- 2 - see what player got the item and select them
-- 3 - see if the item is in the loot table, and enter the cost if it is
-- 4 - if auto award is enabled it should award the item
-- ================================
function WebDKP_AwardItem_Event2(cost, player, item)
    WebDKP_SelectPlayerOnly(player);
    local player2 = WebDKP_GetSelectedPlayers(1);
    if (type(player2) ~= 'table' or player2[0].name == "") then
        WebDKP_Print(WebDKP.translations.Noplayer_Print);
        PlaySound(847);
    end

    local percentflag = 0;
    local tableid = WebDKP_GetTableid();

    if strfind(cost, "%%") then
        -- This means they are entering a percent so calculate the proper cost
        -- Substitute the % with "" so we are left with just the number as a string
        cost = gsub(cost, "%%", "")
        cost = tonumber(cost);

        percentflag = 1;
    end

    if (cost == nil or cost == "") then
        WebDKP_Print(WebDKP.translations.Noinput_Print);
        cost = 0;
    end

    if percentflag == 1 then
        cost = WebDKP_ROUND(-cost / 100 * WebDKP_DkpTable[player2[0].name]["dkp_" .. tableid], 2);
    else
        cost = -cost;
    end

    WebDKP_AddDKP(cost, item, "true", player2)
    WebDKP_AnnounceAwardItem(cost, item, player2[0]["name"]);

    -- Update the table so we can see the new dkp status
    WebDKP_UpdateTableToShow();
    WebDKP_UpdateTable();
end
function WebDKP_ShowAwardFrame(title, cost, link, player, onYesClickEvent)
    PlaySound(850);
    local frame = CreateFrame("Frame", "WebDKP_AwardFrame_" .. tostring(time()), UIParent, "WebDKP_AwardFrameTemplate");
    frame.title:SetText(WebDKP.translations.AwardFrameTitle)
    frame.yes:SetText(WebDKP.translations.AwardFrameTitleYES)
    frame.no:SetText(WebDKP.translations.AwardFrameTitleNO)
    frame.player = player
    frame.link = link;
    frame.title:SetText(title);
    frame.cost:SetText(cost or "");
    frame.yes:SetScript("OnClick", function(self)
        frame:Hide();
        local cost = tonumber(frame.cost:GetText()) or 0;
        onYesClickEvent(cost, frame.player, frame.link);
        PlaySound(120);
        frame = nil
    end);
    frame.no:SetScript("OnClick", function(self)
        frame:Hide();
        PlaySound(851);
        frame = nil
    end);
    frame:Show();
end
local pattern_LOOT_ITEM = gsub(LOOT_ITEM, "%%s", "(.+)");
local pattern_LOOT_ITEM_SELF = gsub(LOOT_ITEM_SELF, "%%s", "(.+)");
function WebDKP_Loot_Taken(arg1, player)
    --WebDKP_Print(string.format("%s %s", arg1, tostring(sPlayer)))
    local instanceID = select(8, GetInstanceInfo())
    if WebDKP.translations.BOSS_MAP[instanceID] == nil then
        return
    end

    if (WebDKP_Options["AutofillEnabled"] == 0) then
        return ;
    end
    if not player then
        return ;
    end
    if strfind(arg1, pattern_LOOT_ITEM) or strfind(arg1, pattern_LOOT_ITEM_SELF) then
        --1 Find out what item was dropped
        local item_name, link, rarity = GetItemInfo(arg1)
        if not item_name then
            return ;
        end

        -- if this item isn't past the autofill rarity threshold in the options, skip it
        if (WebDKP_RarityTable[rarity] < WebDKP_Options["AutofillThreshold"]) then
            return ;
        end

        -- if this is in our ignore list, we can skip it
        if WebDKP_ShouldIgnoreItem(item_name) then
            return ;
        end

        -- if this is the item that was last bid off/awarded, we can skip autofilling it
        if (item_name == WebDKP_lastBidItem or item_name == WebDKP_bidItem) then
            WebDKP_lastBidItem = "";
            return ;
        end

        local cost;
        -- --display the item name in the form
        -- WebDKP_AwardItem_FrameItemName:SetText(item_name);

        -- see if we can determine the cost while we are at it...
        if (WebDKP_Loot ~= nil) then
            cost = WebDKP_Loot[item_name] or 0;
            -- if (cost ~= nil) then
            --     WebDKP_AwardItem_FrameItemCost:SetText(cost);
            -- else
            --     WebDKP_AwardItem_FrameItemCost:SetText("");
            -- end
        end
        -- --select the player
        -- WebDKP_SelectPlayerOnly(sPlayer);

        -- if we are set to auto award items, go ahead and display the popup
        if (WebDKP_Options["AutoAwardEnabled"] == 1) then
            --PlaySound(618);
            -- If we know the cost, prefill it in the form.
            -- If not, show an input for them to enter something.
            WebDKP_ShowAwardFrame(
                    WebDKP.translations.ShowAwardtext .. player .. " " .. link .. " ，DKP: " .. cost .. WebDKP.translations.ShowAwardtext2,
                    cost,
                    link,
                    player,
                    WebDKP_AwardItem_Event2
            );
        end
    end
end

-- ================================
-- Event handler for entering a name in the award item field
-- Will automattically fill in the cost if the cost is available in the players loot table
-- ================================
function WebDKP_AutoFillCost()
    --if ( WebDKP_Options["AutofillEnabled"] == 0 ) then
    --	return;
    --end

    local itemName = WebDKP_AwardItem_FrameItemName:GetText();

    startingBid = WebDKP_GetLootTableCost(itemName);

    if (startingBid ~= nil) then
        WebDKP_AwardItem_FrameItemCost:SetText(startingBid);
    else
        -- Nothing at this time
    end
end


-- ================================
-- Event handler for entering a name in the award dkp reason field
-- Will automattically fill in the cost if the cost is available in the players toot table
-- ================================
function WebDKP_AutoFillDKP()
    if (WebDKP_Options["AutofillEnabled"] == 0) then
        return ;
    end
    local sName = WebDKP_AwardDKP_FrameReason:GetText();

    -- see if we can determine the cost while we are at it...
    if (WebDKP_Loot ~= nil and sName ~= nil) then
        local cost = WebDKP_Loot[sName];
        if (cost ~= nil) then
            WebDKP_AwardDKP_FramePoints:SetText(cost);
        end
    end
end

function WebDKP_AddTooltipValue(self)
    local itemName, itemLink = self:GetItem()
    local value = WebDKP_Loot[itemName] or 0
    if tonumber(value) > 0 then
        self:AddLine("|cFF00FF00WebDKP|cFFFFFF00 拾取值: |cFFFFFFFF" .. value)
    end
end

ItemRefTooltip:HookScript("OnTooltipSetItem", WebDKP_AddTooltipValue)
GameTooltip:HookScript("OnTooltipSetItem", WebDKP_AddTooltipValue)