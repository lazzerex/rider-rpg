local Input = {}

local directions = {
    w = { 0, -1 }, up = { 0, -1 },
    s = { 0, 1 }, down = { 0, 1 },
    a = { -1, 0 }, left = { -1, 0 },
    d = { 1, 0 }, right = { 1, 0 },
}

function Input.directionForKey(key)
    return directions[key]
end

return Input
