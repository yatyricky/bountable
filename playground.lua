function table.toJSON(tab)
    local function fts(fn)
        local info = debug.getinfo(fn, "S")
        return string.format("fn%s:%s-%s", info.source, info.linedefined, info.lastlinedefined)
    end

    local function esc(str)
        return string.gsub(str, "\\", "/")
    end

    local function parsePrimitive(o)
        local to = type(o)
        if to == "string" then
            return "\"" .. o .. "\""
        end
        local so = tostring(o)
        if to == "function" then
            return "\"" .. esc(fts(o)) .. "\""
        else
            return so
        end
    end

    local function parseTable(t, cached, p)
        if type(t) ~= "table" then
            return parsePrimitive(t)
        end
        cached = cached or {}
        p = p or "/"
        local tc = cached[t]
        if tc then
            return "\"ref: " .. tc .. "\""
        end
        cached[t] = p
        local items = {}
        for k, v in pairs(t) do
            local ks = tostring(k)
            local key
            local tk = type(k)
            if tk == "number" then
                key = "\"[" .. ks .. "]\""
            elseif tk == "function" then
                key = "\"" .. esc(fts(k)) .. "\""
            else
                key = "\"" .. ks .. "\""
            end
            table.insert(items, key .. ":" .. parseTable(v, cached, p .. ks .. "/"))
        end
        return "{" .. table.concat(items, ",") .. "}"
    end

    return parseTable(tab)
end

local Bountable = require("bountable")

local model = {
    title = "This is title",
    valid = false,
    list = {
        {
            name = "Alice",
            age = 15,
        },
        {
            name = "Bob",
            age = 7
        }
    },
    attrs = {
        stamina = 35,
        strength = 12
    },
    data = {
        1, 2, 3
    }
}

local context = "{context}"

-- create a boundable table from model
local t = Bountable.new(model)

-- t:bind({ "list.*" }, function(key, old, new)
--     print(string.format("Update [list.*] key:%s, old:%s, new:%s", key, old, new))
-- end)

t:bind({ "list" }, function(key, old, new)
    print(string.format("Update [list] key:%s, old:%s, new:%s", key, old:len(), #new))
end)

t:bind({ "list.*" }, function(key, old, new)
    -- print(string.format("Update [list.*] key:%s, old:%s, new:%s", key, table.toJSON(old), table.toJSON(new)))
    print(string.format("Update [list.*] key:%s, old:%s, new:%s", key, old and (old.name .. old.age),
        new and (new.name .. new.age)))
end)

-- t:bind({ "list.*.*" }, function(key, oldValue, newValue)
--     print(string.format("Update [list.*.*] key:%s, old:%s, new:%s", key, oldValue, newValue))
-- end)

-- t.list = {
--     {
--         name = "Aaron",
--         age = 55,
--     },
--     {
--         name = "Bianca",
--         age = 98,
--     },
--     {
--         name = "Catherine",
--         age = 37,
--     },
-- }

print("--------------------------------")

-- t.list[3].name = "Chlore"

-- print(t.list[2].name)

t.list = {
    {
        name = "Aaron",
        age = 55,
    },
}
print("--------------------------------")

t:bind({ "data" }, function(key, old, new)
    print(string.format("Update [data] key:%s, old:%s, new:%s", key, old, new))
end)

t:bind({ "data.*" }, function(key, old, new)
    print(string.format("Update [data.*] key:%s, old:%s, new:%s", key, old, new))
end)

t.data = { 5, 6 }

print("--------------------------------")

t.data[1] = 55
t.data[4] = 88
t.data[2] = nil
t.data[2] = 66
