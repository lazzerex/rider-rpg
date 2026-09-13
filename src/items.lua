local Items = {}

Items.ORDER = { "potion", "exp_candy" }

Items.DEFS = {
    potion = {
        name = "Potion", description = "Restores 20 HP.", heal = 20,
    },
    exp_candy = {
        name = "EXP Candy", description = "Grants 15 experience.", xp = 15,
    },
}

return Items
