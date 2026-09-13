local Renderer = require("renderer")
local Menu = require("ui.menu")
local Select = require("ui.select")
local World = require("world")
local Battle = require("battle")
local Party = require("party")
local Save = require("save")

local Game = {}

Game.STATES = {
    MENU = "MENU",
    SELECT = "SELECT",
    WORLD = "WORLD",
    BATTLE = "BATTLE",
}

Game.state = Game.STATES.MENU
Game.party = nil

local screens = {
    [Game.STATES.MENU] = Menu,
    [Game.STATES.SELECT] = Select,
    [Game.STATES.WORLD] = World,
    [Game.STATES.BATTLE] = Battle,
}

local TRANSITION_SPEED = 6 -- alpha units per second; ~0.17s each way
local transitionPhase = "none" -- "out" | "in" | "none"
local transitionAlpha = 0
local pendingState, pendingPayload

function Game.setState(newState, payload)
    if transitionPhase ~= "none" then return end
    pendingState, pendingPayload = newState, payload
    transitionPhase = "out"
end

function Game.autosave()
    Save.save({ party = Game.party, position = World.getPosition() })
end

function Game.load()
    Renderer.load()

    local loaded = Save.load()
    Game.party = (loaded and loaded.party) or Party.newGame()
    Game.party.items = Game.party.items or {} -- older saves predate the bag

    Menu.load(Game)
    Select.load(Game)
    World.load(Game, loaded and loaded.position)
    Battle.load(Game)

    -- bypass the fade transition for the very first screen: there is
    -- nothing on screen yet to fade from
    Game.state = Game.STATES.MENU
    Menu.enter()
end

function Game.update(dt)
    if transitionPhase == "out" then
        transitionAlpha = math.min(1, transitionAlpha + TRANSITION_SPEED * dt)
        if transitionAlpha >= 1 then
            Game.state = pendingState
            screens[Game.state].enter(pendingPayload)
            transitionPhase = "in"
        end
    elseif transitionPhase == "in" then
        transitionAlpha = math.max(0, transitionAlpha - TRANSITION_SPEED * dt)
        if transitionAlpha <= 0 then
            transitionPhase = "none"
        end
    end

    screens[Game.state].update(dt)
end

function Game.draw()
    screens[Game.state].draw()

    if transitionAlpha > 0 then
        love.graphics.setColor(0, 0, 0, transitionAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Game.keypressed(key)
    screens[Game.state].keypressed(key)
end

function Game.mousepressed(x, y, button)
    screens[Game.state].mousepressed(x, y, button)
end

return Game
