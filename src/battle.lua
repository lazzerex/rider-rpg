local Renderer = require("renderer")
local Button = require("ui.button")
local Party = require("party")
local Enemies = require("enemies.enemies")
local Items = require("items")

local Battle = {}

local game
local player
local enemy
local phase -- "message" | "action" | "victory" | "defeat"
local moveButtons
local runButton
local continueButton

local messageQueue
local messageIndex
local currentMessage
local onQueueDone

local resolveTurn
local buildMoveButtons

local ARENA_COL = 48
local BACKDROP_STARS = {
    "    .          *            .   ",
    "        *            .         .",
}
local BACKDROP_HILLS = "_.-''-.__.-'^^'-.__.-'--.__.-'^^-."
local ENEMY_GROUND = "________"
local PLAYER_GROUND = "______________"

local GROWTH = { attack = 2, defense = 2, speed = 1 }

local function newCombatant(opts)
    local maxHP = opts.baseMaxHP + (opts.level - 1) * 8
    return {
        id = opts.id,
        name = opts.name,
        introLine = opts.introLine,
        level = opts.level,
        forms = opts.forms,
        baseFormKey = opts.baseFormKey,
        currentFormKey = opts.baseFormKey,
        displayFormKey = opts.baseFormKey,
        moves = opts.moves,
        unlocked = opts.unlocked or {},
        color = opts.color or { 1, 1, 1 },
        sprite = opts.sprite or { "o", "|" },
        maxHP = maxHP,
        hp = opts.hp or maxHP,
        maxEnergy = 100,
        energy = 0,
        guardActive = false,
        statusEffects = {},
        flashTimer = 0,
        lungeTimer = 0,
        hpDisplay = opts.hp or maxHP,
        hpTarget = opts.hp or maxHP,
        energyDisplay = 0,
        energyTarget = 0,
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

local function combatantTint(c)
    if c.flashTimer > 0 then return { 1, 0.3, 0.3 } end
    local formData = c.forms[c.displayFormKey]
    return (formData and formData.color) or c.color
end

local function queueMsg(queue, text, onShow)
    table.insert(queue, { text = text, onShow = onShow })
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

-- Mutates real combatant state (hp/energy/form/guard/status) synchronously,
-- exactly as if the whole turn resolved instantly - this keeps cross-actor
-- interactions (e.g. actor1's Guard reducing actor2's damage) correct
-- regardless of message pacing. What's DEFERRED to onShow (fired only when
-- the player advances to that line) is purely the DISPLAY-facing state:
-- the header's shown form, the HP/energy bar targets, and the hit
-- flash/lunge - so the visuals reveal in step with the text instead of
-- jumping ahead of it.
local function applyDamage(actor, move, defender, queue)
    local hit = math.random() <= (move.accuracy or 1)

    if not hit then
        queueMsg(queue, actor.name .. "'s " .. move.name .. " missed!", function()
            actor.lungeTimer = 0.25
        end)
        return
    end

    for _ = 1, (move.hits or 1) do
        if defender.hp > 0 then
            local dmg = computeDamage(actor, move, defender)
            if defender.guardActive then
                dmg = math.floor(dmg * 0.5)
                defender.guardActive = false
            end
            defender.hp = math.max(0, defender.hp - dmg)
            local hpSnapshot = defender.hp
            queueMsg(queue, actor.name .. " used " .. move.name .. "! " .. dmg .. " damage.", function()
                actor.lungeTimer = 0.25
                defender.flashTimer = 0.15
                defender.hpTarget = hpSnapshot
            end)
        end
    end

    actor.energy = math.min(actor.maxEnergy, actor.energy + (move.energyGain or 0))

    if move.applyStatus and defender.hp > 0 then
        table.insert(defender.statusEffects, { name = move.applyStatus, turns = 2 })
        queueMsg(queue, defender.name .. " was weakened!", nil)
    end
end

local function performAction(actor, defender, moveId, queue)
    local move
    for _, m in ipairs(actor.moves) do
        if m.id == moveId then move = m end
    end
    if not move or not isMoveEnabled(actor, move) then return end

    if move.temporaryForm then
        local targetForm = move.temporaryForm
        actor.currentFormKey = targetForm
        queueMsg(queue, actor.name .. " changed to " .. actor.forms[targetForm].label .. "!", function()
            actor.displayFormKey = targetForm
            actor.lungeTimer = 0.2
        end)
    end

    if move.isGuard then
        actor.guardActive = true
        queueMsg(queue, actor.name .. " is guarding!", function()
            actor.lungeTimer = 0.2
        end)
    else
        applyDamage(actor, move, defender, queue)
        if move.isUltimate then
            actor.energy = 0
        end
    end

    if move.temporaryForm then
        actor.currentFormKey = actor.baseFormKey
        local baseLabel = actor.forms[actor.baseFormKey].label
        queueMsg(queue, actor.name .. " returned to " .. baseLabel .. "!", function()
            actor.displayFormKey = actor.baseFormKey
        end)
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

local function showMessage(index)
    local entry = messageQueue[index]
    currentMessage = entry.text
    if entry.onShow then entry.onShow() end
end

local function startQueue(queue, doneCallback)
    messageQueue = queue
    messageIndex = 1
    onQueueDone = doneCallback
    phase = "message"
    if #messageQueue > 0 then
        showMessage(1)
    else
        onQueueDone()
    end
end

local function advanceMessage()
    if messageIndex < #messageQueue then
        messageIndex = messageIndex + 1
        showMessage(messageIndex)
    else
        onQueueDone()
    end
end

local function buildContinueButton()
    continueButton = Button.new(4, 10, 20, 3, "Continue")
    continueButton.onClick = function()
        game.setState(game.STATES.WORLD)
    end
end

local function endBattle(victory)
    local activeId = game.party.active
    local instance = game.party.riders[activeId]
    instance.baseFormKey = player.baseFormKey

    local outcomeQueue = {}

    if victory then
        instance.hp = player.hp
        local xp = enemy.level * 8
        for _, m in ipairs(Party.awardExperience(game.party, activeId, xp)) do
            queueMsg(outcomeQueue, m, nil)
        end

        local roll = math.random()
        local droppedItem = (roll < 0.15 and "exp_candy") or (roll < 0.5 and "potion") or nil
        if droppedItem then
            Party.addItem(game.party, droppedItem, 1)
            queueMsg(outcomeQueue, enemy.name .. " dropped a " .. Items.DEFS[droppedItem].name .. "!", nil)
        end
    else
        queueMsg(outcomeQueue, player.name .. " was defeated and had to retreat.", nil)
        Party.heal(game.party, activeId)
    end

    game.autosave()

    startQueue(outcomeQueue, function()
        phase = victory and "victory" or "defeat"
        buildContinueButton()
    end)
end

local function runAway()
    game.setState(game.STATES.WORLD)
end

local BUTTONS_START_ROW = 7

function buildMoveButtons()
    moveButtons = {}
    local columns = { 4, 26 }

    for i, move in ipairs(player.moves) do
        local col = columns[(i - 1) % 2 + 1]
        local row = BUTTONS_START_ROW + math.floor((i - 1) / 2) * 3
        local button = Button.new(col, row, 20, 3, move.name)
        button.enabled = isMoveEnabled(player, move)
        button.onClick = function() resolveTurn(move.id) end
        table.insert(moveButtons, button)
    end

    local moveCount = #player.moves
    local lastRow = BUTTONS_START_ROW + math.floor((moveCount - 1) / 2) * 3
    if moveCount % 2 == 1 then
        -- an odd move count leaves the second column empty on the last
        -- row; put Run there instead of wasting a whole extra row on it
        runButton = Button.new(26, lastRow, 20, 3, "Run")
    else
        runButton = Button.new(4, lastRow + 3, 14, 3, "Run")
    end
    runButton.onClick = runAway
end

function resolveTurn(playerMoveId)
    if phase ~= "action" then return end

    local enemyMove = pickEnemyMove(enemy)
    local actors = { { c = player, moveId = playerMoveId }, { c = enemy, moveId = enemyMove.id } }
    table.sort(actors, function(a, b) return getStat(a.c, "speed") > getStat(b.c, "speed") end)

    local queue = {}
    for _, entry in ipairs(actors) do
        if player.hp > 0 and enemy.hp > 0 then
            local opponent = (entry.c == player) and enemy or player
            performAction(entry.c, opponent, entry.moveId, queue)
        end
    end

    tickStatus(player)
    tickStatus(enemy)

    startQueue(queue, function()
        if enemy.hp <= 0 then
            endBattle(true)
        elseif player.hp <= 0 then
            endBattle(false)
        else
            phase = "action"
            buildMoveButtons()
        end
    end)
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
        color = riderData.color, sprite = riderData.sprite,
    })

    local enemyLevel = (payload and payload.enemyLevel) or instance.level
    local enemyOpts = (payload and payload.forcedEnemyId and Enemies.byId(payload.forcedEnemyId, enemyLevel))
        or Enemies.random(enemyLevel)
    enemy = newCombatant(enemyOpts)

    local introQueue = {}
    queueMsg(introQueue, "A wild " .. enemy.name .. " appeared!", nil)
    if enemy.introLine then
        queueMsg(introQueue, enemy.introLine, nil)
    end
    queueMsg(introQueue, riderData.catchphrase or (player.name .. " is ready to fight!"), nil)

    startQueue(introQueue, function()
        phase = "action"
        buildMoveButtons()
    end)
end

function Battle.update(dt)
    local lerpRate = 3
    player.hpDisplay = player.hpDisplay + (player.hpTarget - player.hpDisplay) * math.min(1, dt * lerpRate)
    enemy.hpDisplay = enemy.hpDisplay + (enemy.hpTarget - enemy.hpDisplay) * math.min(1, dt * lerpRate)
    player.energyDisplay = player.energyDisplay + (player.energyTarget - player.energyDisplay) * math.min(1, dt * lerpRate)
    enemy.energyDisplay = enemy.energyDisplay + (enemy.energyTarget - enemy.energyDisplay) * math.min(1, dt * lerpRate)

    if player.flashTimer > 0 then player.flashTimer = player.flashTimer - dt end
    if enemy.flashTimer > 0 then enemy.flashTimer = enemy.flashTimer - dt end
    if player.lungeTimer > 0 then player.lungeTimer = player.lungeTimer - dt end
    if enemy.lungeTimer > 0 then enemy.lungeTimer = enemy.lungeTimer - dt end
end

local function drawCombatant(kind, combatant, row)
    local nameColor = combatant.flashTimer > 0 and { 1, 0.3, 0.3 } or { 1, 1, 1 }
    local formLabel = combatant.forms[combatant.displayFormKey].label
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
    Renderer.drawSprite(ARENA_COL, 0, BACKDROP_STARS, { 0.55, 0.55, 0.68 })
    Renderer.drawText(ARENA_COL, 3, BACKDROP_HILLS, { 0.32, 0.36, 0.44 })

    drawCombatant("enemy", enemy, 0)
    drawCombatant("player", player, 3)

    local enemyTint = combatantTint(enemy)
    local playerTint = combatantTint(player)
    local enemyLunge = enemy.lungeTimer > 0 and 1 or 0
    local playerLunge = player.lungeTimer > 0 and -1 or 0

    -- enemy sits farther back (upper-right) with a small, distant-looking
    -- shadow directly under its feet; player sits closer (lower-left) on a
    -- wider shadow - together this gives each combatant real ground to
    -- stand on instead of both floating in the same strip of backdrop
    Renderer.drawText(ARENA_COL + 13, 7, ENEMY_GROUND, { 0.3, 0.3, 0.32 })
    Renderer.drawSprite(ARENA_COL + 14, 5 + enemyLunge, enemy.sprite, enemyTint)

    Renderer.drawText(ARENA_COL, 13, PLAYER_GROUND, { 0.3, 0.3, 0.32 })
    Renderer.drawSprite(ARENA_COL + 3, 10 + playerLunge, player.sprite, playerTint)

    local boxRow = 20
    Renderer.drawBox(2, boxRow, 60, 7)

    if phase == "message" then
        Renderer.drawText(4, boxRow + 2, currentMessage)
        Renderer.drawText(54, boxRow + 5, "\226\150\188", { 0.8, 0.8, 0.8 })
    elseif phase == "action" then
        Renderer.drawText(4, boxRow + 2, string.format("What will %s do?", player.name))
    end

    if phase == "action" then
        for _, button in ipairs(moveButtons) do button:draw() end
        runButton:draw()
    elseif phase == "victory" then
        Renderer.drawText(4, 9, "VICTORY!", { 1, 1, 0.4 })
        continueButton:draw()
    elseif phase == "defeat" then
        Renderer.drawText(4, 9, "DEFEATED...", { 1, 0.4, 0.4 })
        continueButton:draw()
    end
end

function Battle.keypressed(key)
    if phase == "message" then
        advanceMessage()
    elseif phase == "action" then
        local index = tonumber(key)
        if index and moveButtons[index] and moveButtons[index].enabled then
            moveButtons[index].onClick()
        elseif key == "r" then
            runAway()
        end
    elseif (phase == "victory" or phase == "defeat") and continueButton then
        continueButton.onClick()
    end
end

function Battle.mousepressed(x, y, mbutton)
    local mx, my = love.mouse.getPosition()

    if phase == "message" then
        advanceMessage()
    elseif phase == "action" then
        for _, button in ipairs(moveButtons) do
            button:updateHover(mx, my)
            button:mousepressed(x, y, mbutton)
        end
        runButton:updateHover(mx, my)
        runButton:mousepressed(x, y, mbutton)
    elseif (phase == "victory" or phase == "defeat") and continueButton then
        continueButton:mousepressed(x, y, mbutton)
    end
end

return Battle
