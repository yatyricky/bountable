local Bountable = require("bountable")

local t = Bountable.new({
    list = {
    },
    albert = nil
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
        print("update item @", key, old, new)
    elseif old then
        print("delete item @", key)
    elseif new then
        print("new item @", key, new)
    end
end)

-- t:bind({ "list.*.*" }, function(key, oldValue, newValue)
--     print(string.format("Update [list.*.*] key:%s, old:%s, new:%s", key, oldValue, newValue))
-- end)

t:bind({ "albert" }, function(key, old, new)
    print("update [albert]", key, old, new)
end)

t.list = {
    "Alice",
    "Bob",
    "Chris"
}
t.albert = "lorem"
print("--------------------------------")
t:reset()
t.list = {
    "Alice",
    "Brand",
    "Chris"
}
t.albert = "ipsum"

print("--------------------------------")
t.list = {
    "Alice",
    "Chris"
}

print("--------------------------------")
