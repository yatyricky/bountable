local Bountable = require("bountable")

local t = Bountable.new({
    list = {
        -- {
        --     category = "vip",
        --     items = {1,2,3},
        -- },
    },
})

function table.sequenceEqual(s1, s2)
    local n1 = s1 == nil
    local n2 = s2 == nil
    if n1 and n2 then
        return true
    end
    if n1 or n2 then
        return false
    end
    local len = #s1
    if len ~= #s2 then
        return false
    end
    for i = 1, len do
        if s1[i] ~= s2[i] then
            return false
        end
    end
    return true
end

local function printCate(d)
    if not d then
        return "nil"
    end
    return string.format("[%s](%s)", d.category, table.concat(Bountable.getDirectRaw(d.items), ","))
end

t:bind({ "list" }, function(key, oldValue, newValue)
    local l1 = oldValue:len()
    local l2 = #newValue
    if l1 == l2 then
        return
    end
    print("len changed", l1, l2)
end)

t:bind({ "list.*" }, function(key, old, new)
    if old and new then
        if old.category ~= new.category then
            print("cate change@", key, old.category, new.category)
        end
        if not table.sequenceEqual(Bountable.getDirectRaw(old.items), Bountable.getDirectRaw(new.items)) then
            print("items change@", key, printCate(old), printCate(new))
        end
    elseif old then
        print("delete item @", key)
    elseif new then
        print("new item @", key, printCate(new))
    end
end)

-- t:bind({ "list.*.*" }, function(key, oldValue, newValue)
--     print(string.format("Update [list.*.*] key:%s, old:%s, new:%s", key, oldValue, newValue))
-- end)

t.list = {
    {
        category = "vip",
        items = { 1, 2, 3 },
    },
    {
        category = "promo",
        items = { 14, 15 },
    },
    {
        category = "res",
        items = { 21, 22, 23 },
    },
}
print("--------------------------------")

t.list = {
    {
        category = "vip",
        items = { 1, 2, 3 },
    },
    {
        category = "promo",
        items = { 14, 16 },
    },
    {
        category = "res",
        items = { 21, 22, 23 },
    },
}
print("--------------------------------")

t.list = {
    {
        category = "vip",
        items = { 1, 2, 3 },
    },
    {
        category = "res",
        items = { 21, 22, 23 },
    },
}

print("--------------------------------")

t.list = {
    {
        category = "vip",
        items = { 1, 2, 3 },
    },
    {
        category = "promo",
        items = { 11, 12 },
    },
    {
        category = "res",
        items = { 21, 22, 29 },
    },
}

print("--------------------------------")
