local Renderer = require("renderer")
local Input = require("input")
local Party = require("party")

local World = {}

local game
local map
local mapWidth, mapHeight
local player
local dialogueText
local encounterCooldown = 0
local saveMessageTimer = 0
local interactables

local originCol, originRow = 2, 3

local BLOCKING = { ["#"] = true, ["T"] = true, ["B"] = true, ["N"] = true, ["S"] = true }
local ENCOUNTER_CHANCE = 0.14
local ENCOUNTER_COOLDOWN_STEPS = 6

local function buildMap()
    local width, height = 30, 16
    local grid = {}

    for row = 1, height do
        grid[row] = {}
        for col = 1, width do
            local tile = "."
            if row == 1 or row == height or col == 1 or col == width then
                tile = "#"
            end
            grid[row][col] = tile
        end
    end

    local dividerCol = 16
    for row = 2, height - 1 do
        grid[row][dividerCol] = "#"
    end

    local roadRow = 8
    for col = 2, width - 1 do
        grid[roadRow][col] = "="
    end

    for row = 2, height - 1 do
        for col = dividerCol + 1, width - 1 do
            if grid[row][col] == "." then
                grid[row][col] = ","
            end
        end
    end

    local trees = { { 4, 20 }, { 5, 25 }, { 11, 22 }, { 12, 27 } }
    for _, pos in ipairs(trees) do
        grid[pos[1]][pos[2]] = "T"
    end

    grid[4][5] = "B"
    grid[4][10] = "N"
    grid[6][8] = "S"

    return grid, width, height
end

local function tileVisual(tile)
    if tile == "#" then return "#", { 0.6, 0.6, 0.6 } end
    if tile == "," then return ",", { 0.3, 0.8, 0.3 } end
    if tile == "=" then return "=", { 0.7, 0.6, 0.4 } end
    if tile == "T" then return "T", { 0.1, 0.6, 0.1 } end
    if tile == "B" then return "B", { 0.6, 0.6, 0.9 } end
    if tile == "N" then return "N", { 0.9, 0.9, 0.3 } end
    if tile == "S" then return "S", { 0.8, 0.7, 0.5 } end
    return ".", { 0.4, 0.4, 0.4 }
end

local function isBlocked(col, row)
    if col < 1 or row < 1 or col > mapWidth or row > mapHeight then
        return true
    end
    return BLOCKING[map[row][col]] == true
end

local function findInteractable(col, row)
    for _, spot in ipairs(interactables) do
        if spot.col == col and spot.row == row then
            return spot
        end
    end
    return nil
end

function World.load(gameRef, initialPosition)
    game = gameRef
    map, mapWidth, mapHeight = buildMap()

    interactables = {
        { col = 5, row = 4, message = "Town Hall. A quiet Rider outpost." },
        { col = 10, row = 4, message = "Professor: \"Rest here and I will heal your party.\"", heal = true },
        { col = 8, row = 6, message = "Sign: \"Wild grass lies to the east. Kamen Riders await.\"" },
    }

    player = {
        col = (initialPosition and initialPosition.col) or 5,
        row = (initialPosition and initialPosition.row) or 8,
        facing = (initialPosition and initialPosition.facing) or "down",
    }
end

function World.enter() end

function World.getPosition()
    return { col = player.col, row = player.row, facing = player.facing }
end

local function facingOffset()
    if player.facing == "up" then return 0, -1 end
    if player.facing == "down" then return 0, 1 end
    if player.facing == "left" then return -1, 0 end
    return 1, 0
end

local function tryInteract()
    local dx, dy = facingOffset()
    local spot = findInteractable(player.col + dx, player.row + dy)
    if spot then
        dialogueText = spot.message
        if spot.heal then
            Party.healAll(game.party)
        end
    end
end

local function tryMove(dx, dy)
    if dx == -1 then player.facing = "left"
    elseif dx == 1 then player.facing = "right"
    elseif dy == -1 then player.facing = "up"
    elseif dy == 1 then player.facing = "down"
    end

    local newCol, newRow = player.col + dx, player.row + dy
    if isBlocked(newCol, newRow) then return end

    player.col, player.row = newCol, newRow

    if encounterCooldown > 0 then
        encounterCooldown = encounterCooldown - 1
    end

    local tile = map[player.row][player.col]
    if tile == "," and encounterCooldown <= 0 then
        if math.random() < ENCOUNTER_CHANCE then
            encounterCooldown = ENCOUNTER_COOLDOWN_STEPS
            local activeId = game.party.active
            local activeLevel = game.party.riders[activeId].level
            game.setState(game.STATES.BATTLE, { enemyLevel = activeLevel })
        end
    end
end

function World.update(dt)
    if saveMessageTimer > 0 then
        saveMessageTimer = saveMessageTimer - dt
    end
end

function World.keypressed(key)
    if dialogueText then
        dialogueText = nil
        return
    end

    if key == "escape" then
        game.setState(game.STATES.MENU)
        return
    end

    if key == "e" then
        tryInteract()
        return
    end

    if key == "f5" then
        game.autosave()
        saveMessageTimer = 1.5
        return
    end

    local dir = Input.directionForKey(key)
    if dir then
        tryMove(dir[1], dir[2])
    end
end

function World.mousepressed(x, y, button)
    if dialogueText then
        dialogueText = nil
    end
end

function World.draw()
    for row = 1, mapHeight do
        for col = 1, mapWidth do
            local char, color = tileVisual(map[row][col])
            Renderer.drawCell(originCol + col - 1, originRow + row - 1, char, color)
        end
    end

    Renderer.drawCell(originCol + player.col - 1, originRow + player.row - 1, "@", { 1, 1, 0.2 })

    local activeId = game.party.active
    local instance = game.party.riders[activeId]
    local riderData = Party.getData(activeId)
    Renderer.drawText(2, 1, string.format(
        "%s Lv.%d  HP %d/%d", riderData.name, instance.level, instance.hp, Party.getMaxHP(instance)))

    Renderer.drawText(originCol, originRow + mapHeight + 1, "WASD/Arrows move   E interact   F5 save   Esc menu")

    if saveMessageTimer > 0 then
        Renderer.drawText(originCol, originRow + mapHeight + 2, "Game saved.", { 0.6, 1, 0.6 })
    end

    if dialogueText then
        Renderer.drawBox(2, mapHeight + 5, mapWidth, 4, { 1, 1, 1 })
        Renderer.drawText(4, mapHeight + 6, dialogueText)
        Renderer.drawText(4, mapHeight + 7, "(press any key)")
    end
end

return World
