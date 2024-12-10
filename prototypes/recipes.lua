---@meta

local chute_enabled = settings.startup['miniloader-enable-chute'].value or false
local filter_enabled = settings.startup['miniloader-enable-filter'].value or false

---@table<string, data.RecipePrototype>
local recipes = {
    {
        type = 'recipe',
        name = 'miniloader',
        ingredients = {
            { type = 'item', name = 'underground-belt', amount = 1 },
            { type = 'item', name = 'steel-plate',      amount = 8 },
            { type = 'item', name = 'inserter',         amount = 6 },
        },
        results = {
            { type = 'item', name = 'miniloader', amount = 1 },
        }
    },
    {
        type = 'recipe',
        name = 'fast-miniloader',
        ingredients = {
            { type = 'item', name = 'miniloader',            amount = 1 },
            { type = 'item', name = 'fast-underground-belt', amount = 1 },
            { type = 'item', name = 'fast-inserter',         amount = 4 },
        },
        results = {
            { type = 'item', name = 'fast-miniloader', amount = 1 },
        }
    },
    {
        type = 'recipe',
        name = 'express-miniloader',
        ingredients = {
            { type = 'item', name = 'fast-miniloader',          amount = 1 },
            { type = 'item', name = 'express-underground-belt', amount = 1 },
            { type = 'item', name = 'bulk-inserter',            amount = 2 },
        },
        results = {
            { type = 'item', name = 'express-miniloader', amount = 1 },
        }
    },
}

if chute_enabled then
    table.insert(recipes, {
        type = 'recipe',
        name = 'chute-miniloader',
        ingredients = {
            { type = 'item', name = 'iron-plate', amount = 4 },
            { type = 'item', name = 'inserter',   amount = 2 },
        },
        results = {
            { type = 'item', name = 'chute-miniloader', amount = 1 },
        }
    })
end

if filter_enabled then
    table.insert(recipes, {
        type = 'recipe',
        name = 'filter-miniloader',
        ingredients = {
            { type = 'item', name = 'underground-belt', amount = 1 },
            { type = 'item', name = 'steel-plate',      amount = 8 },
            { type = 'item', name = 'inserter',         amount = 6 },
        },
        results = {
            { type = 'item', name = 'filter-miniloader', amount = 1 },
        }
    })

    table.insert(recipes, {
        type = 'recipe',
        name = 'fast-filter-miniloader',
        ingredients = {
            { type = 'item', name = 'filter-miniloader',     amount = 1 },
            { type = 'item', name = 'fast-underground-belt', amount = 1 },
            { type = 'item', name = 'fast-inserter',         amount = 4 },
        },
        results = {
            { type = 'item', name = 'fast-filter-miniloader', amount = 1 },
        }
    })

    table.insert(recipes, {
        type = 'recipe',
        name = 'express-filter-miniloader',
        ingredients = {
            { type = 'item', name = 'fast-filter-miniloader',   amount = 1 },
            { type = 'item', name = 'express-underground-belt', amount = 1 },
            { type = 'item', name = 'bulk-inserter',            amount = 2 },
        },
        results = {
            { type = 'item', name = 'express-filter-miniloader', amount = 1 },
        }
    })

    if chute_enabled then
        table.insert(recipes, {
            type = 'recipe',
            name = 'chute-filter-miniloader',
            ingredients = {
                { type = 'item', name = 'iron-plate', amount = 4 },
                { type = 'item', name = 'inserter',   amount = 2 },
            },
            results = {
                { type = 'item', name = 'chute-filter-miniloader', amount = 1 },
            }
        })
    end
end

-- apply recipe changes due to settings
local should_double_recipes = settings.startup['miniloader-double-recipes'].value

if should_double_recipes then
    for _, recipe in pairs(recipes) do
        for _, ingredient in pairs(recipe.ingredients) do
            ingredient.amount = ingredient.amount * 2
        end
        for _, result in pairs(recipe.results) do
            result.amount = result.amount * 2
        end
    end
end

data.extend(recipes)
