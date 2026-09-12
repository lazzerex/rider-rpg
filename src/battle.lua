local Renderer = require("renderer")
local Button = require("ui.button")
local Party = require("party")
local Enemies = require("enemies.enemies")

local Battle = {}

local game
local player
local enemy
local log
local phase -- "action" | "victory" | "defeat"
local moveButtons
local runButton
local continueButton

local resolveTurn
local buildMoveButtons

local GROWTH = { attack = 2, defense = 2, speed = 1 }

local function newCombatant(opts)
    local maxHP = opts.baseMaxHP + (opts.level - 1) * 8
    return {
        id = opts.id,
        name = opts.name,
        level = opts.level,
        forms = opts.forms,
        baseFormKey = opts.baseFormKey,
        currentFormKey = opts.baseFormKey,
        moves = opts.moves,
        unlocked = opts.unlocked or {},
        maxHP = maxHP,
        hp = opts.hp or maxHP,
        maxEnergy = 100,
        energy = 0,
        guardActive = false,
        statusEffects = {},
        flashTimer = 0,
        hpDisplay = opts.hp or maxHP,
        energyDisplay = 0,
    }
end

local function getStat(c, stat)
    local value = c.forms[c.currentFormKey][stat] + (c.level - 1) * GROWTH[stat]
    if stat == "attack" then
        for _, status in ipairs(c.statusEffects) do
            if status.name == "weaken" then
                value = value * 0.7
            end
        end
    end
    return value
end

local function addLog(message)
    table.insert(log, message)
    if #log > 5 then
        table.remove(log, 1)
    end
end

local function computeDamage(attacker, move, defender)
    local base = (getStat(attacker, "attack") * move.power) / (getStat(defender, "defense") + 10)
    local variance = 0.9 + math.random() * 0.2
    return math.max(1, math.floor(base * variance))
end

local function isMoveEnabled(combatant, move)
    if move.requiresUnlock and not combatant.unlocked[move.requiresUnlock] then
        return false
    end
    if move.isUltimate and combatant.energy < combatant.maxEnergy then
        return false
    end
    return true
end

local function applyDamage(attacker, move, defender)
    local hit = math.random() <= (move.accuracy or 1)

    if not hit then
        addLog(attacker.name .. "'s " .. move.name .. " missed!")
        return
    end

    for _ = 1, (move.hits or 1) do
        if defender.hp > 0 then
            local dmg = computeDamage(attacker, move, defender)
            if defender.guardActive then
                dmg = math.floor(dmg * 0.5)
                defender.guardActive = false
            end
            defender.hp = math.max(0, defender.hp - dmg)
            defender.flashTimer = 0.15
            addLog(attacker.name .. " used " .. move.name .. "! " .. dmg .. " damage.")
        end
    end

    attacker.energy = math.min(attacker.maxEnergy, attacker.energy + (move.energyGain or 0))

    if move.applyStatus and defender.hp > 0 then
        table.insert(defender.statusEffects, { name = move.applyStatus, turns = 2 })
        addLog(defender.name .. " was weakened!")
    end
end

local function performAction(actor, defender, moveId)
    local move
    for _, m in ipairs(actor.moves) do
        if m.id == moveId then move = m end
    end
    if not move or not isMoveEnabled(actor, move) then return end

    if move.temporaryForm then
        actor.currentFormKey = move.temporaryForm
        addLog(actor.name .. " changed to " .. actor.forms[move.temporaryForm].label .. "!")
    end

    if move.isGuard then
        actor.guardActive = true
        addLog(actor.name .. " is guarding!")
    else
        applyDamage(actor, move, defender)
        if move.isUltimate then
            actor.energy = 0
        end
    end

    if move.temporaryForm then
        actor.currentFormKey = actor.baseFormKey
        addLog(actor.name .. " returned to " .. actor.forms[actor.baseFormKey].label .. "!")
    end
end

local function tickStatus(combatant)
    for i = #combatant.statusEffects, 1, -1 do
        combatant.statusEffects[i].turns = combatant.statusEffects[i].turns - 1
        if combatant.statusEffects[i].turns <= 0 then
            table.remove(combatant.statusEffects, i)
        end
    end
end

local function pickEnemyMove(combatant)
    local options = {}
    for _, move in ipairs(combatant.moves) do
        if isMoveEnabled(combatant, move) then
            table.insert(options, move)
        end
    end
    return options[math.random(#options)]
end

local function buildContinueButton()
    continueButton = Button.new(4, 10, 20, 2, "Continue")
    continueButton.onClick = function()
        game.setState(game.STATES.WORLD)
    end
end

local function endBattle(victory)
    phase = victory and "victory" or "defeat"

    local activeId = game.party.active
    local instance = game.party.riders[activeId]
    instance.baseFormKey = player.baseFormKey

    if victory then
        instance.hp = player.hp
        local xp = enemy.level * 8
        for _, m in ipairs(Party.awardExperience(game.party, activeId, xp)) do
            addLog(m)
        end
    else
        addLog(player.name .. " was defeated and had to retreat.")
        Party.heal(game.party, activeId)
    end

    game.autosave()
    buildContinueButton()
end

local function runAway()
    addLog(player.name .. " fled from battle!")
    game.setState(game.STATES.WORLD)
end

function buildMoveButtons()
    moveButtons = {}
    local columns = { 4, 26 }
    local startRow = 9

    for i, move in ipairs(player.moves) do
        local col = columns[(i - 1) % 2 + 1]
        local row = startRow + math.floor((i - 1) / 2) * 2
        local button = Button.new(col, row, 20, 2, move.name)
        button.enabled = isMoveEnabled(player, move)
        button.onClick = function() resolveTurn(move.id) end
        table.insert(moveButtons, button)
    end

    runButton = Button.new(4, 16, 14, 2, "Run")
    runButton.onClick = runAway
end

function resolveTurn(playerMoveId)
    if phase ~= "action" then return end

    local enemyMove = pickEnemyMove(enemy)
    local actors = { { c = player, moveId = playerMoveId }, { c = enemy, moveId = enemyMove.id } }
    table.sort(actors, function(a, b) return getStat(a.c, "speed") > getStat(b.c, "speed") end)

    for _, entry in ipairs(actors) do
        if player.hp > 0 and enemy.hp > 0 then
            local opponent = (entry.c == player) and enemy or player
            performAction(entry.c, opponent, entry.moveId)
        end
    end

    tickStatus(player)
    tickStatus(enemy)

    if enemy.hp <= 0 then
        endBattle(true)
    elseif player.hp <= 0 then
        endBattle(false)
    else
        buildMoveButtons()
    end
end

function Battle.load(gameRef)
    game = gameRef
end

function Battle.enter(payload)
    local activeId = game.party.active
    local instance = game.party.riders[activeId]
    local riderData = Party.getData(activeId)

    player = newCombatant({
        id = activeId, name = riderData.name, level = instance.level,
        forms = riderData.forms, baseFormKey = instance.baseFormKey,
        moves = riderData.moves, unlocked = instance.unlocked,
        baseMaxHP = riderData.baseMaxHP, hp = instance.hp,
    })

    local enemyLevel = (payload and payload.enemyLevel) or instance.level
    enemy = newCombatant(Enemies.random(enemyLevel))

    log = {}
    phase = "action"
    addLog(player.name .. " encountered " .. enemy.name .. "!")
    buildMoveButtons()
end

function Battle.update(dt)
    local lerpRate = 3
    player.hpDisplay = player.hpDisplay + (player.hp - player.hpDisplay) * math.min(1, dt * lerpRate)
    enemy.hpDisplay = enemy.hpDisplay + (enemy.hp - enemy.hpDisplay) * math.min(1, dt * lerpRate)
    player.energyDisplay = player.energyDisplay + (player.energy - player.energyDisplay) * math.min(1, dt * lerpRate)
    enemy.energyDisplay = enemy.energyDisplay + (enemy.energy - enemy.energyDisplay) * math.min(1, dt * lerpRate)

    if player.flashTimer > 0 then player.flashTimer = player.flashTimer - dt end
    if enemy.flashTimer > 0 then enemy.flashTimer = enemy.flashTimer - dt end
end

local function drawCombatant(kind, combatant, row)
    local nameColor = combatant.flashTimer > 0 and { 1, 0.3, 0.3 } or { 1, 1, 1 }
    local formLabel = combatant.forms[combatant.currentFormKey].label
    local formText = (formLabel and formLabel ~= "") and (" [" .. formLabel .. "]") or ""
    Renderer.drawText(4, row, string.format(
        "%s Lv.%d%s", combatant.name, combatant.level, formText), nameColor)
    Renderer.drawText(4, row + 1, "HP")
    Renderer.drawHealthBar(7, row + 1, 20, combatant.hpDisplay, combatant.maxHP)
    Renderer.drawText(28, row + 1, string.format("%d/%d", math.floor(combatant.hpDisplay), combatant.maxHP))

    if kind == "player" then
        Renderer.drawText(4, row + 2, "EN")
        Renderer.drawEnergyBar(7, row + 2, 20, combatant.energyDisplay, combatant.maxEnergy)
    end
end

function Battle.draw()
    drawCombatant("enemy", enemy, 2)
    drawCombatant("player", player, 5)

    Renderer.drawBox(2, 19, 60, 7)
    for i, line in ipairs(log) do
        Renderer.drawText(4, 19 + i, line)
    end

    if phase == "action" then
        for _, button in ipairs(moveButtons) do button:draw() end
        runButton:draw()
    elseif phase == "victory" then
        Renderer.drawText(4, 8, "VICTORY!", { 1, 1, 0.4 })
        continueButton:draw()
    elseif phase == "defeat" then
        Renderer.drawText(4, 8, "DEFEATED...", { 1, 0.4, 0.4 })
        continueButton:draw()
    end
end

function Battle.keypressed(key)
    if phase == "action" then
        local index = tonumber(key)
        if index and moveButtons[index] and moveButtons[index].enabled then
            moveButtons[index].onClick()
        elseif key == "r" then
            runAway()
        end
    elseif continueButton then
        continueButton.onClick()
    end
end

function Battle.mousepressed(x, y, mbutton)
    local mx, my = love.mouse.getPosition()

    if phase == "action" then
        for _, button in ipairs(moveButtons) do
            button:updateHover(mx, my)
            button:mousepressed(x, y, mbutton)
        end
        runButton:updateHover(mx, my)
        runButton:mousepressed(x, y, mbutton)
    elseif continueButton then
        continueButton:mousepressed(x, y, mbutton)
    end
end

return Battle
