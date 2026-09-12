local Renderer = require("renderer")

local Button = {}
Button.__index = Button

function Button.new(col, row, width, height, label)
    return setmetatable({
        col = col, row = row, width = width, height = height,
        label = label, enabled = true, hovered = false, onClick = nil,
    }, Button)
end

function Button:containsPixel(x, y)
    local cw, ch = Renderer.getCellSize()
    local bx, by = self.col * cw, self.row * ch
    local bw, bh = self.width * cw, self.height * ch
    return x >= bx and x <= bx + bw and y >= by and y <= by + bh
end

function Button:updateHover(mx, my)
    self.hovered = self.enabled and self:containsPixel(mx, my)
end

function Button:mousepressed(x, y, mbutton)
    if mbutton == 1 and self.enabled and self:containsPixel(x, y) then
        if self.onClick then self.onClick() end
        return true
    end
    return false
end

function Button:draw()
    local color = { 1, 1, 1 }
    if not self.enabled then
        color = { 0.4, 0.4, 0.4 }
    elseif self.hovered then
        color = { 1, 1, 0.4 }
    end

    Renderer.drawBox(self.col, self.row, self.width, self.height, color)
    Renderer.drawText(self.col + 1, self.row + math.floor(self.height / 2), self.label, color)
end

return Button
