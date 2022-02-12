# OOP.lua

封装、继承、多态的基本内容：
* `extends`: table---------继承至父类
* `public`: table----------公有访问属性
* `protected`: table-------保护访问属性
* `private`: table---------私有访问属性
* `base`: table------------返回父类的 public 和 protected 成员
* `new`: function----------返回本类的一个实例
* `ctor`: function---------默认存在一个无逻辑的构造函数

### 一些注意事项
1. 在所有语句块中，`new` 出来的实例对象都应该被声明为 `local` 变量；
2. 不要尝试将实例对象加入到 `_G` 或者 `_ENV` 中；
3. 使用 `base`调用方法 和使用 `new` 创建实例时，请使用 `base:xxx` 或 `xxx:new()`；
4. 对实例中可访问的成员变量( public 中的成员变量) 赋值时，若类型不一致，则报错；
5. 在 class 语句块外，无法获取不可访问的成员变量（不存在或者存在于 private/protected 中的成员变量）；
6. 无法为实例中不可访问的成员变量赋值；

## Usage

```lua
GrandParent = class
{
    private = 
    {
        name = "GrandParent"
    },
    public =
    {
        Func = function ()
            print("this is GrandParent")
            print(name)
        end
    }
}
Parent = class
{
    extends = GrandParent,
    private = 
    {
        name = "Parent"
    },
    public =
    {
        Func = function ()
            print("this is Parent")
            base:Func()
            print(name)
        end
    }
}
Child = class
{
    extends = Parent,
    private = 
    {
        name = "Child"
    },
    public =
    {
        Func = function ()
            print("this is Child")
            base:Func()
            print(name)
        end
    }
}

child = Child:new()
child:Func()
```
## OutPut

```
this is Child
this is Parent
this is GrandParent
GrandParent
Parent
Child
```
