local ipairs = ipairs
local pairs = pairs
local type = type
local print = print
local next = next
local setmetatable = setmetatable
local t_insert = table.insert
local t_remove = table.remove
local s_format = string.format
local s_gmatch = string.gmatch

local str_table = "table"
local str_asterisk = "*"
local str_static = "s"
local str_period = "."
local str_split = "([^%s]+)"

local function isEmpty(t)
    return t == nil or next(t) == nil
end

---@generic T
---@param tab T
---@return T
local function shallow(tab)
    local t = {}
    for key, value in pairs(tab) do
        t[key] = value
    end
    return t
end

local function split(inputstr, sep)
    local t = {}
    for str in s_gmatch(inputstr, s_format(str_split, sep)) do
        t_insert(t, str)
    end
    return t
end

---@type Bountable
local cls = {}
local mt = {}

function mt.__index(t, k)
    return t.__d[k]
end

local function mtLen(t)
    return #t.__d
end

local function mtPairs(t)
    return pairs(t.__d)
end

local function mtIpairs(t)
    return ipairs(t.__d)
end

local function emit(t, k, v, old)
    local tab = t.__l[k]
    if tab then
        for func, contexts in pairs(tab) do
            for ctx, _ in pairs(contexts) do
                if ctx == str_static then
                    func(k, old, v)
                else
                    func(ctx, k, old, v)
                end
            end
        end
    end
end

--region bind

local function doBind(listeners, key, call, ctx)
    local tab = listeners[key]
    if not tab then
        tab = {}
        listeners[key] = tab
    end
    local contexts = tab[call]
    if not contexts then
        contexts = {}
        tab[call] = contexts
    end
    if contexts[ctx] then
        print("Double binding")
    end
    contexts[ctx] = 1
end

local function bindRecursive(this, ps, call, ctx)
    local old = shallow(ps)
    local p = t_remove(ps, 1)
    if #ps == 0 then
        if p == str_asterisk then
            for k, _ in pairs(this.__d) do
                doBind(this.__l, k, call, ctx)
            end
            t_insert(this.__b, { old, call, ctx })
        else
            doBind(this.__l, p, call, ctx)
        end
    else
        if p == str_asterisk then
            for _, v in pairs(this.__d) do
                bindRecursive(v, shallow(ps), call, ctx)
            end
            t_insert(this.__b, { old, call, ctx })
        else
            bindRecursive(this.__d[p], shallow(ps), call, ctx)
        end
    end
end

local function bind(this, paths, call, context)
    local ctx = context or str_static
    for _, path in pairs(paths) do
        local p = split(path, str_period)
        bindRecursive(this, p, call, ctx)
    end
end

--endregion

--region unbind full

local function doUnbind(listeners, key, call, ctx)
    local tab = listeners[key]
    if not tab then
        print("Cannot unbind key", key)
        return
    end
    local contexts = tab[call]
    if not contexts then
        print("Cannot unbind callback", call)
        return
    end
    if not contexts[ctx] then
        print("Cannot unbind context", ctx)
        return
    end
    contexts[ctx] = nil
    if isEmpty(contexts) then
        tab[call] = nil
        if isEmpty(tab) then
            listeners[key] = nil
        end
    end
end

local function seqEqual(seq1, seq2)
    if seq1 == nil and seq2 == nil then
        return true
    end
    if seq1 == nil or seq2 == nil then
        return false
    end
    local len = #seq1
    if len ~= #seq2 then
        return false
    end
    for i = 1, len do
        if seq1[i] ~= seq2[i] then
            return false
        end
    end
    return true
end

local function unbindArgs(this, old, call, ctx)
    local b = this.__b
    for i = #b, 1, -1 do
        local it = b[i]
        if seqEqual(it[1], old) and it[2] == call and it[3] == ctx then
            t_remove(b, i)
        end
    end
end

local function unbindRecursive(this, ps, call, ctx)
    local old = shallow(ps)
    local p = t_remove(ps, 1)
    if #ps == 0 then
        if p == str_asterisk then
            for k, _ in pairs(this.__d) do
                doUnbind(this.__l, k, call, ctx)
            end
            unbindArgs(this, old, call, ctx)
        else
            doUnbind(this.__l, p, call, ctx)
        end
    else
        if p == str_asterisk then
            for _, v in pairs(this.__d) do
                unbindRecursive(v, shallow(ps), call, ctx)
            end
            unbindArgs(this, old, call, ctx)
        else
            unbindRecursive(this.__d[p], shallow(ps), call, ctx)
        end
    end
end

local function unbind(this, paths, call, context)
    local ctx = context or str_static
    for _, path in pairs(paths) do
        local p = split(path, str_period)
        unbindRecursive(this, p, call, ctx)
    end
end

--endregion

--region unbind paths

local function unbindArgsPaths(this, old)
    local b = this.__b
    for i = #b, 1, -1 do
        local it = b[i]
        if seqEqual(it[1], old) then
            t_remove(b, i)
        end
    end
end

local function doUnbindPaths(listeners, key)
    local tab = listeners[key]
    if not tab then
        print("Cannot unbind key", key)
        return
    end
    listeners[key] = nil
end

local function unbindPathsRecursive(this, ps)
    local old = shallow(ps)
    local p = t_remove(ps, 1)
    if #ps == 0 then
        if p == str_asterisk then
            for k, _ in pairs(this.__d) do
                doUnbindPaths(this.__l, k)
            end
            unbindArgsPaths(this, old)
        else
            doUnbindPaths(this.__l, p)
        end
    else
        if p == str_asterisk then
            for _, v in pairs(this.__d) do
                unbindPathsRecursive(v, shallow(ps))
            end
            unbindArgsPaths(this, old)
        else
            unbindPathsRecursive(this.__d[p], shallow(ps))
        end
    end
end

local function unbindPaths(this, paths)
    for _, path in pairs(paths) do
        local p = split(path, str_period)
        unbindPathsRecursive(this, p)
    end
end

--endregion

--region unbind context

local function unbindContext(this, context)
    context = context or str_static
    local l = this.__l
    for key, tab in pairs(l) do
        for call, contexts in pairs(tab) do
            contexts[context] = nil
            if isEmpty(contexts) then
                tab[call] = nil
            end
        end
        if isEmpty(tab) then
            l[key] = nil
        end
    end
    for _, value in pairs(this.__d) do
        if type(value) == str_table then
            unbindContext(value, context)
        end
    end
    local b = this.__b
    for i = #b, 1, -1 do
        local it = b[i]
        if it[3] == context then
            t_remove(b, i)
        end
    end
end

--endregion

mt.__newindex = function(t, k, v)
    local d = t.__d
    local old = d[k]
    if v == old then
        return
    end

    local l = t.__l
    if v == nil then
        -- delete
        d[k] = nil
        emit(t, k, d[k], old)
        l[k] = nil
    else
        local tp = type(v)
        if old == nil then
            d[k] = tp == str_table and cls.new(v) or v
            for _, args in ipairs(t.__b) do
                local newPs = shallow(args[1])
                newPs[1] = k
                bindRecursive(t, newPs, args[2], args[3])
            end
            emit(t, k, d[k], old)
        else
            if tp == str_table then
                emit(t, k, v, old)
                if old then
                    local oldKeys = {}
                    for kk, _ in old:pairs() do
                        oldKeys[kk] = 1
                    end
                    for kk, vv in pairs(v) do
                        mt.__newindex(d[k], kk, vv)
                        oldKeys[kk] = nil
                    end
                    for kk, _ in pairs(oldKeys) do
                        mt.__newindex(d[k], kk, nil)
                    end
                else
                    for kk, vv in pairs(v) do
                        mt.__newindex(d[k], kk, vv)
                    end
                end
            else
                d[k] = v
                emit(t, k, d[k], old)
            end
        end
    end
end

local function insert(this, arg1, arg2)
    local d = this.__d
    local key
    local item
    if arg2 == nil then
        key = #d + 1
        item = arg1
    else
        key = arg1
        item = arg2
    end

    local old = d[key]
    local tp = type(item)
    t_insert(this.__l, key, nil)
    if tp == str_table then
        t_insert(d, key, cls.new(item))
        for _, args in ipairs(this.__b) do
            local newPs = shallow(args[1])
            newPs[1] = key
            bindRecursive(this, newPs, args[2], args[3])
        end
    else
        t_insert(d, key, item)
        for _, args in ipairs(this.__b) do
            doBind(this.__l, key, args[2], args[3])
        end
    end
    emit(this, key, d[key], old)
end

local function remove(this, arg1)
    local d = this.__d
    local key
    if arg1 == nil then
        key = #d
    else
        key = arg1
    end

    local removed = t_remove(d, key)
    emit(this, key, d[key], removed)
    t_remove(this.__l, key)
end

local template = {
    bind = bind,
    unbind = unbind,
    unbindPaths = unbindPaths,
    unbindContext = unbindContext,
    insert = insert,
    remove = remove,
    len = mtLen,
    pairs = mtPairs,
    ipairs = mtIpairs,
}

local function clone(tab)
    local t = {}
    for key, value in pairs(tab) do
        if template[key] then
            print("Warn: Bountable can't use key", key)
        else
            local tp = type(value)
            if tp == str_table then
                t[key] = cls.new(value)
            else
                t[key] = value
            end
        end
    end
    return t
end

function cls.new(model)
    local inst = shallow(template)
    inst.__l = {} -- listeners
    inst.__b = {} -- binding args
    inst.__d = clone(model) -- raw data
    return setmetatable(inst, mt)
end

function cls.getDirectRaw(data)
    if type(data) == "table" then
        if data.__d then
            return data.__d
        else
            return data
        end
    else
        return data
    end
end

return cls
