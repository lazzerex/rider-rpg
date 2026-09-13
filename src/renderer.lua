local Renderer = {}

local font
local cellWidth, cellHeight

function Renderer.load()
    font = love.graphics.newFont("assets/mono.ttf", 20)
    love.graphics.setFont(font)
    cellWidth = font:getWidth("M")
    cellHeight = font:getHeight()
end

function Renderer.getCellSize()
    return cellWidth, cellHeight
end

function Renderer.drawCell(col, row, char, color)
    love.graphics.setColor(color or { 1, 1, 1 })
    love.graphics.print(char, col * cellWidth, row * cellHeight)
    love.graphics.setColor(1, 1, 1)
end

function Renderer.drawText(col, row, text, color)
    love.graphics.setColor(color or { 1, 1, 1 })
    love.graphics.print(text, col * cellWidth, row * cellHeight)
    love.graphics.setColor(1, 1, 1)
end

function Renderer.drawBox(col, row, width, height, color)
    for x = 1, width - 2 do
        Renderer.drawCell(col + x, row, "─", color)
        Renderer.drawCell(col + x, row + height - 1, "─", color)
    end
    for y = 1, height - 2 do
        Renderer.drawCell(col, row + y, "│", color)
        Renderer.drawCell(col + width - 1, row + y, "│", color)
    end

    Renderer.drawCell(col, row, "┌", color)
    Renderer.drawCell(col + width - 1, row, "┐", color)
    Renderer.drawCell(col, row + height - 1, "└", color)
    Renderer.drawCell(col + width - 1, row + height - 1, "┘", color)
end

function Renderer.drawSprite(col, row, lines, color)
    for dy, line in ipairs(lines) do
        local dx = 0
        for ch in line:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
            if ch ~= " " then
                Renderer.drawCell(col + dx, row + dy - 1, ch, color)
            end
            dx = dx + 1
        end
    end
end

local function barColor(ratio)
    if ratio < 0.3 then
        return { 0.9, 0.2, 0.2 }
    elseif ratio < 0.6 then
        return { 0.9, 0.8, 0.2 }
    end
    return { 0.2, 0.9, 0.2 }
end

local function drawBar(col, row, width, current, max, color)
    local ratio = math.max(0, math.min(1, current / max))
    local filled = math.floor(ratio * width)
    local bar = string.rep("█", filled) .. string.rep("░", width - filled)
    Renderer.drawText(col, row, bar, color)
end

function Renderer.drawHealthBar(col, row, width, current, max)
    drawBar(col, row, width, current, max, barColor(current / max))
end

function Renderer.drawEnergyBar(col, row, width, current, max)
    drawBar(col, row, width, current, max, { 0.3, 0.6, 1 })
end

return Renderer
