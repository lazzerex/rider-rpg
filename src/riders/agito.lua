local Common = require("moves.common")

local Agito = {
    id = "agito",
    name = "Agito",
    baseForm = "ground",
    baseMaxHP = 58,
    color = { 0.95, 0.8, 0.15 },
    worldGlyph = "Ω",
    sprite = { " o ", "(V)", "/ \\" },
    progressionUnlock = {
        level = 8,
        key = "trinity",
        replacesBase = false,
        message = "Agito unlocked Trinity Form!",
    },
    forms = {
        ground = { label = "Ground Form", attack = 20, defense = 20, speed = 20 },
        storm = { label = "Storm Form", attack = 14, defense = 16, speed = 34 },
        flame = { label = "Flame Form", attack = 28, defense = 16, speed = 14 },
        trinity = { label = "Trinity Form", attack = 26, defense = 24, speed = 26 },
    },
}

Agito.moves = {
    {
        id = "ground_strike", name = "Ground Strike", type = "physical",
        power = 17, accuracy = 0.95, energyGain = 12,
        description = "Agito's balanced default attack.",
    },
    {
        id = "storm_strike", name = "Storm Strike", type = "physical",
        power = 8, accuracy = 0.97, energyGain = 12, hits = 2,
        temporaryForm = "storm",
        description = "Two rapid strikes from Storm Form.",
    },
    {
        id = "flame_strike", name = "Flame Strike", type = "physical",
        power = 24, accuracy = 0.85, energyGain = 14,
        temporaryForm = "flame",
        description = "A powerful blow from Flame Form.",
    },
    {
        id = "trinity_strike", name = "Trinity Strike", type = "physical",
        power = 22, accuracy = 0.93, energyGain = 13,
        temporaryForm = "trinity", requiresUnlock = "trinity",
        description = "A combined-combat strike from Trinity Form.",
    },
    Common.Guard,
    {
        id = "shining_kick", name = "Shining Rider Kick", type = "physical",
        power = 22, accuracy = 0.9, energyGain = 0, energyCost = 100, hits = 2,
        isUltimate = true,
        description = "Agito's two-strike ultimate finisher.",
    },
}

return Agito
