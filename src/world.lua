local Renderer = require("renderer")
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
local VIEWPORT_COLS, VIEWPORT_ROWS = 56, 18
local DIVIDER_COL = 45

local BLOCKING = {
    ["#"] = true, ["T"] = true, ["B"] = true, ["N"] = true, ["S"] = true,
    ["R"] = true, ["~"] = true, ["f"] = true,
}
local LANDMARK_TILES = { B = true, N = true, S = true, R = true }
local ENCOUNTER_CHANCE = 0.14
local ENCOUNTER_COOLDOWN_STEPS = 6

local MOVE_REPEAT_INTERVAL = 0.13
local moveTimer = 0

local function heldDirection()
    if love.keyboard.isDown("w", "up") then return 0, -1 end
    if love.keyboard.isDown("s", "down") then return 0, 1 end
    if love.keyboard.isDown("a", "left") then return -1, 0 end
    if love.keyboard.isDown("d", "right") then return 1, 0 end
    return nil
end

local GRASS_VARIANTS = { ",", "'", " ", "." }
local GROUND_VARIANTS = { ".", " ", " ", ":" }

local function buildMap()
    local width, height = 110, 50
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

    for row = 2, height - 1 do
        grid[row][DIVIDER_COL] = "#"
    end

    local roadRow = 13
    for col = 2, width - 1 do
        grid[roadRow][col] = "="
    end

    -- grass grows in distinct patches with open ground between them,
    -- rather than covering the whole wilderness edge to edge
    local grassPatches = {
        { 3, 10, 48, 58 },
        { 3, 12, 65, 75 },
        { 14, 18, 60, 70 },
        { 22, 28, 48, 56 },
        { 22, 30, 65, 78 },
        { 35, 42, 50, 60 },
        { 35, 44, 68, 80 },
        { 5, 9, 85, 95 },
        { 20, 26, 90, 100 },
        { 38, 45, 90, 102 },
    }
    for _, patch in ipairs(grassPatches) do
        local rowStart, rowEnd, colStart, colEnd = patch[1], patch[2], patch[3], patch[4]
        for row = rowStart, rowEnd do
            for col = colStart, colEnd do
                if grid[row][col] == "." then
                    grid[row][col] = ","
                end
            end
        end
    end

    local trees = {
        { 4, 60 }, { 6, 70 }, { 11, 50 }, { 16, 65 }, { 9, 90 },
        { 24, 52 }, { 27, 72 }, { 31, 58 }, { 36, 55 }, { 40, 75 },
        { 43, 95 }, { 46, 100 }, { 8, 105 }, { 18, 80 }, { 25, 100 },
        { 33, 85 }, { 45, 60 }, { 20, 48 }, { 12, 105 }, { 48, 90 },
    }
    for _, pos in ipairs(trees) do
        grid[pos[1]][pos[2]] = "T"
    end

    local pond = {}
    for r = 25, 29 do
        for c = 75, 80 do
            table.insert(pond, { r, c })
        end
    end
    for _, pos in ipairs(pond) do
        grid[pos[1]][pos[2]] = "~"
    end

    -- bridge crossing the pond north-south through its middle lane
    for row = 25, 29 do
        grid[row][77] = "≡"
    end

    -- dirt path weaving through the wilderness toward the first ledge crossing
    for row = 13, 19 do
        grid[row][DIVIDER_COL + 1] = "."
    end
    for col = DIVIDER_COL + 1, 53 do
        grid[19][col] = "."
    end

    -- ledge tier 1: passable only when stepping down (south)
    for col = 51, 60 do
        grid[20][col] = "v"
    end

    -- ledge tier 2: a second, deeper descent further into the wilderness
    for col = 70, 80 do
        grid[36][col] = "v"
    end

    -- fenced flower garden near the player's house
    for col = 2, 4 do
        grid[5][col] = "f"
        grid[7][col] = "f"
    end
    grid[6][2] = "f"
    grid[6][4] = "f"
    grid[6][3] = "*"

    -- reserved roof tiles (blocking, purely visual - drawn as part of the
    -- landmark sprite one row above its body tile)
    grid[3][5] = "R"
    grid[4][5] = "B"
    grid[2][17] = "R"
    grid[3][17] = "B"
    grid[25][8] = "R"
    grid[26][8] = "B"
    grid[26][10] = "R"
    grid[27][10] = "N"
    grid[44][36] = "R"
    grid[44][37] = "R"
    grid[44][38] = "R"
    grid[45][36] = "B"
    grid[45][37] = "B"
    grid[45][38] = "B"
    grid[35][22] = "R"
    grid[36][22] = "B"
    grid[14][20] = "R"
    grid[15][20] = "S"

    grid[21][63] = "R"
    grid[22][63] = "N"
    grid[36][85] = "R"
    grid[37][85] = "N"
    grid[9][68] = "R"
    grid[10][68] = "N"
    grid[26][83] = "R"
    grid[27][83] = "N"
    grid[39][102] = "R"
    grid[40][102] = "S"

    return grid, width, height
end

local function tileVisual(tile, row, col)
    if tile == "#" then return "#", { 0.55, 0.55, 0.55 } end
    if tile == "," then
        local variant = GRASS_VARIANTS[(row * 31 + col * 17) % #GRASS_VARIANTS + 1]
        return variant, { 0.3, 0.75, 0.35 }
    end
    if tile == "=" then return "=", { 0.7, 0.6, 0.4 } end
    if tile == "T" then return "T", { 0.15, 0.55, 0.15 } end
    if tile == "~" then return "~", { 0.35, 0.6, 0.85 } end
    if tile == "*" then return "*", { 0.9, 0.55, 0.75 } end
    if tile == "f" then return "|", { 0.55, 0.4, 0.25 } end
    if tile == "v" then return "v", { 0.65, 0.55, 0.35 } end
    if tile == "≡" then return "≡", { 0.6, 0.45, 0.25 } end
    local variant = GROUND_VARIANTS[(row * 19 + col * 11) % #GROUND_VARIANTS + 1]
    return variant, { 0.42, 0.42, 0.42 }
end

local function isBlocked(col, row, dy)
    if col < 1 or row < 1 or col > mapWidth or row > mapHeight then
        return true
    end
    local tile = map[row][col]
    if tile == "v" then
        return dy ~= 1
    end
    return BLOCKING[tile] == true
end

local function findInteractable(col, row)
    for _, spot in ipairs(interactables) do
        local w = spot.width or 1
        if row == spot.row and col >= spot.col and col < spot.col + w then
            return spot
        end
    end
    return nil
end

local function computeCamera()
    local camCol = player.col - math.floor(VIEWPORT_COLS / 2)
    camCol = math.max(0, math.min(camCol, mapWidth - VIEWPORT_COLS))
    local camRow = player.row - math.floor(VIEWPORT_ROWS / 2)
    camRow = math.max(0, math.min(camRow, mapHeight - VIEWPORT_ROWS))
    return camCol, camRow
end

function World.load(gameRef, initialPosition)
    game = gameRef
    map, mapWidth, mapHeight = buildMap()

    interactables = {
        {
            col = 5, row = 4, message = "Your house. Simple and quiet.",
            sprite = { "▲", "H" }, color = { 0.75, 0.45, 0.35 },
        },
        {
            col = 17, row = 3, message = "Mart: \"Sorry, we're not open yet.\"",
            sprite = { "▲", "M" }, color = { 0.35, 0.5, 0.9 },
        },
        {
            col = 8, row = 26, message = "Rider Center: your party is fully healed.", heal = true,
            sprite = { "▲", "C" }, color = { 0.85, 0.35, 0.35 },
        },
        {
            col = 10, row = 27, message = "Nurse: \"Welcome, Rider! Rest up before heading out.\"",
            sprite = { "o", "N" }, color = { 0.9, 0.9, 0.95 },
        },
        {
            col = 22, row = 36, message = "A quiet house. No one's home.",
            sprite = { "▲", "H" }, color = { 0.55, 0.5, 0.4 },
        },
        {
            col = 36, row = 45, width = 3, message = "Dojo: \"Come back when you're stronger.\"",
            sprite = { "▲▲▲", "DDD" }, color = { 0.7, 0.45, 0.85 },
        },
        {
            col = 20, row = 15, message = "Route sign: \"Wild grass ahead. Kamen Riders await.\"",
            sprite = { "┬", "S" }, color = { 0.8, 0.7, 0.5 },
        },
        {
            col = 63, row = 22, message = "Hiker: \"You can hop down a ledge, but you can't climb back up!\"",
            sprite = { "o", "N" }, color = { 0.8, 0.7, 0.5 },
        },
        {
            col = 85, row = 37, message = "Climber: \"This drop leads deeper into the wilds. No turning back.\"",
            sprite = { "o", "N" }, color = { 0.75, 0.6, 0.5 },
        },
        {
            col = 68, row = 10, message = "Wanderer: \"I've seen strange creatures in the grass around here. Be careful.\"",
            sprite = { "o", "N" }, color = { 0.6, 0.8, 0.6 },
        },
        {
            col = 83, row = 27, message = "Angler: \"The water's calm here. I like to fish by the bridge.\"",
            sprite = { "o", "N" }, color = { 0.5, 0.7, 0.9 },
        },
        {
            col = 102, row = 40, message = "Old Marker: \"Ancient Riders once trained in this land.\"",
            sprite = { "┬", "S" }, color = { 0.6, 0.65, 0.5 },
        },
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
    if isBlocked(newCol, newRow, dy) then return end

    if map[newRow][newCol] == "v" and dy == 1 then
        -- hop straight through a ledge to the tile beyond; standing on
        -- it would let the player simply step back up, defeating the
        -- one-way point of it. if the tile beyond happens to be blocked,
        -- just don't allow the hop at all.
        if isBlocked(newCol, newRow + 1, dy) then return end
        newRow = newRow + 1
    end

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

    if dialogueText then
        moveTimer = 0
        return
    end

    local dx, dy = heldDirection()
    if dx then
        moveTimer = moveTimer - dt
        if moveTimer <= 0 then
            tryMove(dx, dy)
            moveTimer = MOVE_REPEAT_INTERVAL
        end
    else
        moveTimer = 0
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
end

function World.mousepressed(x, y, button)
    if dialogueText then
        dialogueText = nil
    end
end

function World.draw()
    local camCol, camRow = computeCamera()

    for row = camRow + 1, math.min(camRow + VIEWPORT_ROWS, mapHeight) do
        for col = camCol + 1, math.min(camCol + VIEWPORT_COLS, mapWidth) do
            local tile = map[row][col]
            if not LANDMARK_TILES[tile] then
                local char, color = tileVisual(tile, row, col)
                Renderer.drawCell(originCol + col - camCol - 1, originRow + row - camRow - 1, char, color)
            end
        end
    end

    for _, spot in ipairs(interactables) do
        local screenCol = spot.col - camCol - 1
        local screenRow = spot.row - camRow - 1
        if screenCol >= 0 and screenCol < VIEWPORT_COLS and screenRow >= 0 and screenRow < VIEWPORT_ROWS then
            local topRow = screenRow - (#spot.sprite - 1)
            Renderer.drawSprite(originCol + screenCol, originRow + topRow, spot.sprite, spot.color)
        end
    end

    local activeId = game.party.active
    local instance = game.party.riders[activeId]
    local riderData = Party.getData(activeId)

    local px = originCol + player.col - camCol - 1
    local py = originRow + player.row - camRow - 1
    Renderer.drawCell(px, py, riderData.worldGlyph, riderData.color)
    local nameStart = px - math.floor(#riderData.name / 2)
    Renderer.drawText(nameStart, py - 1, riderData.name, riderData.color)

    Renderer.drawText(2, 0, string.format(
        "%s Lv.%d  HP %d/%d", riderData.name, instance.level, instance.hp, Party.getMaxHP(instance)))

    local hintRow = originRow + VIEWPORT_ROWS + 1
    Renderer.drawText(originCol, hintRow, "WASD/Arrows move   E interact   F5 save   Esc menu")

    if saveMessageTimer > 0 then
        Renderer.drawText(originCol, hintRow + 1, "Game saved.", { 0.6, 1, 0.6 })
    end

    if dialogueText then
        local boxRow = hintRow + 2
        Renderer.drawBox(2, boxRow, VIEWPORT_COLS, 4, { 1, 1, 1 })
        Renderer.drawText(4, boxRow + 1, dialogueText)
        Renderer.drawText(4, boxRow + 2, "(press any key)")
    end
end

return World
