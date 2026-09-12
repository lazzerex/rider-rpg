local Renderer = require("renderer")
local Menu = require("ui.menu")
local World = require("world")
local Battle = require("battle")
local Party = require("party")
local Save = require("save")

local Game = {}

Game.STATES = {
    MENU = "MENU",
    WORLD = "WORLD",
    BATTLE = "BATTLE",
}

Game.state = Game.STATES.MENU
Game.party = nil

local screens = {
    [Game.STATES.MENU] = Menu,
    [Game.STATES.WORLD] = World,
    [Game.STATES.BATTLE] = Battle,
}

function Game.setState(newState, payload)
    Game.state = newState
    screens[newState].enter(payload)
end

function Game.autosave()
    Save.save({ party = Game.party, position = World.getPosition() })
end

function Game.load()
    Renderer.load()

    local loaded = Save.load()
    Game.party = (loaded and loaded.party) or Party.newGame()

    Menu.load(Game)
    World.load(Game, loaded and loaded.position)
    Battle.load(Game)

    Game.setState(Game.STATES.MENU)
end

function Game.update(dt)
    screens[Game.state].update(dt)
end

function Game.draw()
    screens[Game.state].draw()
end

function Game.keypressed(key)
    screens[Game.state].keypressed(key)
end

function Game.mousepressed(x, y, button)
    screens[Game.state].mousepressed(x, y, button)
end

return Game
