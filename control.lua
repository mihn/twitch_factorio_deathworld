
local function get_target_player_from_name (target_name)
    if target_name == "*" or target_name == "" then
        local players = {}
        for _, player in pairs(game.players) do
            if player.connected then
                table.insert(players, player)
            end
        end
        return players[math.random(#players)]
    end

    local target_player = game.get_player(target_name)
    if target_player == nil then
        for _, player in pairs(game.players) do
            if string.find(string.lower(player.name), string.lower(target_name)) then
                target_player = player
            end
        end
    end

    if target_player and target_player.connected then
        return target_player
    else
        return nil
    end
end


local function reset_player_buff (player_index, buff_name)
    local buff = global.player_buffs[player_index][buff_name] or nil
    if buff == nil then return end

    local p = game.get_player(player_index)
    p[buff_name] = buff["default"]
    buff = nil
end

local function check_for_expired_buffs (nth_tick_event)
    if global.player_buffs == nil then return end

    for player_index, buff_details in pairs(global.player_buffs) do
        for buff_name, buff_value in pairs(buff_details) do
            if buff_value["remaining_seconds"] == 0 then
                reset_player_buff(player_index, buff_name)
            else
               buff_value["remaining_seconds"] = buff_value["remaining_seconds"] - 1
            end
        end
    end
end

script.on_init(function ()
    global.player_buffs = global.player_buffs or {}
end)

script.on_nth_tick(60, function ()
    check_for_expired_buffs()
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    if global.player_buffs == nil then
        global.player_buffs = {}
    end
    global.player_buffs[event.player_index] = {}
end)

script.on_event(defines.events.on_pre_player_left_game, function(event)
    if global.player_buffs == nil or global.player_buffs[event.player_index] == nil then
        return
    end
    for buff_name, buff_value in pairs(global.player_buffs[event.player_index]) do
        reset_player_buff(event.player_index, buff_name)
    end
    global.player_buffs[event.player_index] = nil
end)

remote.add_interface("twitch_deathworld",{
    help_research = function (name, amount)
        local player = game.players[1];
        local force = player.force;
        local research = force.current_research;

        if research then
            local new_amount = force.research_progress + amount;
            if new_amount >= 1 then
                force.research_progress = 1;
                force.print({"", "[Twitch] ", name, " completed ", research.localised_name}, {0, 1, 0, 1});
            else
                force.research_progress = new_amount;
                force.print({"", "[Twitch] ", name, " contributed to ", research.localised_name}, {0, 1, 0, 1});
            end
            rcon.print("worked");
            return;
        end
        rcon.print("failed");
        return;
    end,

    hurt_research = function (name, amount)
        local player = game.players[1];
        local force = player.force;
        local research = force.current_research;

        if research then
            local new_amount = force.research_progress - amount;
            if new_amount <= 0 then
                force.research_progress = 0;
                force.print({"", "[Twitch] ", name, " completely reset ", research.localised_name}, {1, 0, 0, 1});
            else
                force.research_progress = new_amount;
                force.print({"", "[Twitch] ", name, " set back ", research.localised_name}, {1, 0, 0, 1});
            end
            rcon.print("worked");
            return;
        end
        rcon.print("failed");
        return;
    end,

    plant_tree = function (name, targetName, amount, silent)
        local planted = false;
        local targetPlayer = get_target_player_from_name(targetName)

        if targetPlayer then
            for i = 1, tonumber(amount) do
                local targetX = targetPlayer.position.x + math.random(-6, 6);
                local targetY = targetPlayer.position.y + math.random(-6, 6);
                local createdEntity = game.surfaces.nauvis.create_entity({name="tree-01", amount=1, position={targetX, targetY}});
                if createdEntity then
                    planted = true;
                end
            end

            if planted then
                if not silent then
                    targetPlayer.force.print({"", "[Twitch] ", name, " planted a lovely forest near ", targetPlayer.name, " <3"}, {0.2, 0.8, 0.2, 1});
                end
                rcon.print("worked");
                return;
            else
                rcon.print("failed|Unable to plant tree here");
                return;
            end
        end
        rcon.print("failed|Unable to find player by that name");
        return;
    end,

    drain_accumulators = function (name, amount, silent)
        local drained = 0;
        local accumulators = game.surfaces.nauvis.find_entities_filtered{type="accumulator"};

        for i = 1, #accumulators do
            local accumulator = accumulators[i];
            local toDrain = math.min(accumulator.energy, amount - drained);
            accumulator.energy = accumulator.energy - toDrain;
            drained = drained + toDrain;
        end

        if drained > 0 then
            if not silent then
                game.print({"", "[Twitch] ", name, " drained the power network..."}, {1, 0, 0, 1});
            end
            rcon.print("worked");
        else
            rcon.print("failed|There's no power to drain!");
        end
    end,

    fill_accumulators = function (name, amount, silent)
        local filled = 0;
        local accumulators = game.surfaces.nauvis.find_entities_filtered{type="accumulator"};

        for i = 1, #accumulators do
            local accumulator = accumulators[i];
            local old = accumulator.energy;
            accumulator.energy = accumulator.energy + (amount - filled);
            local delta = accumulator.energy - old;
            filled = filled + delta;
        end

        if filled > 0 then
            if not silent then
                game.print({"", "[Twitch] ", name, " charged the power network..."}, {0.2, 0.8, 0.2, 1});
            end
            rcon.print("worked");
        else
            rcon.print("failed|The network is already fully charged!");
        end
    end,

    spawn_enemies = function (name, targetName, amountOfBases, amountOfEnemies, silent)
        local planted = false;
        local targetPlayer = get_target_player_from_name(targetName)
        local baseSize = amountOfBases * 1.75
        local distanceToPlayer = baseSize + 30 + math.random(70)
        local angle = math.random() * math.pi * 2;
        local amountOfWorms = amountOfBases * 0.75
        local baseNames = {"biter-spawner", "spitter-spawner"}
        local enemyNames = {
            "behemoth-biter",
            "behemoth-spitter",
            "big-biter",
            "big-spitter",
            "medium-biter",
            "medium-spitter",
            "small-biter",
            "small-spitter"
        }
        local wormNames = {
            "behemoth-worm-turret",
            "big-worm-turret",
            "medium-worm-turret",
            "small-worm-turret",
        }

        if targetPlayer then
            local centerX = targetPlayer.position.x + math.cos(angle) * distanceToPlayer;
            local centerY = targetPlayer.position.y + math.sin(angle) * distanceToPlayer;
            local anglePerBase = (math.pi * 2) / tonumber(amountOfBases);
            local anglePerWorm = (math.pi * 2) / tonumber(amountOfWorms);

            for i = 1, tonumber(amountOfBases) do
                local targetX = centerX + math.cos((i - 1) * anglePerBase) * baseSize;
                local targetY = centerY + math.sin((i - 1) * anglePerBase) * baseSize;
                local entityType = baseNames[math.random(#baseNames)]
                local createdEntity = game.surfaces.nauvis.create_entity({name=entityType, amount=1, position={targetX, targetY}});
                if createdEntity then
                    planted = true;
                end
            end

            for i = 1, tonumber(amountOfWorms) do
                local targetX = centerX + math.cos((i - 1) * anglePerWorm) * (baseSize * 1.5);
                local targetY = centerY + math.sin((i - 1) * anglePerWorm) * (baseSize * 1.5);
                local entityType = wormNames[math.random(#wormNames)]
                local createdEntity = game.surfaces.nauvis.create_entity({name=entityType, amount=1, position={targetX, targetY}});
                if createdEntity then
                    planted = true;
                end
            end

            for i = 1, tonumber(amountOfEnemies) do
                local targetX = centerX + math.random(-baseSize, baseSize);
                local targetY = centerY + math.random(-baseSize, baseSize);
                local entityType = enemyNames[math.random(#enemyNames)]
                local createdEntity = game.surfaces.nauvis.create_entity({name=entityType, amount=1, position={targetX, targetY}});
                if createdEntity then
                    planted = true;
                end
            end

            if planted then
                if not silent then
                    targetPlayer.force.print({"", "[Twitch] ", name, " found some new friends near ", targetPlayer.name, ". Awwww, feel the love!"}, {0.8, 0.2, 0.2, 1});
                end
                rcon.print("worked");
                return;
            else
                rcon.print("failed|Unable to create enemies here");
                return;
            end
        end
        rcon.print("failed|Unable to find player by that name");
        return;
    end,

    modify_run_speed = function (name, target_player_name, modifier_change, lower_limit, upper_limit, buff_length)
        local target_player = get_target_player_from_name(target_player_name)
        lower_limit = lower_limit or -0.5
        upper_limit = upper_limit or 2
        buff_length = buff_length or 10
        modifier_change = tonumber(modifier_change)

        if target_player and target_player.character ~= nil then
            local current_speed_modifier = target_player.character["character_running_speed_modifier"]
            local resultant_speed_modifier = current_speed_modifier + modifier_change

            local limits_reached = false
            if resultant_speed_modifier < lower_limit then
                resultant_speed_modifier = lower_limit
                if current_speed_modifier == lower_limit then
                    limits_reached = true
                end
            elseif resultant_speed_modifier > upper_limit then
                resultant_speed_modifier = upper_limit
                if current_speed_modifier == upper_limit then
                    limits_reached = true
                end
            end

            if limits_reached then
                rcon.print("failed|Player at speed threshold already")
                return
            else
                if global.player_buffs == nil then
                    global.player_buffs = {}
                end
                if global.player_buffs[target_player.index] == nil then
                    global.player_buffs[target_player.index] = {}
                end

                local current_buff_state = global.player_buffs[target_player.index]["character_running_speed_modifier"]
                if current_buff_state == nil then
                    current_buff_state = {}
                end

                current_buff_state["default"] = 0

                if current_buff_state["remaining_seconds"] ~= nil then
                    current_buff_state["remaining_seconds"] = current_buff_state["remaining_seconds"] + buff_length
                else
                    current_buff_state["remaining_seconds"] = buff_length
                end

                global.player_buffs[target_player.index]["character_running_speed_modifier"] = current_buff_state
                target_player.character["character_running_speed_modifier"] = resultant_speed_modifier

                if modifier_change > 0 then
                    target_player.force.print({"", "[Twitch] ", name, " Buffed ", target_player.name, "'s run speed"}, {0, 1, 0, 1})
                else
                    target_player.force.print({"", "[Twitch] ", name, " Nerfed ", target_player.name, "'s run speed"}, {1, 0, 0, 1})
                end
            end
        else
            rcon.print("failed|Unable to find player by that name")
            return
        end
        rcon.print("worked")
        return
    end,

    drop_meteor = function (name, targetName, count, range)
        local target_player = get_target_player_from_name(targetName)
        if target_player then
            remote.call("space-exploration", "begin_meteor_shower", {target_entity = target_player, meteors = count, range = range})
            target_player.force.print({"", "[Twitch] ", name, " spawned a meteor (or a few...) on top of ", target_player.name, ". Awwww, feel the love!"}, {0.8, 0.2, 0.2, 1});
            rcon.print("worked")
            return;
        end
        rcon.print("failed|Unable to find player by that name");
        return;
    end,
    
});
