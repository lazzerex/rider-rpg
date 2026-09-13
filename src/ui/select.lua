local Renderer = require("renderer")
local Button = require("ui.button")

local Select = {}

local game
local buttons
local message

local CHOICES = {
    { id = "ichigo", label = "ICHIGO", era = "Showa Era", locked = true },
    { id = "kuuga", label = "KUUGA", era = "Heisei Era", locked = false },
    { id = "zeroone", label = "ZERO-ONE", era = "Reiwa Era", locked = true },
}

function Select.load(gameRef)
    game = gameRef
end

function Select.enter()
    buttons = {}
    message = nil

    local col = 6
    for _, choice in ipairs(CHOICES) do
        local button = Button.new(col, 10, 15, 5, choice.label)
        button.choice = choice
        button.onClick = function()
            if choice.locked then
                message = choice.label .. " is coming soon!"
            else
                game.setState(game.STATES.WORLD)
            end
        end
        table.insert(buttons, button)
        col = col + 17
    end
end

function Select.update(dt) end

function Select.draw()
    Renderer.drawText(6, 3, "CHOOSE YOUR RIDER")
    Renderer.drawText(6, 5, "Every region belongs to a different Kamen Rider era.", { 0.7, 0.7, 0.7 })

    for _, button in ipairs(buttons) do
        button:draw()
        local eraColor = button.choice.locked and { 0.5, 0.5, 0.5 } or { 0.8, 0.9, 1 }
        Renderer.drawText(button.col + 1, button.row + button.height, button.choice.era, eraColor)
        if button.choice.locked then
            Renderer.drawText(button.col + 1, button.row + button.height + 1, "Coming soon", { 0.5, 0.45, 0.4 })
        end
    end

    if message then
        Renderer.drawText(6, 22, message, { 1, 0.8, 0.4 })
    end
end

function Select.keypressed(key)
    local index = tonumber(key)
    if index and buttons[index] then
        buttons[index].onClick()
    end
end

function Select.mousepressed(x, y, mbutton)
    local mx, my = love.mouse.getPosition()
    for _, button in ipairs(buttons) do
        button:updateHover(mx, my)
        button:mousepressed(x, y, mbutton)
    end
end

return Select
