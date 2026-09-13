local Common = require("moves.common")

local Enemies = {}

Enemies.list = {
    {
        id = "grunt", name = "Zu-Gurongi",
        introLine = "The Zu-Gurongi bares its fangs, hungry for the Gegeru!",
        baseAttack = 16, baseDefense = 16, baseSpeed = 16, baseMaxHP = 40,
        moves = { Common.Punch, Common.Kick, Common.Guard },
        color = { 0.6, 0.6, 0.65 },
        sprite = { "(o)", "/=\\" },
    },
    {
        id = "swift_lurker", name = "Me-Gurongi",
        introLine = "The Me-Gurongi darts closer, too fast to track!",
        baseAttack = 14, baseDefense = 10, baseSpeed = 30, baseMaxHP = 34,
        moves = { Common.Punch, Common.Kick },
        color = { 0.3, 0.85, 0.9 },
        sprite = { "<o>", " V " },
    },
    {
        id = "iron_guardian", name = "Go-Gurongi",
        introLine = "The Go-Gurongi's hide gleams like ancient stone!",
        baseAttack = 14, baseDefense = 30, baseSpeed = 8, baseMaxHP = 55,
        moves = { Common.Punch, Common.Guard, Common.HeavyStrike },
        color = { 0.55, 0.55, 0.75 },
        sprite = { "[#]", "[X]" },
    },
    {
        id = "brute", name = "Ba-Gurongi",
        introLine = "The Ba-Gurongi roars, eager to begin the game!",
        baseAttack = 26, baseDefense = 14, baseSpeed = 12, baseMaxHP = 45,
        moves = { Common.HeavyStrike, Common.Punch },
        color = { 0.85, 0.4, 0.2 },
        sprite = { "\\O/", "/ \\" },
    },
    {
        id = "toxic_crawler", name = "Ra-Gurongi",
        introLine = "The Ra-Gurongi's grip drips with a strange venom!",
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

-- bosses are never picked by Enemies.random - only triggered deliberately
-- (e.g. a world landmark), by id
Enemies.BOSSES = {
    n_daguva_zeba = {
        id = "n_daguva_zeba", name = "N-Daguva-Zeba",
        introLine = "The first Gurongi. The one the ancient Kuuga could barely seal.",
        baseAttack = 30, baseDefense = 25, baseSpeed = 18, baseMaxHP = 90,
        moves = { Common.HeavyStrike, Common.Punch, Common.Guard },
        color = { 0.7, 0.1, 0.15 },
        sprite = { "\\|/", "(X)", "/|\\" },
    },
}

local function buildOpts(template, level)
    return {
        id = template.id,
        name = template.name,
        introLine = template.introLine,
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

function Enemies.random(level)
    local template = Enemies.list[math.random(#Enemies.list)]
    return buildOpts(template, level)
end

function Enemies.byId(id, level)
    local template = Enemies.BOSSES[id]
    if not template then return nil end
    return buildOpts(template, level)
end

return Enemies
