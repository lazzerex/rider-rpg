local Renderer = require("renderer")
local Button = require("ui.button")
local Save = require("save")

local Menu = {}

local game
local buttons

local STARS = {
    { col = 4, row = 1 }, { col = 34, row = 2 }, { col = 46, row = 1 },
    { col = 52, row = 4 }, { col = 6, row = 6 }, { col = 40, row = 7 },
    { col = 50, row = 9 }, { col = 3, row = 10 }, { col = 44, row = 12 },
}

local HELMET = {
    "      .--''--.      ",
    "    /  O    O  \\    ",
    "   |     __     |   ",
    "    \\   '--'   /    ",
    "     '--------'     ",
}

function Menu.load(gameRef)
    game = gameRef
end

function Menu.enter()
    local startLabel = Save.exists() and "Continue" or "Start"

    local startButton = Button.new(10, 15, 16, 3, startLabel)
    startButton.onClick = function()
        if Save.exists() then
            game.setState(game.STATES.WORLD)
        else
            game.setState(game.STATES.SELECT)
        end
    end

    local quitButton = Button.new(10, 19, 16, 3, "Quit")
    quitButton.onClick = function() love.event.quit() end

    buttons = { startButton, quitButton }
end

function Menu.update(dt) end

function Menu.draw()
    for _, star in ipairs(STARS) do
        Renderer.drawCell(star.col, star.row, ".", { 0.5, 0.5, 0.6 })
    end

    Renderer.drawSprite(8, 1, HELMET, { 0.6, 0.75, 0.9 })
    Renderer.drawText(10, 7, "KAMEN RIDER RPG")

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
