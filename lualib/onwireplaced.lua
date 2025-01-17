--[[
  Wires can be placed in the following ways:

  1) player clicks with a green-wire or red-wire
  2) construction robot revives a ghost
  3) a mod script (e.g. Nanobots) revives a ghost
  4) a player clicks with a blueprint over an existing entity

  Relevant events:
  on_selected_entity_changed: before 1
  on_player_cursor_stack_changed: after 1
  on_robot_built_entity: 2
  on_built_entity: 3
  on_pre_build: 4
  on_tick: after 4
]]

local M = {}

local blueprint = require 'lualib.blueprint'
local event = require 'lualib.event'
local util = require 'lualib.util'

M.on_wire_added = script.generate_event_name()
M.on_wire_removed = script.generate_event_name()

-- how often to poll circuit network connections when the player is holding wire over an entity
local POLL_INTERVAL = 15

local monitored_players

--[[
  CCD === CircuitConnectionDefinition

  selected_ccd_set_for[player_index] = {
    [ccd_key] = {
      wire = ...,
      target_entity = ...,
      source_circuit_id = ...,
      target_circuit_id = ...
    },
    ...
  }
]]
local selected_ccd_set_for

local function ccd_key(ccd)
    --do return ccd.wire.."-"..ccd.source_circuit_id.."-"..ccd.target_circuit_id.."-"..ccd.target_entity.unit_number end
    return bit32.band(ccd.wire, 15)
        + bit32.lshift(bit32.band(ccd.source_circuit_id - 1, 15), 4)
        + bit32.lshift(bit32.band(ccd.target_circuit_id - 1, 15), 8)
        + bit32.lshift(ccd.target_entity.unit_number, 12)
end

local function ccd_set(entity)
    local ccds = {}
    if entity and entity.valid then
        for _, color in pairs { 'red', 'green' } do
            local wire_connector = entity.get_wire_connector(defines.wire_connector_id['circuit_' .. color], false)
            if wire_connector and wire_connector.connection_count > 0 then
                for _, wire_connection in pairs(wire_connector.connections) do
                    local ccd = {
                        wire = defines.wire_type[color],
                        target_entity = wire_connection.target.owner,
                        source_circuit_id = wire_connector.wire_connector_id,
                        target_circuit_id = wire_connection.target.wire_connector_id,
                    }
                    table.insert(ccds, ccd)
                end
            end
        end
    end

    if not ccds then
        return {}
    end

    local out = {}
    for i = 1, #ccds do
        out[ccd_key(ccds[i])] = ccds[i]
    end
    return out
end

local function diff_sets(old, new)
    local removed = {}
    for old_key, ccd in pairs(old) do
        if not new[old_key] then
            removed[#removed + 1] = ccd
        end
    end

    local added = {}
    for new_key, ccd in pairs(new) do
        if not old[new_key] then
            added[#added + 1] = ccd
        end
    end
    return removed, added
end

local function raise_on_wire_added(entity, ccd)
    local ev = {
        entity = entity,
        wire = ccd.wire,
        target_entity = ccd.target_entity,
        source_circuit_id = ccd.source_circuit_id,
        target_circuit_id = ccd.target_circuit_id,
    }
    script.raise_event(M.on_wire_added, ev)
end

local function raise_on_wire_removed(entity, ccd)
    local ev = {
        entity = entity,
        wire = ccd.wire,
        target_entity = ccd.target_entity,
        source_circuit_id = ccd.source_circuit_id,
        target_circuit_id = ccd.target_circuit_id,
    }
    script.raise_event(M.on_wire_removed, ev)
end

local function check_for_circuit_changes(entity, old, new)
    if not old or not new then
        return
    end

    local removed, added = diff_sets(old, new)
    for _, ccd in ipairs(removed) do
        raise_on_wire_removed(entity, ccd)
    end
    for _, ccd in ipairs(added) do
        raise_on_wire_added(entity, ccd)
    end
end

local function check_selection_for_player(player_index)
    local selected = game.players[player_index].selected
    if selected and selected.valid then
        local new = ccd_set(selected)
        check_for_circuit_changes(selected, selected_ccd_set_for[player_index], new)
        selected_ccd_set_for[player_index] = new
    end
end

local function check_selection_for_all(ev)
    if ev.tick % POLL_INTERVAL ~= 0 then
        return
    end

    -- check only players who we believe to have a selected entity
    for player_index in pairs(selected_ccd_set_for) do
        check_selection_for_player(player_index)
    end
end

local function start_monitoring_selected_entity(player_index)
    local selected = game.players[player_index].selected
    if selected then
        selected_ccd_set_for[player_index] = ccd_set(selected)
        event.register(defines.events.on_tick, check_selection_for_all)
        return
    end
    selected_ccd_set_for[player_index] = nil
    if not next(selected_ccd_set_for) then
        event.unregister(defines.events.on_tick, check_selection_for_all)
    end
end

local function on_selected_entity_changed(ev)
    local player_index = ev.player_index
    if not monitored_players[player_index] then
        return
    end

    if ev.last_entity then
        local new = ccd_set(ev.last_entity)
        check_for_circuit_changes(ev.last_entity, selected_ccd_set_for[player_index], new)
    end

    start_monitoring_selected_entity(player_index)
end

local function stop_monitoring_player_selection(player_index)
    -- one last check since we will no longer be monitoring this player's selection
    check_selection_for_player(player_index)

    monitored_players[player_index] = nil
    if not next(monitored_players) then
        event.unregister(defines.events.on_selected_entity_changed, on_selected_entity_changed)
    end

    selected_ccd_set_for[player_index] = nil
    if not next(selected_ccd_set_for) then
        event.unregister(defines.events.on_tick, check_selection_for_all)
    end
end

local function start_monitoring_player_selection(player_index)
    monitored_players[player_index] = true
    start_monitoring_selected_entity(player_index)
    event.register(defines.events.on_selected_entity_changed, on_selected_entity_changed)
end

local function on_player_cursor_stack_changed(ev)
    local player_index = ev.player_index
    local cursor_stack = game.players[player_index].cursor_stack
    if cursor_stack and cursor_stack.valid_for_read then
        local name = cursor_stack.name
        if name == 'red-wire' or name == 'green-wire' then
            if monitored_players[player_index] then
                -- already monitoring, probably placed a wire
                check_selection_for_player(player_index)
            else
                start_monitoring_player_selection(player_index)
            end
            return
        end
    end
    stop_monitoring_player_selection(player_index)
end

local function on_built_entity(ev)
    local entity = ev.entity or ev.destination
    if not entity.valid then return end

    for _, color in pairs { 'red', 'green' } do
        local wire_connector = entity.get_wire_connector(defines.wire_connector_id['circuit_' .. color], false)
        if wire_connector and wire_connector.connection_count > 0 then
            for _, wire_connection in pairs(wire_connector.connections) do
                local ccd = {
                    wire = defines.wire_type[color],
                    target_entity = wire_connection.target.owner,
                    source_circuit_id = wire_connector.wire_connector_id,
                    target_circuit_id = wire_connection.target.wire_connector_id,
                }

                raise_on_wire_added(entity, ccd)
            end
        end
    end
end

local function on_entity_mined(ev)
    local entity = ev.entity
    if not entity.valid then return end

    for _, color in pairs { 'red', 'green' } do
        local wire_connector = entity.get_wire_connector(defines.wire_connector_id['circuit_' .. color], false)
        if wire_connector and wire_connector.connection_count > 0 then
            for _, wire_connection in pairs(wire_connector.connections) do
                local ccd = {
                    wire = defines.wire_type[color],
                    target_entity = wire_connection.target.owner,
                    source_circuit_id = wire_connector.wire_connector_id,
                    target_circuit_id = wire_connection.target.wire_connector_id,
                }
    
                raise_on_wire_removed(entity, ccd)
            end
        end
    end
end

local bp_overplace

local function check_after_blueprint_placed()
    for unit_number, data in pairs(bp_overplace) do
        local entity = data.entity
        -- any of the entities may have become invalid due to other scripting
        if entity.valid then
            local new = ccd_set(entity)
            check_for_circuit_changes(entity, data.before_ccd_set, new)
        end
        bp_overplace[unit_number] = nil
    end

    event.unregister(defines.events.on_tick, check_after_blueprint_placed)
end

local function setup_after_blueprint_placed(preexisting_entities)
    for i = 1, #preexisting_entities do
        local entity = preexisting_entities[i]
        if entity.unit_number then
            bp_overplace[entity.unit_number] = {
                entity = entity,
                before_ccd_set = ccd_set(entity),
            }
        end
    end

    event.register(defines.events.on_tick, check_after_blueprint_placed)
end

local function on_pre_build(ev)
    local player = game.players[ev.player_index]
    if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint' then
        local bp_entities = player.cursor_stack.get_blueprint_entities()
        if not bp_entities or not next(bp_entities) then return end
        local bp_area = blueprint.bounding_box(bp_entities)
        local surface_area = util.expand_box(
            util.move_box(
                util.rotate_box(bp_area, ev.direction),
                ev.position
            ),
            1
        )
        local preexisting_entities = player.surface.find_entities(surface_area)
        -- check again at the end of this tick, after blueprint has been placed
        setup_after_blueprint_placed(preexisting_entities)
    end
end

function M.on_init()
    storage.onwireplaced = {
        monitored_players = {},
        selected_ccd_set_for = {},
        bp_overplace = {},
    }
    M.on_load()
end

function M.on_load()
    if not storage.onwireplaced then
        return -- expect on_configuration_changed to be called
    end

    if storage.onwireplaced.monitored_players then
        monitored_players = storage.onwireplaced.monitored_players
        if next(monitored_players) then
            event.register(defines.events.on_selected_entity_changed, on_selected_entity_changed)
        end
    end

    if storage.onwireplaced.selected_ccd_set_for then
        selected_ccd_set_for = storage.onwireplaced.selected_ccd_set_for
        if next(selected_ccd_set_for) then
            event.register(defines.events.on_tick, check_selection_for_all)
        end
    end

    if storage.onwireplaced.bp_overplace then
        bp_overplace = storage.onwireplaced.bp_overplace
        if next(bp_overplace) then
            event.register(defines.events.on_tick, check_after_blueprint_placed)
        end
    end

    event.register(defines.events.on_player_cursor_stack_changed, on_player_cursor_stack_changed)
    event.register(
        {
            defines.events.on_built_entity,
            defines.events.on_entity_cloned,
            defines.events.on_robot_built_entity,
            defines.events.script_raised_built,
            defines.events.script_raised_revive,
        },
        on_built_entity
    )
    event.register(
        {
            defines.events.on_entity_died,
            defines.events.on_player_mined_entity,
            defines.events.on_robot_mined_entity,
            defines.events.script_raised_destroy,
        },
        on_entity_mined
    )
    event.register(defines.events.on_pre_build, on_pre_build)
end

function M.on_configuration_changed()
    if not storage.onwireplaced then
        storage.onwireplaced = {
            monitored_players = storage.monitored_players or {},
            selected_ccd_set_for = storage.selected_ccd_set_for or {},
            bp_overplace = {},
        }
        storage.monitored_players = nil
        storage.selected_ccd_set_for = nil
    end
    M.on_load()
end

return M
