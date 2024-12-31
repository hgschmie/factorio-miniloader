local entities = require 'prototypes.entities'
local items = require 'prototypes.items'

require 'prototypes.recipes'
require 'prototypes.technologies'

local function create_miniloader(prefix, next_prefix, tint, base_underground_name)
    base_underground_name = base_underground_name or (prefix .. 'underground-belt')
    entities.create_loaders(prefix, base_underground_name, tint)
    entities.create_inserters(prefix, next_prefix, base_underground_name, tint)
    items.create_items(prefix, base_underground_name, tint)
end

create_miniloader('', 'fast-', util.color('ffc340D1'))
create_miniloader('fast-', 'express-', util.color('e31717D1'))
create_miniloader('express-', nil, util.color('43c0faD1'))

-- chute
if settings.startup['miniloader-enable-chute'].value then
    create_miniloader('chute-', '', nil, 'underground-belt')
    data.raw['loader-1x1']['chute-miniloader-loader'].speed = data.raw['loader-1x1']['chute-miniloader-loader'].speed / 4
    local inserter = data.raw.inserter['chute-miniloader-inserter']
    inserter.localised_description[5] = tostring(math.floor(data.raw['loader-1x1']['chute-miniloader-loader'].speed * 480 * 100 + 0.5) / 100)
    inserter.rotation_speed = data.raw.inserter['chute-miniloader-inserter'].rotation_speed / 4
    inserter.energy_source = { type = 'void' }
    inserter.energy_per_movement = '.0000001J'
    inserter.energy_per_rotation = '.0000001J'
    inserter.circuit_wire_max_distance = 0
    if not data.raw.inserter[inserter.next_upgrade] then
        inserter.next_upgrade = nil
    end
end
