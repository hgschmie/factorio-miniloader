---@meta

local util = require('util')

local chute_enabled = settings.startup['miniloader-enable-chute'].value or false
local filter_enabled = settings.startup['miniloader-enable-filter'].value or false

local technologies = {
    {
        type = 'technology',
        name = 'miniloader',
        icons = {
            {
                icon = '__miniloader__/graphics/technology/technology-base.png',
                icon_size = 128,
            },
            {
                icon = '__miniloader__/graphics/technology/technology-mask.png',
                icon_size = 128,
                tint = util.color('ffc340D1'),
            },
        },
        prerequisites = { 'logistics', 'steel-processing', 'electronics' },
        effects = {
            {
                type = 'unlock-recipe',
                recipe = 'miniloader',
            }
        }
    },
    {
        type = 'technology',
        name = 'fast-miniloader',
        icons = {
            {
                icon = '__miniloader__/graphics/technology/technology-base.png',
                icon_size = 128,
            },
            {
                icon = '__miniloader__/graphics/technology/technology-mask.png',
                icon_size = 128,
                tint = util.color('e31717D1'),
            },
        },
        prerequisites = { 'logistics-2', 'miniloader', },
        effects = {
            {
                type = 'unlock-recipe',
                recipe = 'fast-miniloader',
            }
        }
    },
    {
        type = 'technology',
        name = 'express-miniloader',
        icons = {
            {
                icon = '__miniloader__/graphics/technology/technology-base.png',
                icon_size = 128,
            },
            {
                icon = '__miniloader__/graphics/technology/technology-mask.png',
                icon_size = 128,
                tint = util.color('43c0faD1'),
            },
        },
        prerequisites = { 'logistics-3', 'fast-miniloader', },
        effects = {
            {
                type = 'unlock-recipe',
                recipe = 'express-miniloader',
            }
        },
    },
}

if chute_enabled then
    table.insert(technologies, {
        type = 'technology',
        name = 'basic-miniloader',
        icons = {
            {
                icon = '__miniloader__/graphics/technology/technology-base.png',
                icon_size = 128,
            },
            {
                icon = '__miniloader__/graphics/technology/technology-mask.png',
                icon_size = 128,
            },
        },
        effects = {
            {
                type = 'unlock-recipe',
                recipe = 'chute-miniloader',
            },
        },
        research_trigger = {
            type = 'craft-item',
            item = 'electronic-circuit',
            count = 10
        }
    })
end

if filter_enabled then
    table.insert(technologies[1].effects, {
        type = 'unlock-recipe',
        recipe = 'filter-miniloader',
    })
    table.insert(technologies[2].effects, {
        type = 'unlock-recipe',
        recipe = 'fast-filter-miniloader',
    })
    table.insert(technologies[3].effects, {
        type = 'unlock-recipe',
        recipe = 'express-filter-miniloader',
    })

    if chute_enabled then
        table.insert(technologies[4].effects, {
            type = 'unlock-recipe',
            recipe = 'chute-filter-miniloader',
        })
    end
end

for _, technology in pairs(technologies) do

    if not (technology.unit or technology.research_trigger) then
        local main_prereq = data.raw['technology'][technology.prerequisites[1]]
        technology.order = main_prereq.order

        if main_prereq.unit then
            technology.unit = util.copy(main_prereq.unit)
        else
            technology.research_trigger = util.copy(main_prereq.research_trigger)
        end
    end
end

data.extend(technologies)
