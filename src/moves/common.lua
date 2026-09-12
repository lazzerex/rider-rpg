local Common = {}

Common.Punch = {
    id = "punch", name = "Punch", type = "physical",
    power = 10, accuracy = 0.95, energyGain = 10,
    description = "A basic physical strike.",
}

Common.Kick = {
    id = "kick", name = "Kick", type = "physical",
    power = 13, accuracy = 0.9, energyGain = 11,
    description = "A stronger physical strike.",
}

Common.HeavyStrike = {
    id = "heavy_strike", name = "Heavy Strike", type = "physical",
    power = 20, accuracy = 0.8, energyGain = 14,
    description = "A slow but powerful strike.",
}

Common.Guard = {
    id = "guard", name = "Guard", type = "defense",
    power = 0, accuracy = 1, energyGain = 0,
    isGuard = true,
    description = "Braces to halve the next hit taken.",
}

return Common
