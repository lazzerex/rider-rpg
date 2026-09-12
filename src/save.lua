local Save = {}

local FILENAME = "save.json"

local function encodeValue(value, out)
    local t = type(value)
    if t == "boolean" or t == "number" then
        table.insert(out, tostring(value))
    elseif t == "string" then
        table.insert(out, string.format("%q", value))
    elseif t == "table" then
        if #value > 0 then
            table.insert(out, "[")
            for i, v in ipairs(value) do
                if i > 1 then table.insert(out, ",") end
                encodeValue(v, out)
            end
            table.insert(out, "]")
        else
            table.insert(out, "{")
            local first = true
            for k, v in pairs(value) do
                if not first then table.insert(out, ",") end
                first = false
                table.insert(out, string.format("%q", tostring(k)))
                table.insert(out, ":")
                encodeValue(v, out)
            end
            table.insert(out, "}")
        end
    else
        error("cannot encode type: " .. t)
    end
end

function Save.encode(value)
    local out = {}
    encodeValue(value, out)
    return table.concat(out)
end

local function skipWhitespace(s, i)
    while i <= #s and s:sub(i, i):match("%s") do
        i = i + 1
    end
    return i
end

local decodeValue

local function decodeString(s, i)
    i = i + 1
    local buf = {}
    while true do
        local c = s:sub(i, i)
        if c == "" then error("unterminated string") end
        if c == "\\" then
            local nextC = s:sub(i + 1, i + 1)
            local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\" }
            table.insert(buf, map[nextC] or nextC)
            i = i + 2
        elseif c == '"' then
            i = i + 1
            break
        else
            table.insert(buf, c)
            i = i + 1
        end
    end
    return table.concat(buf), i
end

local function decodeNumber(s, i)
    local start = i
    while i <= #s and s:sub(i, i):match("[%d%.%-eE+]") do
        i = i + 1
    end
    return tonumber(s:sub(start, i - 1)), i
end

decodeValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)

    if c == '"' then
        return decodeString(s, i)
    elseif c == "{" then
        local result = {}
        i = skipWhitespace(s, i + 1)
        if s:sub(i, i) == "}" then return result, i + 1 end
        while true do
            i = skipWhitespace(s, i)
            local key
            key, i = decodeString(s, i)
            i = skipWhitespace(s, i) + 1
            local value
            value, i = decodeValue(s, i)
            result[key] = value
            i = skipWhitespace(s, i)
            local sep = s:sub(i, i)
            i = i + 1
            if sep == "}" then break end
        end
        return result, i
    elseif c == "[" then
        local result = {}
        i = skipWhitespace(s, i + 1)
        if s:sub(i, i) == "]" then return result, i + 1 end
        while true do
            local value
            value, i = decodeValue(s, i)
            table.insert(result, value)
            i = skipWhitespace(s, i)
            local sep = s:sub(i, i)
            i = i + 1
            if sep == "]" then break end
        end
        return result, i
    elseif c == "t" then
        return true, i + 4
    elseif c == "f" then
        return false, i + 5
    elseif c == "n" then
        return nil, i + 4
    else
        return decodeNumber(s, i)
    end
end

function Save.decode(text)
    return decodeValue(text, 1)
end

function Save.exists()
    return love.filesystem.getInfo(FILENAME) ~= nil
end

function Save.save(data)
    local ok, encoded = pcall(Save.encode, data)
    if not ok then
        return false
    end
    love.filesystem.write(FILENAME, encoded)
    return true
end

function Save.load()
    if not Save.exists() then return nil end

    local okRead, contents = pcall(love.filesystem.read, FILENAME)
    if not okRead or not contents then return nil end

    local okDecode, data = pcall(Save.decode, contents)
    if not okDecode then return nil end

    return data
end

return Save
