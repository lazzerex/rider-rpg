local Game = require("game")

function love.load()
    Game.load()
end

function love.update(dt)
    Game.update(dt)
end

function love.draw()
    Game.draw()
end

function love.keypressed(key)
    Game.keypressed(key)
end

function love.mousepressed(x, y, button)
    Game.mousepressed(x, y, button)
end
