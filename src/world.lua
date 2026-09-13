local Renderer = require("renderer")
local Party = require("party")
local Items = require("items")

local World = {}

local game
local map
local mapWidth, mapHeight
local player
local dialogueText
local encounterCooldown = 0
local saveMessageTimer = 0
local interactables
local trailCol, trailRow, trailTimer = nil, nil, 0
local TRAIL_DURATION = 0.22
local menuMode = nil -- nil | "pause" | "collection" | "bag" | "bagTarget"
local pauseCursor = 1
local statusCursor = 1
local bagCursor = 1
local bagTargetCursor = 1
local bagSelectedItem = nil
local PAUSE_OPTIONS = { "Rider Collection", "Bag", "Save", "Close" }

local REGION_NAME = "RINTO REGION"
local BANNER_DURATION = 2.5
local BANNER_FADE = 0.5
local regionBannerTimer = 0

local originCol, originRow = 2, 3
local VIEWPORT_COLS, VIEWPORT_ROWS = 74, 19
local DIVIDER_COL = 45

local BLOCKING = {
    ["#"] = true, ["T"] = true, ["B"] = true, ["N"] = true, ["S"] = true,
    ["R"] = true, ["~"] = true, ["f"] = true, ["X"] = true, ["o"] = true,
}
local LANDMARK_TILES = { B = true, N = true, S = true, R = true }
local ENCOUNTER_CHANCE = 0.14
local ENCOUNTER_COOLDOWN_STEPS = 6

-- wilderness enemy strength scales with distance from town, like distinct
-- routes in a real region rather than one flat difficulty everywhere
local function levelRangeForZone(col)
    if col < 66 then return 1, 5 end
    if col < 91 then return 5, 10 end
    if col < 112 then return 10, 15 end
    return 15, 20
end

local MOVE_REPEAT_INTERVAL = 0.13
local SPRINT_REPEAT_INTERVAL = 0.07
local moveTimer = 0

local function isSprinting()
    return love.keyboard.isDown("lshift", "rshift")
end

local DIALOGUE_TEXT_WIDTH = 52

local function wrapText(text, maxWidth)
    local lines = {}
    local current = ""
    for word in text:gmatch("%S+") do
        local candidate = (current == "" and word) or (current .. " " .. word)
        if #candidate > maxWidth and current ~= "" then
            table.insert(lines, current)
            current = word
        else
            current = candidate
        end
    end
    if current ~= "" then
        table.insert(lines, current)
    end
    return lines
end

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
    local width, height = 140, 60
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

    -- the town/wilderness boundary isn't one wall with a single choke
    -- point - it has several natural crossings, each its own route rather
    -- than a single funnel
    local dividerGaps = { { 6, 8 }, { 25, 27 }, { 40, 42 } }
    local function inDividerGap(row)
        for _, gap in ipairs(dividerGaps) do
            if row >= gap[1] and row <= gap[2] then return true end
        end
        return false
    end
    for row = 2, height - 1 do
        if not inDividerGap(row) then
            grid[row][DIVIDER_COL] = "#"
        end
    end

    local roadRow = 13
    for col = 2, width - 1 do
        grid[roadRow][col] = "="
    end

    -- Forest Trail: a tree-flanked crossing north of the road
    for row = 6, 8 do
        grid[row][DIVIDER_COL - 1] = "."
        grid[row][DIVIDER_COL + 1] = "."
    end
    grid[5][DIVIDER_COL - 2] = "T"
    grid[5][DIVIDER_COL + 2] = "T"
    grid[9][DIVIDER_COL - 2] = "T"
    grid[9][DIVIDER_COL + 2] = "T"

    -- Meadow Path: a wider, open crossing further south
    for row = 25, 27 do
        for col = DIVIDER_COL - 2, DIVIDER_COL + 2 do
            grid[row][col] = "."
        end
    end

    -- Southern Trail: a narrower crossing near the Dojo
    for row = 40, 42 do
        grid[row][DIVIDER_COL] = "."
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

    -- a two-way gap through the ledge: the one-way hop at cols 51-60 is a
    -- shortcut, not the only way through - col 53 stays open both ways
    grid[20][53] = "."

    -- branch linking that gap down to the Meadow Path crossing, so the
    -- ledge/patch area and the pond/ruins area connect two ways instead
    -- of only through their own separate crossings
    for row = 20, 26 do
        grid[row][53] = "."
    end
    for col = 47, 53 do
        grid[26][col] = "."
    end

    -- second branch: Forest Trail crossing down to the cave's outer sign,
    -- an alternate route to the cave besides wandering the open patches
    for row = 8, 16 do
        grid[row][DIVIDER_COL + 2] = "."
    end
    for col = DIVIDER_COL + 2, 100 do
        grid[16][col] = "."
    end

    -- ledge tier 2: a second, deeper descent further into the wilderness
    for col = 70, 80 do
        grid[36][col] = "v"
    end

    -- sealed chamber: the cave where the first Kuuga bound the Gurongi
    -- leader, tucked in the far corner of the wilderness
    local caveTop, caveBottom, caveLeft, caveRight = 2, 12, 96, 108
    for row = caveTop, caveBottom do
        for col = caveLeft, caveRight do
            if row == caveTop or row == caveBottom or col == caveLeft or col == caveRight then
                grid[row][col] = "X"
            else
                grid[row][col] = "c"
            end
        end
    end
    grid[caveBottom][102] = "c" -- entrance gap on the south wall

    -- Approach to the Boss: rather than the wilderness continuing straight
    -- east, it bends south here into fresh, higher-level ground - a Z
    -- shape instead of one long rectangle
    local approachPatches = {
        { 5, 15, 112, 122 },
        { 25, 35, 112, 126 },
    }
    for _, patch in ipairs(approachPatches) do
        local rowStart, rowEnd, colStart, colEnd = patch[1], patch[2], patch[3], patch[4]
        for row = rowStart, rowEnd do
            for col = colStart, colEnd do
                if grid[row][col] == "." then
                    grid[row][col] = ","
                end
            end
        end
    end

    local approachTrees = { { 8, 116 }, { 12, 120 }, { 28, 118 }, { 32, 124 } }
    for _, pos in ipairs(approachTrees) do
        grid[pos[1]][pos[2]] = "T"
    end

    -- the bend itself: the path turns south rather than continuing east
    for row = 35, 47 do
        grid[row][120] = "."
    end

    -- Boss Chamber: N-Daguva-Zeba waits at the end of the Z
    local bossTop, bossBottom, bossLeft, bossRight = 48, 58, 114, 128
    for row = bossTop, bossBottom do
        for col = bossLeft, bossRight do
            if row == bossTop or row == bossBottom or col == bossLeft or col == bossRight then
                grid[row][col] = "X"
            else
                grid[row][col] = "c"
            end
        end
    end
    grid[bossTop][120] = "c" -- entrance, aligned with the bend above

    -- riverside: a quiet stretch of water in town, crossed by a bridge
    for row = 30, 36 do
        for col = 27, 29 do
            grid[row][col] = "~"
        end
    end
    for col = 27, 29 do
        grid[33][col] = "≡"
    end

    -- ancient ruins: a loose ring of standing stones in the wilderness,
    -- echoing the Rinto's own stone circle
    local stones = { { 44, 57 }, { 44, 61 }, { 46, 55 }, { 46, 63 }, { 48, 57 }, { 48, 61 } }
    for _, pos in ipairs(stones) do
        grid[pos[1]][pos[2]] = "o"
    end

    -- border to Agito's region, south of town - fenced off but for the
    -- single gap the gatekeeper is blocking. No roof reservation here:
    -- the fence already seals the row, so a roof above would leave no
    -- open tile to approach and interact with the gatekeeper from.
    for col = 2, 15 do
        grid[58][col] = "f"
    end
    grid[58][6] = "N"

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
    grid[6][102] = "R"
    grid[7][102] = "S"
    grid[15][100] = "R"
    grid[16][100] = "S"
    grid[45][59] = "R"
    grid[46][59] = "S"
    grid[32][25] = "R"
    grid[33][25] = "S"
    grid[52][120] = "R"
    grid[53][120] = "N"
    grid[45][121] = "R"
    grid[46][121] = "S"

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
    if tile == "X" then return "X", { 0.3, 0.27, 0.32 } end
    if tile == "c" then return ".", { 0.22, 0.2, 0.25 } end
    if tile == "o" then return "o", { 0.55, 0.5, 0.45 } end
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
        {
            col = 102, row = 7,
            message = "Plaque: \"Here, Kuuga bound the Gurongi leader.\"",
            sprite = { "┬", "S" }, color = { 0.5, 0.4, 0.55 },
        },
        {
            col = 100, row = 16,
            message = "Sign: \"A sealed cave lies just north. Something ancient rests within.\"",
            sprite = { "┬", "S" }, color = { 0.8, 0.7, 0.5 },
        },
        {
            col = 59, row = 46,
            message = "A ring of standing stones. The Rinto gathered here, long ago.",
            sprite = { "┬", "S" }, color = { 0.6, 0.55, 0.5 },
        },
        {
            col = 25, row = 33,
            message = "Sign: \"Riverside. A peaceful place to rest.\"",
            sprite = { "┬", "S" }, color = { 0.5, 0.65, 0.75 },
        },
        {
            col = 6, row = 58,
            message = "Gatekeeper: \"This path leads to Agito's region. It's not open yet.\"",
            sprite = { "N" }, color = { 0.5, 0.5, 0.55 },
        },
        {
            col = 121, row = 46,
            message = "A crushing presence radiates from the chamber ahead. This is it.",
            sprite = { "┬", "S" }, color = { 0.6, 0.1, 0.15 },
        },
        {
            col = 120, row = 53,
            sprite = { " /^\\ ", "<###>" }, color = { 0.7, 0.1, 0.15 },
            bossBattle = "n_daguva_zeba", bossLevel = 20,
        },
    }

    player = {
        col = (initialPosition and initialPosition.col) or 5,
        row = (initialPosition and initialPosition.row) or 8,
        facing = (initialPosition and initialPosition.facing) or "down",
    }

    -- shown once per session on first entering the overworld, not on every
    -- return from battle (World.enter runs on those too)
    regionBannerTimer = BANNER_DURATION
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
    if not spot then return end

    if spot.bossBattle then
        game.setState(game.STATES.BATTLE, { enemyLevel = spot.bossLevel, forcedEnemyId = spot.bossBattle })
        return
    end

    dialogueText = spot.message
    if spot.heal then
        Party.healAll(game.party)
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

    trailCol, trailRow, trailTimer = player.col, player.row, TRAIL_DURATION
    player.col, player.row = newCol, newRow

    if encounterCooldown > 0 then
        encounterCooldown = encounterCooldown - 1
    end

    local tile = map[player.row][player.col]
    if tile == "," and encounterCooldown <= 0 then
        if math.random() < ENCOUNTER_CHANCE then
            encounterCooldown = ENCOUNTER_COOLDOWN_STEPS
            local lvlMin, lvlMax = levelRangeForZone(player.col)
            game.setState(game.STATES.BATTLE, { enemyLevel = math.random(lvlMin, lvlMax) })
        end
    end
end

function World.update(dt)
    if saveMessageTimer > 0 then
        saveMessageTimer = saveMessageTimer - dt
    end

    if trailTimer > 0 then
        trailTimer = trailTimer - dt
    end

    if regionBannerTimer > 0 then
        regionBannerTimer = regionBannerTimer - dt
    end

    if dialogueText or menuMode then
        moveTimer = 0
        return
    end

    local dx, dy = heldDirection()
    if dx then
        moveTimer = moveTimer - dt
        if moveTimer <= 0 then
            tryMove(dx, dy)
            moveTimer = isSprinting() and SPRINT_REPEAT_INTERVAL or MOVE_REPEAT_INTERVAL
        end
    else
        moveTimer = 0
    end
end

local function ownedItemList()
    local list = {}
    for _, id in ipairs(Items.ORDER) do
        if (game.party.items[id] or 0) > 0 then
            table.insert(list, id)
        end
    end
    return list
end

local function ownedRiderList()
    local list = {}
    for _, id in ipairs(Party.RIDER_ORDER) do
        if Party.isOwned(game.party, id) then
            table.insert(list, id)
        end
    end
    return list
end

function World.keypressed(key)
    if dialogueText then
        dialogueText = nil
        return
    end

    if menuMode == "pause" then
        if key == "tab" or key == "escape" then
            menuMode = nil
        elseif key == "w" or key == "up" then
            pauseCursor = math.max(1, pauseCursor - 1)
        elseif key == "s" or key == "down" then
            pauseCursor = math.min(#PAUSE_OPTIONS, pauseCursor + 1)
        elseif key == "return" or key == "space" then
            local choice = PAUSE_OPTIONS[pauseCursor]
            if choice == "Rider Collection" then
                menuMode = "collection"
                statusCursor = 1
                for i, id in ipairs(Party.RIDER_ORDER) do
                    if id == game.party.active then
                        statusCursor = i
                        break
                    end
                end
            elseif choice == "Bag" then
                menuMode = "bag"
                bagCursor = 1
            elseif choice == "Save" then
                game.autosave()
                saveMessageTimer = 1.5
                menuMode = nil
            elseif choice == "Close" then
                menuMode = nil
            end
        end
        return
    end

    if menuMode == "collection" then
        if key == "tab" then
            menuMode = nil
        elseif key == "escape" then
            menuMode = "pause" -- step back one level, not all the way out
        elseif key == "w" or key == "up" then
            statusCursor = math.max(1, statusCursor - 1)
        elseif key == "s" or key == "down" then
            statusCursor = math.min(#Party.RIDER_ORDER, statusCursor + 1)
        elseif key == "return" or key == "space" then
            local id = Party.RIDER_ORDER[statusCursor]
            if Party.isOwned(game.party, id) then
                Party.setActive(game.party, id)
            end
        end
        return
    end

    if menuMode == "bag" then
        local items = ownedItemList()
        if key == "tab" then
            menuMode = nil
        elseif key == "escape" then
            menuMode = "pause"
        elseif key == "w" or key == "up" then
            bagCursor = math.max(1, bagCursor - 1)
        elseif key == "s" or key == "down" then
            bagCursor = math.min(math.max(1, #items), bagCursor + 1)
        elseif key == "return" or key == "space" then
            if items[bagCursor] then
                bagSelectedItem = items[bagCursor]
                bagTargetCursor = 1
                menuMode = "bagTarget"
            end
        end
        return
    end

    if menuMode == "bagTarget" then
        local riders = ownedRiderList()
        if key == "tab" then
            menuMode = nil
        elseif key == "escape" then
            menuMode = "bag"
        elseif key == "w" or key == "up" then
            bagTargetCursor = math.max(1, bagTargetCursor - 1)
        elseif key == "s" or key == "down" then
            bagTargetCursor = math.min(#riders, bagTargetCursor + 1)
        elseif key == "return" or key == "space" then
            local riderId = riders[bagTargetCursor]
            local def = Items.DEFS[bagSelectedItem]
            if riderId and def then
                if def.heal then
                    Party.useItemHeal(game.party, bagSelectedItem, riderId, def.heal)
                elseif def.xp then
                    if Party.consumeItem(game.party, bagSelectedItem) then
                        Party.awardExperience(game.party, riderId, def.xp)
                    end
                end
            end
            menuMode = "bag"
            bagCursor = 1
        end
        return
    end

    if key == "tab" then
        menuMode = "pause"
        pauseCursor = 1
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
        return
    end

    if menuMode then
        menuMode = nil
    end
end

local function drawPauseMenu()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

    Renderer.drawBox(4, 2, 24, #PAUSE_OPTIONS * 2 + 3, { 1, 1, 1 })
    Renderer.drawText(6, 3, "MENU", { 1, 1, 0.6 })

    for i, label in ipairs(PAUSE_OPTIONS) do
        local cursor = (i == pauseCursor) and "> " or "  "
        Renderer.drawText(6, 4 + i * 2, cursor .. label)
    end
end

local function drawCollectionPage()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

    Renderer.drawBox(4, 2, VIEWPORT_COLS - 4, 16, { 1, 1, 1 })
    Renderer.drawText(6, 3, "RIDER COLLECTION", { 1, 1, 0.6 })

    local row = 5
    for i, id in ipairs(Party.RIDER_ORDER) do
        local data = Party.getData(id)
        local owned = Party.isOwned(game.party, id)
        local cursor = (i == statusCursor) and "> " or "  "

        if owned then
            local instance = game.party.riders[id]
            local isActive = id == game.party.active
            local formLabel = data.forms[instance.baseFormKey].label
            local maxHP = Party.getMaxHP(instance)
            local xpNeeded = Party.xpToNext(instance.level)
            local nameColor = isActive and data.color or { 0.8, 0.8, 0.8 }

            Renderer.drawText(6, row, string.format("%s%s  Lv.%d  [%s]%s",
                cursor, data.name, instance.level, formLabel, isActive and "  (ACTIVE)" or ""), nameColor)
            Renderer.drawText(10, row + 1, string.format(
                "HP %d/%d   XP %d/%d", instance.hp, maxHP, instance.xp, xpNeeded))
        else
            Renderer.drawText(6, row, string.format("%s%s", cursor, data.name), { 0.5, 0.5, 0.5 })
            Renderer.drawText(10, row + 1, "LOCKED - unlock in Agito's region", { 0.5, 0.4, 0.4 })
        end
        row = row + 3
    end

    Renderer.drawText(6, row + 1, "Arrows: select   Enter: set active   Esc: back   Tab: close", { 0.7, 0.7, 0.7 })
end

local function drawBagPage()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

    local items = ownedItemList()
    local row = 5

    if #items == 0 then
        Renderer.drawText(6, row, "No items yet. Gurongi sometimes drop them.", { 0.6, 0.6, 0.6 })
        row = row + 2
    else
        for i, itemId in ipairs(items) do
            local def = Items.DEFS[itemId]
            local cursor = (i == bagCursor) and "> " or "  "
            Renderer.drawText(6, row, string.format(
                "%s%s x%d", cursor, def.name, game.party.items[itemId]))
            Renderer.drawText(10, row + 1, def.description, { 0.7, 0.7, 0.7 })
            row = row + 2
        end
    end

    Renderer.drawBox(4, 2, VIEWPORT_COLS - 4, row + 2, { 1, 1, 1 })
    Renderer.drawText(6, 3, "BAG", { 1, 1, 0.6 })
    Renderer.drawText(6, row + 1, "Arrows: select   Enter: use   Esc: back   Tab: close", { 0.7, 0.7, 0.7 })
end

local function drawBagTargetPage()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

    local riders = ownedRiderList()
    Renderer.drawBox(4, 2, VIEWPORT_COLS - 4, math.max(6, #riders * 2 + 5), { 1, 1, 1 })
    Renderer.drawText(6, 3, "Use " .. Items.DEFS[bagSelectedItem].name .. " on whom?", { 1, 1, 0.6 })

    local row = 5
    for i, id in ipairs(riders) do
        local instance = game.party.riders[id]
        local data = Party.getData(id)
        local cursor = (i == bagTargetCursor) and "> " or "  "
        Renderer.drawText(6, row, string.format(
            "%s%s  Lv.%d  HP %d/%d", cursor, data.name, instance.level, instance.hp, Party.getMaxHP(instance)))
        row = row + 2
    end

    Renderer.drawText(6, row + 1, "Arrows: select   Enter: confirm   Esc: back", { 0.7, 0.7, 0.7 })
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

    if trailTimer > 0 then
        local trailScreenCol = trailCol - camCol - 1
        local trailScreenRow = trailRow - camRow - 1
        if trailScreenCol >= 0 and trailScreenCol < VIEWPORT_COLS
            and trailScreenRow >= 0 and trailScreenRow < VIEWPORT_ROWS then
            local fade = trailTimer / TRAIL_DURATION
            Renderer.drawCell(originCol + trailScreenCol, originRow + trailScreenRow, "'", { 0.5, 0.5, 0.5, fade })
        end
    end

    local activeId = game.party.active
    local riderData = Party.getData(activeId)

    local px = originCol + player.col - camCol - 1
    local py = originRow + player.row - camRow - 1
    Renderer.drawCell(px, py, riderData.worldGlyph, riderData.color)
    local nameStart = px - math.floor(#riderData.name / 2)
    Renderer.drawText(nameStart, py - 1, riderData.name, riderData.color)

    local hintRow = originRow + VIEWPORT_ROWS + 1
    Renderer.drawText(originCol, hintRow, "Move: WASD/Arrows  Shift: run  E interact  Tab: menu  F5 save")

    if saveMessageTimer > 0 then
        Renderer.drawText(originCol, hintRow + 1, "Game saved.", { 0.6, 1, 0.6 })
    end

    if dialogueText then
        local lines = wrapText(dialogueText, DIALOGUE_TEXT_WIDTH)
        local boxRow = hintRow + 2
        local boxHeight = #lines + 3
        Renderer.drawBox(2, boxRow, VIEWPORT_COLS, boxHeight, { 1, 1, 1 })
        for i, line in ipairs(lines) do
            Renderer.drawText(4, boxRow + i, line)
        end
        Renderer.drawText(4, boxRow + #lines + 1, "(press any key)")
    end

    if regionBannerTimer > 0 then
        local alpha = math.min(1, regionBannerTimer / BANNER_FADE)
        local bannerWidth = #REGION_NAME + 4
        local bannerCol = originCol + VIEWPORT_COLS - bannerWidth
        Renderer.drawBox(bannerCol, 0, bannerWidth, 3, { 1, 1, 1, alpha })
        Renderer.drawText(bannerCol + 2, 1, REGION_NAME, { 1, 0.85, 0.4, alpha })
    end

    if menuMode == "pause" then
        drawPauseMenu()
    elseif menuMode == "collection" then
        drawCollectionPage()
    elseif menuMode == "bag" then
        drawBagPage()
    elseif menuMode == "bagTarget" then
        drawBagTargetPage()
    end
end

return World
