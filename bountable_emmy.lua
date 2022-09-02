---@class Bountable
local m = {}

---@param tab table
---@return Bountable
function m.new(tab) end

---绑定
---@generic TContext
---@overload fun(paths: string[], callback: (fun(key: string, oldValue: any, newValue: any): void)): void
---@param paths string[] 需要绑定的路径，使用点.连接，可使用*来绑定任意。比如 "title", "attrs.stamina", "list.*", "list.*.name"
---@param callback (fun(key: string, oldValue: any, newValue: any): void) | (fun(context: TContext, key: string, oldValue: any, newValue: any): void)
---@param context TContext 上下文，如果指定，会作为回调的第一个参数
function m:bind(paths, callback, context) end

---解除绑定
---@generic TContext
---@overload fun(paths: string[], callback: (fun(key: string, oldValue: any, newValue: any): void)): void
---@param paths string[]
---@param callback (fun(key: string, oldValue: any, newValue: any): void) | (fun(context: TContext, key: string, oldValue: any, newValue: any): void)
---@param context TContext
function m:unbind(paths, callback, context) end

---解除指定路径下的所有绑定
---@param paths string[]
function m:unbindPaths(paths) end

---解除指定上下文的所有绑定
---@param context any
function m:unbindContext(context) end

---插入一个值，只能对列表类型的table使用，参数同table.insert
---@overload fun(value: any)
---@param pos number pos
---@param value any value
function m:insert(pos, value) end

---移除一个值，只能对列表类型的table使用，参数同table.insert
---@overload fun()
---@param pos number pos
function m:remove(pos) end

---获取列表长度，只能对列表类型的table使用
---@return number
function m:len() end

---同pairs
---@generic K, V
---@return fun(t: table<K, V>): K, V
function m:pairs() end

---同ipairs
---@generic V
---@return fun(t: V[], i: number): number, V, number
function m:ipairs() end
