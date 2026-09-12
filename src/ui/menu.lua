local Renderer = require("renderer")
local Button = require("ui.button")
local Save = require("save")

local Menu = {}

local game
local buttons

function Menu.load(gameRef)
    game = gameRef
end

function Menu.enter()
    local startLabel = Save.exists() and "Continue" or "Start"

    local startButton = Button.new(10, 12, 16, 3, startLabel)
    startButton.onClick = function() game.setState(game.STATES.WORLD) end

    local quitButton = Button.new(10, 16, 16, 3, "Quit")
    quitButton.onClick = function() love.event.quit() end

    buttons = { startButton, quitButton }
end

function Menu.update(dt) end

function Menu.draw()
    Renderer.drawText(10, 4, "KAMEN RIDER RPG")

    for _, button in ipairs(buttons) do
        button:draw()
    end
end

function Menu.keypressed(key)
    if key == "return" or key == "space" then
        buttons[1].onClick()
    elseif key == "escape" then
        love.event.quit()
    end
end

function Menu.mousepressed(x, y, mbutton)
    local mx, my = love.mouse.getPosition()
    for _, button in ipairs(buttons) do
        button:updateHover(mx, my)
        button:mousepressed(x, y, mbutton)
    end
end

return Menu
