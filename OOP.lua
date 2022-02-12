--  setfenv 在Lua5.1之后不存在
if not setfenv then
    local function findenv(f)
        local level = 1
        --遍历拿到上文
        repeat
            local name, value = debug.getupvalue(f, level)
            if name == "_ENV" then
                return level, value
            end
            level = level + 1
        until name == nil
        return nil
    end
    ---Version: >= Lua5.2
    getfenv = function(f)
        return (select(2, findenv(f)) or _G)
    end
    ---Version: >= Lua5.2
    setfenv = function(f, t)
        local level = findenv(f)
        if level then
            debug.setupvalue(f, level, t)
        end
        return f
    end
end
--递归输出表
foreachPrintTable = function(table)
    for key, value in pairs(table) do
        if _G["type"](value) == "table" then
            foreachPrintTable(value)
        end
        print(key, value)
    end
end
---输出函数环境
------@param func function
printEnv = function(func)
    local env = getfenv(func)
    foreachPrintTable(env)
end
---浅拷贝表，不包含元表
---@param target table
function table.copy(target)
    local clone = {}
    for key, value in pairs(target) do
        clone[key] = value
    end
    return clone
end
---深拷贝表，递归设置元表
---@param target table
function table.clone(target)
    if target == nil then
        return nil
    end
    local clone = {}
    for k, v in pairs(target) do
        if _G["type"](v) == "table" then
            clone[k] = table.clone(v)
        else
            clone[k] = v
        end
    end
    setmetatable(clone, table.clone(getmetatable(target)))
    return clone
end
---混合表，如果存在重复键，则使用目标表的键值
---@param origin table
---@param target table
function table.blend(origin, target)
    for key, value in pairs(target) do
        origin[key] = value
    end
end

---### Lua 面向对象编程
---封装、继承、多态的基本内容：
--- * `extends`: table------------继承至父类
--- * `public`: table-------------公有访问属性
--- * `protected`: table---------保护访问属性
--- * `private`: table------------私有访问属性
--- * `base`: table----------------返回父类的 public 和 protected 成员
--- * `new`: function--------------返回本类的一个实例
--- * `ctor`: function------------构造函数，默认存在一个没有任何逻辑的构造函数
--- ---
--- ### 一些注意事项
--- 1. 在所有语句块中，`new` 出来的实例对象都应该被声明为 `local` 变量；
--- 2. 不要尝试将实例对象加入到 `_G` 或者 `_ENV` 中；
--- 3. 使用 `base`调用方法 和使用 `new` 创建实例时，请使用 `base:xxx` 或 `xxx:new()`；
--- 4. 对实例中可访问的成员变量( public 中的成员变量) 赋值时，若类型不一致，则报错；
--- 5. 在 class 语句块外，无法获取不可访问的成员变量（不存在或者存在于 private/protected 中的成员变量）；
--- 6. 无法为实例中不可访问的成员变量赋值；
function class(...)
    --传入的数据表
    local classData = ...
    --类成员表
    local membersTable = {}
    --最终返回类表
    local classTable = {}

    --设置new方法
    function classTable:new(...)
        local instance = {}
        setmetatable(instance,{
            __index = function(_, key)
                --如果是函数，则增加自己的变量到环境中
                local data = self[key]
                if data then
                    if _G["type"](data) == "function" then
                        local blendEnv = {}
                        for key, value in pairs(instance) do
                            blendEnv[key] = value
                        end
                        setmetatable(blendEnv, {
                            __index = getfenv(data),
                            __newindex = function (_, key, value)
                                instance[key] = value
                            end
                        })
                        setfenv(data, blendEnv)
                    end
                else
                    error('尝试获取未定义或无法访问的成员变量："' .. key .. '"！',2)
                end
                return data
            end,
            __newindex = function (table,key,value)
            local members = membersTable["public"]
                if members then
                    if members[key] then
                        local originType = _G["type"](members[key])
                        if (_G["type"](value) ~= originType) then
                            error("错误的赋值，类型无法匹配！"..key.."："..originType,2)
                        else
                            rawset(table,key,value)
                            return
                        end
                    else
                        error('尝试为未定义或无法访问的变量："' .. key .. '" 赋值！',2)
                    end
                end
            end
            })

        local ctor = getmetatable(self)["__members"]["ctor"]
        setfenv(classData["ctor"],instance)
        ctor(getfenv(ctor),...)

        local result = instance
        return result
    end

    --构建class,继承父类，拷贝父类所有 public 和 protected 成员
    --并拷贝自身所有成员
    local function BuildClass(inTable, outTable)
        local parent = inTable["extends"]
        if parent then
            local parentMember = getmetatable(parent)["__members"]
            --拷贝父类 public 成员
            if parentMember["public"] and parentMember then
                -- classTable.base = {}
                -- rawset(classTable,classTable.base,parentMember["public"])
                outTable["public"] = table.copy(parentMember["public"])
            end
            --拷贝父类 protected 成员
            if parentMember["protected"] and parentMember then
                outTable["protected"] = table.copy(parentMember["protected"])
            end
        end
        local publicTable = inTable["public"]
        local protectedTable = inTable["protected"]
        local privateTable = inTable["private"]
        local ctor = inTable["ctor"]
        --拷贝自身成员
        if publicTable then
            if outTable["public"] == nil then
                outTable["public"] = {}
            end
            table.blend(outTable["public"], publicTable)
        end
        if protectedTable then
            if outTable["protected"] == nil then
                outTable["protected"] = {}
            end
            table.blend(outTable["protected"], protectedTable)
        end
        if privateTable then
            if outTable["private"] == nil then
                outTable["private"] = {}
            end
            table.blend(outTable["private"], privateTable)
        end
        if ctor then
            outTable["ctor"] = function (env,...)
                local extens = classData["extends"]
                if extens then
                    local constructor = extens["ctor"]
                    if constructor then
                        constructor(...)
                    end
                end
                classData["ctor"](...)
            end
        else
            outTable["ctor"] = function (env,...)
                local extens = classData["extends"]
                if extens then
                    local constructor = extens["ctor"]
                    if constructor then
                        constructor(...)
                    end
                end
            end
        end
    end

    BuildClass(classData, membersTable)

    --用于拷贝public、private、protected的成员
    local CopyMembers = function (outTable)
        if membersTable["public"] then
            for k, v in pairs(membersTable["public"]) do
                outTable[k] = v
            end
        end
        if membersTable["protected"] then
            for k, v in pairs(membersTable["protected"]) do
                outTable[k] = v
            end
        end
        if membersTable["private"] then
            for k, v in pairs(membersTable["private"]) do
                outTable[k] = v
            end
        end
    end

    --为本类成员建立本地变量表
    --新建一个本函数环境下的G表
    local memberEnv = {}
    setmetatable(memberEnv, {__index = _G})
    CopyMembers(memberEnv)

    --设置base
    if classData["extends"] then
        local baseEnv =  {}
        memberEnv["base"] = {}

        local parent = getmetatable(classData["extends"])
        local parentMember = parent["__members"]
        if parentMember["public"] then
            table.blend(baseEnv,parentMember["public"])
        end
        if parentMember["protected"] then
            table.blend(baseEnv,parentMember["protected"])
        end

        baseEnv["ctor"] = parentMember["ctor"]
        setfenv(baseEnv["ctor"],getfenv(parentMember["ctor"]))
        setmetatable(baseEnv,{__index = _G})

        setmetatable(memberEnv["base"],{
            __index = function (_,key)
                local data = baseEnv[key]
                if data then
                    if _G["type"](data) == "function" then
                        --需要在方法调用后重新设置回原来的环境
                        local func = function(_ , ...)
                            local beforeEnv = getfenv(data)
                                classData["extends"][key](...)
                            setfenv(data,beforeEnv)
                        end
                        return func
                    end
                    return data
                else
                    error("尝试访问父类不存在或不可访问的成员变量："..key,2)
                end
            end
        })
    end

    --设置 classTable 元表
    setmetatable(classTable,{

        __env = memberEnv,
        __members = membersTable,
        --Get时只从 public 中获得
        __index = function(table, key)
            if key == "ctor" then
                return membersTable["ctor"]
            end
            local members = membersTable["public"]
            if members then
                local data = members[key]
                if data then
                    if _G["type"](data) == "function" then

                        --如果子类没有重写方法，则环境以父类为准
                        local parent = classData["extends"]

                        if parent then
                            local public = classData["public"]
                            local protected = classData["protected"]

                            --如果子类了重写方法，则环境以子类为准
                            if (public and public[key]) or (protected and protected[key]) then
                                setfenv(data, memberEnv)
                            else
                                local blendEnv = {}
                                setmetatable(blendEnv,{__index = getmetatable(parent)["__env"]})
                                CopyMembers(blendEnv)
                                setfenv(data, blendEnv)
                            end
                        else
                            setfenv(data, memberEnv)
                        end
                    end
                    return data
                else
                    if _G[key] then
                        return _G[key]
                    else
                        error('尝试获取未定义或无法访问的成员变量："' .. key .. '"！',2)
                    end
                    return nil
                end
            end
        end,
        --Set时只可以对 public 中的变量赋值
        __newindex = function(table, key, value)
            local members = membersTable["public"]
            if members then
                if members[key] then
                    local originType = _G["type"](members[key])
                    if (_G["type"](value) ~= originType) then
                        error("错误的赋值，类型无法匹配！"..key.."："..originType,2)
                    else
                        members[key] = value
                        return
                    end
                else
                    error('尝试为未定义或无法访问的变量："' .. key .. '" 赋值！',2)
                end
            end
        end
    })

    return classTable
end
