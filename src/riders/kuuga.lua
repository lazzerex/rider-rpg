local Common = require("moves.common")

local Kuuga = {
    id = "kuuga",
    name = "Kuuga",
    baseForm = "mighty",
    baseMaxHP = 60,
    color = { 0.95, 0.25, 0.2 },
    catchphrase = "Kuuga steps forward, ready to fight!",
    worldGlyph = "Ψ",
    sprite = { " o ", "(V)", "/ \\" },
    progressionUnlock = {
        level = 10,
        key = "ultimate",
        replacesBase = true,
        message = "Kuuga awakened Ultimate Kuuga!",
    },
    forms = {
        mighty = { label = "Mighty Form", attack = 22, defense = 20, speed = 20, color = { 0.95, 0.25, 0.2 } },
        dragon = { label = "Dragon Form", attack = 18, defense = 14, speed = 32, color = { 0.25, 0.45, 0.95 } },
        pegasus = { label = "Pegasus Form", attack = 14, defense = 16, speed = 22, color = { 0.95, 0.85, 0.2 } },
        titan = { label = "Titan Form", attack = 26, defense = 32, speed = 10, color = { 0.6, 0.3, 0.85 } },
        ultimate = { label = "Ultimate Kuuga", attack = 34, defense = 30, speed = 28, color = { 0.95, 0.75, 0.2 } },
    },
}

Kuuga.moves = {
    {
        id = "mighty_punch", name = "Mighty Punch", type = "physical",
        power = 9, accuracy = 0.98, energyGain = 9,
        description = "A quick, reliable jab. Weaker than Kuuga's other strikes.",
    },
    {
        id = "mighty_strike", name = "Mighty Strike", type = "physical",
        power = 16, accuracy = 0.95, energyGain = 12,
        description = "Kuuga's reliable general purpose strike.",
    },
    {
        id = "dragon_strike", name = "Dragon Strike", type = "physical",
        power = 15, accuracy = 0.97, energyGain = 12,
        temporaryForm = "dragon",
        description = "A swift staff strike from Dragon Form.",
    },
    {
        id = "pegasus_shot", name = "Pegasus Shot", type = "ranged",
        power = 14, accuracy = 0.99, energyGain = 12,
        temporaryForm = "pegasus",
        description = "A precise ranged shot from Pegasus Form.",
    },
    {
        id = "titan_strike", name = "Titan Strike", type = "physical",
        power = 22, accuracy = 0.85, energyGain = 14,
        temporaryForm = "titan",
        description = "A heavy blow from the defensive Titan Form.",
    },
    Common.Guard,
    {
        id = "rider_kick", name = "Rider Kick", type = "physical",
        power = 40, accuracy = 0.9, energyGain = 0, energyCost = 100,
        isUltimate = true,
        description = "Kuuga's ultimate finishing kick.",
    },
}

return Kuuga
