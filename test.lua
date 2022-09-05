--region assertion

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

local log = {}
local assertionCount = 0
local assertionPass = 0

local function shallow(tab)
    local t = {}
    for key, value in pairs(tab) do
        t[key] = value
    end
    return t
end

local function seqEqual(s1, s2)
    if s1 == nil and s2 == nil then
        return true
    end
    if s1 == nil or s2 == nil then
        return false
    end
    local len = #s1
    if len ~= #s2 then
        return false
    end
    local seq1 = shallow(s1)
    table.sort(seq1)
    local seq2 = shallow(s2)
    table.sort(seq2)
    for i = 1, len do
        if seq1[i] ~= seq2[i] then
            return false
        end
    end
    return true
end

local u001B = string.char(0) .. string.char(27)
local chalk_red = u001B .. "[31m"
local chalk_green = u001B .. "[32m"
local chalk_yellow = u001B .. "[33m"
local chalk_close = u001B .. "[0m"

local function assert(what, result)
    assertionCount = assertionCount + 1
    if not seqEqual(result, log) then
        print(string.format(chalk_red ..
            "[FAIL]" ..
            chalk_close ..
            " Assert '%s' to be '" ..
            chalk_yellow .. "%s" .. chalk_close .. "' got '" .. chalk_yellow .. "%s" .. chalk_close .. "' instead.", what
            ,
            table.concat(result, ";"), table.concat(log, ";")))
    else
        print(string.format(chalk_green .. "[PASS]" .. chalk_close .. " Assert '%s'.", what))
        assertionPass = assertionPass + 1
    end
    log = {}
end

local function assertionReport()
    print(string.format("Assertion finished, result: " ..
        (assertionPass == assertionCount and chalk_green or chalk_red) .. "%s/%s" .. chalk_close,
        assertionPass, assertionCount))
end

--endregion

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

local function updateTitle(ctx, key, old, new)
    table.insert(log, string.format("Update [title] ctx:%s, key:%s, old:%s, new:%s", ctx, key, old, new))
end

-- watch change of title
t:bind({ "title" }, updateTitle, context)

t.title = "Something new"

assert("basic watch", { "Update [title] ctx:{context}, key:title, old:This is title, new:Something new" })

local function watchTitleOrValid(key, old, new)
    table.insert(log, string.format("Update [title, valid] key:%s, old:%s, new:%s", key, old, new))
end

-- watch change of title or valid
t:bind({ "title", "valid" }, watchTitleOrValid)

t.valid = false

assert("same value triggers nothing", {})

t.title = "2 listeners on title"

assert("triggers both listeners", {
    "Update [title] ctx:{context}, key:title, old:Something new, new:2 listeners on title",
    "Update [title, valid] key:title, old:Something new, new:2 listeners on title",
})

t:unbind({ "title" }, watchTitleOrValid)

t.title = "AnotherTitle"

assert("Only one responder", { "Update [title] ctx:{context}, key:title, old:2 listeners on title, new:AnotherTitle" })

t.valid = true

assert("valid still working", { "Update [title, valid] key:valid, old:false, new:true" })

t:bind({ "valid" }, updateTitle, context)

t.valid = false

assert("valid 2", {
    "Update [title] ctx:{context}, key:valid, old:true, new:false",
    "Update [title, valid] key:valid, old:true, new:false",
})

t:unbindPaths({ "valid" })

t.valid = true

assert("no one responds on valid change", {})

-- watch change of attrs.strength, attrs.strength is not necessarily not-nil
t:bind({ "attrs.strength" }, function(key, old, new)
    table.insert(log, string.format("Update [attrs.strength] key:%s, old:%s, new:%s", key, old, new))
end)

t.attrs.strength = 13

assert("deeper path", { "Update [attrs.strength] key:strength, old:12, new:13" })

-- watch change of any field in attrs, t.attrs.field = xxx would trigger this
t:bind({ "attrs.*" }, function(key, old, new)
    table.insert(log, string.format("Update [attrs.*] key:%s, old:%s, new:%s", key, old, new))
end)

local attrs = t.attrs
attrs.strength = 15
attrs.stamina = 40
attrs.dexterity = 10

assert("watch on table.any", {
    "Update [attrs.strength] key:strength, old:13, new:15",
    "Update [attrs.*] key:strength, old:13, new:15",
    "Update [attrs.*] key:stamina, old:35, new:40",
    "Update [attrs.*] key:dexterity, old:nil, new:10",
})

attrs.strength = nil

assert("delete value", {
    "Update [attrs.strength] key:strength, old:15, new:nil",
    "Update [attrs.*] key:strength, old:15, new:nil",
})

-- watch change of attrs, t.attrs = xxx would trigger this
t:bind({ "attrs" }, function(key, old, new)
    table.insert(log,
        string.format("Update [attrs] key:%s, old:%s, new:%s", key,
            string.format("dex:%s/sta:%s", old.dexterity, old.stamina),
            string.format("str:%s/dex:%s/sta:%s", new.strength, new.dexterity, new.stamina)))
end)

t.attrs = {
    stamina = 200,
    strength = 300,
    dexterity = 400,
}

assert("assign table", {
    "Update [attrs] key:attrs, old:dex:10/sta:40, new:str:300/dex:400/sta:200",
    "Update [attrs.strength] key:strength, old:nil, new:300",
    "Update [attrs.*] key:strength, old:nil, new:300",
    "Update [attrs.*] key:dexterity, old:10, new:400",
    "Update [attrs.*] key:stamina, old:40, new:200",
})

local function printListItem(item, idx)
    if not item then
        return "nil"
    end
    if idx then
        return string.format("[%s]name:%s,age:%s", idx, item.name, item.age)
    else
        return string.format("name:%s,age:%s", item.name, item.age)
    end
end

local function printList_d(list_d)
    local sb = {}
    for i, v in list_d:ipairs() do
        table.insert(sb, printListItem(v, i))
    end
    return table.concat(sb, " ")
end

local function printList(list)
    local sb = {}
    for i, v in ipairs(list) do
        table.insert(sb, printListItem(v, i))
    end
    return table.concat(sb, " ")
end

t:bind({ "list" }, function(key, old, new)
    table.insert(log, string.format("Update [list] key:%s, old:%s, new:%s", key, printList_d(old), printList(new)))
end)

t.list = {
    {
        name = "Aaron",
        age = 55,
    },
    {
        name = "Bianca",
        age = 98,
    },
    {
        name = "Catherine",
        age = 37,
    },
}

assert("expand list", {
    "Update [list] key:list, old:[1]name:Alice,age:15 [2]name:Bob,age:7, new:[1]name:Aaron,age:55 [2]name:Bianca,age:98 [3]name:Catherine,age:37",
})

t.list = {
    {
        name = "Ashline",
        age = 72
    }
}

assert("shrink list", {
    "Update [list] key:list, old:[1]name:Aaron,age:55 [2]name:Bianca,age:98 [3]name:Catherine,age:37, new:[1]name:Ashline,age:72",
})

t:bind({ "list.*" }, function(key, old, new)
    table.insert(log,
        string.format("Update [list.*] key:%s, old:%s, new:%s", key, printListItem(old), printListItem(new)))
end)

t.list = {
    {
        name = "Alexander",
        age = 61,
    },
    {
        name = "Boris",
        age = 5
    }
}

assert("expand list with index", {
    "Update [list] key:list, old:[1]name:Ashline,age:72, new:[1]name:Alexander,age:61 [2]name:Boris,age:5",
    "Update [list.*] key:1, old:name:Ashline,age:72, new:name:Alexander,age:61",
    "Update [list.*] key:2, old:nil, new:name:Boris,age:5",
})

t.list = {
    {
        name = "Arthas",
        age = 700,
    }
}

assert("shrink list with index", {
    "Update [list] key:list, old:[1]name:Alexander,age:61 [2]name:Boris,age:5, new:[1]name:Arthas,age:700",
    "Update [list.*] key:1, old:name:Alexander,age:61, new:name:Arthas,age:700",
    "Update [list.*] key:2, old:name:Boris,age:5, new:nil",
})

t.list[1] = {
    name = "Albert",
    age = 120
}

assert("list set index", {
    "Update [list.*] key:1, old:name:Arthas,age:700, new:name:Albert,age:120",
})

t.list[2] = {
    name = "Broc",
    age = 1300,
}

assert("list new index", {
    "Update [list.*] key:2, old:nil, new:name:Broc,age:1300",
})

t.list[2] = nil

assert("list delete index", {
    "Update [list.*] key:2, old:name:Broc,age:1300, new:nil",
})

t.list:insert({
    name = "Benedict",
    age = 59
})

t.list:insert({
    name = "Corney",
    age = 11,
})

assert("list insert", {
    "Update [list.*] key:2, old:nil, new:name:Benedict,age:59",
    "Update [list.*] key:3, old:nil, new:name:Corney,age:11"
})

t.list:remove()

assert("list remove", {
    "Update [list.*] key:3, old:name:Corney,age:11, new:nil"
})

t:bind({ "list.*.name" }, function(key, old, new)
    table.insert(log, string.format("Update [list.*.name] key:%s, old:%s, new:%s", key, old, new))
end)

t.list[2].name = "Benjamin"

assert("set list item property", {
    "Update [list.*.name] key:name, old:Benedict, new:Benjamin"
})

t.list[1] = {
    name = "Aliena",
    age = 13
}

assert("change entire list item", {
    "Update [list.*] key:1, old:name:Albert,age:120, new:name:Aliena,age:13",
    "Update [list.*.name] key:name, old:Albert, new:Aliena"
})

t.list = {
    {
        name = "Alen",
        age = 34,
    },
    {
        name = "Bjarne",
        age = 83,
    },
    {
        name = "Christopher",
        age = 76,
    },
    {
        name = "Dolores",
        age = 999,
    },
}

assert("assign entire list", {
    "Update [list] key:list, old:[1]name:Aliena,age:13 [2]name:Benjamin,age:59, new:[1]name:Alen,age:34 [2]name:Bjarne,age:83 [3]name:Christopher,age:76 [4]name:Dolores,age:999",
    "Update [list.*] key:1, old:name:Aliena,age:13, new:name:Alen,age:34",
    "Update [list.*] key:2, old:name:Benjamin,age:59, new:name:Bjarne,age:83",
    "Update [list.*] key:3, old:nil, new:name:Christopher,age:76",
    "Update [list.*] key:4, old:nil, new:name:Dolores,age:999",
    "Update [list.*.name] key:name, old:Aliena, new:Alen",
    "Update [list.*.name] key:name, old:Benjamin, new:Bjarne",
})

t:bind({ "*" }, function(key, old, new)
    table.insert(log, string.format("Update [*] key:%s, old:%s, new:%s", key, old, new))
end)

t.list[1].name = "Amanda"
t.valid = false
t.title = "Thank you"

assert("everything", {
    "Update [list.*.name] key:name, old:Alen, new:Amanda",
    "Update [title] ctx:{context}, key:title, old:AnotherTitle, new:Thank you",
    "Update [*] key:valid, old:true, new:false",
    "Update [*] key:title, old:AnotherTitle, new:Thank you",
})

t:resetValue()

t.title = "Totally new"

assert("reset values", {
    "Update [title] ctx:{context}, key:title, old:This is title, new:Totally new",
    "Update [*] key:title, old:This is title, new:Totally new"
})

assertionReport()
