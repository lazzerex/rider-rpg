local Kuuga = require("riders.kuuga")
local Agito = require("riders.agito")

local Party = {}

local RIDER_DATA = { kuuga = Kuuga, agito = Agito }

local function xpToNext(level)
    return level * 20
end

local function newRiderInstance(id)
    return {
        id = id,
        level = 1,
        xp = 0,
        baseFormKey = RIDER_DATA[id].baseForm,
        hp = RIDER_DATA[id].baseMaxHP,
        unlocked = {},
    }
end

function Party.newGame()
    return {
        active = "kuuga",
        bench = { "agito" },
        riders = {
            kuuga = newRiderInstance("kuuga"),
            agito = newRiderInstance("agito"),
        },
        flags = {},
    }
end

function Party.getData(id)
    return RIDER_DATA[id]
end

function Party.getMaxHP(instance)
    return RIDER_DATA[instance.id].baseMaxHP + (instance.level - 1) * 8
end

local function applyLevelUp(instance)
    local data = RIDER_DATA[instance.id]
    instance.hp = Party.getMaxHP(instance)

    local messages = {}
    local unlock = data.progressionUnlock
    if unlock and instance.level >= unlock.level and not instance.unlocked[unlock.key] then
        instance.unlocked[unlock.key] = true
        if unlock.replacesBase then
            instance.baseFormKey = unlock.key
        end
        table.insert(messages, unlock.message)
    end
    return messages
end

function Party.awardExperience(party, id, xp)
    local instance = party.riders[id]
    local messages = {}

    instance.xp = instance.xp + xp
    table.insert(messages, string.format("%s gained %d experience!", RIDER_DATA[id].name, xp))

    while instance.xp >= xpToNext(instance.level) do
        instance.xp = instance.xp - xpToNext(instance.level)
        instance.level = instance.level + 1
        table.insert(messages, string.format("%s grew to level %d!", RIDER_DATA[id].name, instance.level))

        for _, m in ipairs(applyLevelUp(instance)) do
            table.insert(messages, m)
        end
    end

    return messages
end

function Party.heal(party, id)
    local instance = party.riders[id]
    instance.hp = Party.getMaxHP(instance)
end

function Party.healAll(party)
    for id in pairs(party.riders) do
        Party.heal(party, id)
    end
end

function Party.setActive(party, id)
    if not party.riders[id] or id == party.active then
        return false
    end

    for i, benchId in ipairs(party.bench) do
        if benchId == id then
            table.remove(party.bench, i)
            table.insert(party.bench, party.active)
            party.active = id
            return true
        end
    end

    return false
end

return Party
