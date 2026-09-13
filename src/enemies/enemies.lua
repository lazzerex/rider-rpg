local Common = require("moves.common")

local Enemies = {}

Enemies.list = {
    {
        id = "grunt", name = "Grunt Monster",
        baseAttack = 16, baseDefense = 16, baseSpeed = 16, baseMaxHP = 40,
        moves = { Common.Punch, Common.Kick, Common.Guard },
        color = { 0.6, 0.6, 0.65 },
        sprite = { "(o)", "/=\\" },
    },
    {
        id = "swift_lurker", name = "Swift Lurker",
        baseAttack = 14, baseDefense = 10, baseSpeed = 30, baseMaxHP = 34,
        moves = { Common.Punch, Common.Kick },
        color = { 0.3, 0.85, 0.9 },
        sprite = { "<o>", " V " },
    },
    {
        id = "iron_guardian", name = "Iron Guardian",
        baseAttack = 14, baseDefense = 30, baseSpeed = 8, baseMaxHP = 55,
        moves = { Common.Punch, Common.Guard, Common.HeavyStrike },
        color = { 0.55, 0.55, 0.75 },
        sprite = { "[#]", "[X]" },
    },
    {
        id = "brute", name = "Brute",
        baseAttack = 26, baseDefense = 14, baseSpeed = 12, baseMaxHP = 45,
        moves = { Common.HeavyStrike, Common.Punch },
        color = { 0.85, 0.4, 0.2 },
        sprite = { "\\O/", "/ \\" },
    },
    {
        id = "toxic_crawler", name = "Toxic Crawler",
        baseAttack = 12, baseDefense = 14, baseSpeed = 18, baseMaxHP = 38,
        moves = {
            Common.Punch,
            {
                id = "corrosive_grip", name = "Corrosive Grip", type = "status",
                power = 8, accuracy = 0.9, energyGain = 8,
                applyStatus = "weaken",
                description = "A draining grip that weakens the target's attack.",
            },
        },
        color = { 0.5, 0.85, 0.3 },
        sprite = { "~o~", "vvv" },
    },
}

function Enemies.random(level)
    local template = Enemies.list[math.random(#Enemies.list)]
    return {
        id = template.id,
        name = template.name,
        level = level,
        forms = { base = { label = "", attack = template.baseAttack, defense = template.baseDefense, speed = template.baseSpeed } },
        baseFormKey = "base",
        baseMaxHP = template.baseMaxHP,
        moves = template.moves,
        color = template.color,
        sprite = template.sprite,
        unlocked = {},
    }
end

return Enemies
