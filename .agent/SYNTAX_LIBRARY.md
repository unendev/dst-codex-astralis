# 📚 饥荒 Mod 实测语法与接口库 (SYNTAX_LIBRARY.md)

> **守门铁律**：**本文档是全项目代码编写的唯一法定依据。**
> 任何写进 Mod 的代码，必须在此文档中具备**经过成熟 Mod 检验的真实出处（注明 Mod ID、文件与行号）**。禁止任何未经登记的代码进入项目！

---

## 📖 目录索引

1. [【范式 A】客机道具右键 -> 服务端响应 -> 专属回传唤起本地 UI](#1-范式-a客机道具右键---服务端响应---专属回传唤起本地-ui)
2. [【范式 B】客户端 UI 按钮交互 -> 弹窗输入文本 -> 列表局部刷新](#2-范式-b客户端-ui-按钮交互---弹窗输入文本---列表局部刷新)
3. [【范式 C】C/S 双向 RPC 数据通信与全局仓储模型](#3-范式-c-cs-双向-rpc-数据通信与全局仓储模型)

---

## 1. 【范式 A】客机道具右键 -> 服务端响应 -> 专属回传唤起本地 UI

### 1.1 动作注册与双端动作收集 (ComponentAction)
- **实测出处**：`Klei 官方引擎 scripts/componentactions.lua:3108-3201` + `石化书 Mod 1695519788`
- **真实代码切片**：
```lua
-- 1. 注册无专属职业限制的独立 Action
local ATLAS_READ_ACTION = AddAction("ATLAS_READ", STRINGS.ACTIONS.READ or "阅读", function(act)
    local target = act.invobject or act.target
    if target and target.components.book and act.doer then
        return target.components.book:OnRead(act.doer)
    end
    return true
end)
ATLAS_READ_ACTION.mount_valid = true

-- 2. 绑定双端人类通用状态机 SGwilson / SGwilson_client
AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(ACTIONS.ATLAS_READ, "book"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(ACTIONS.ATLAS_READ, "book"))

-- 3. 以真实的 "book" 为组件索引，向物品栏及手持装备注入右键动作
AddComponentAction("INVENTORY", "book", function(inst, doer, actions, right)
    if right and inst:HasTag("atlas_book") then
        table.insert(actions, ACTIONS.ATLAS_READ)
    end
end)
AddComponentAction("EQUIPPED", "book", function(inst, doer, actions, right)
    if right and inst:HasTag("atlas_book") then
        table.insert(actions, ACTIONS.ATLAS_READ)
    end
end)
```

### 1.2 服务端识别特定客机并定向发送打开 UI 的 RPC (Targeted Client RPC)
- **实测出处**：`万象书原版 Mod 3555025039 / modmain.lua`
- **真实代码切片**：
```lua
-- 服务端监听实体阅读事件，定向推给当前操作该动作的客机 userid
AddPrefabPostInit("atlas_book", function(inst)
    if GLOBAL.TheWorld.ismastersim then
        inst:ListenForEvent("atlas_book_read", function(inst, data)
            if data and data.reader and data.reader.userid then
                local rpc_id = GetClientModRPC(ATLAS_RPC_NAMESPACE, ATLAS_RPC_OPEN_UI)
                if rpc_id then
                    SendModRPCToClient(rpc_id, data.reader.userid)
                end
            end
        end)
    end
end)
```

---

## 2. 【范式 B】客户端 UI 按钮交互 -> 弹窗输入文本 -> 列表局部刷新

### 2.1 客户端安全打开本地专属 UI 窗口 (HUD PushScreen)
- **实测出处**：`万象书原版 Mod 3555025039 / modmain.lua:179-220`
- **真实代码切片**：
```lua
AddClassPostConstruct("screens/playerhud", function(self)
    function self:OpenAtlasBook()
        if GLOBAL.TheFrontEnd:GetActiveScreen() and GLOBAL.TheFrontEnd:GetActiveScreen().name == "AtlasBookUI" then
            return
        end
        local AtlasBookUI = require("widgets/atlasbook_ui")
        if AtlasBookUI and GLOBAL.ThePlayer then
            GLOBAL.TheFrontEnd:PushScreen(AtlasBookUI(GLOBAL.ThePlayer))
        end
    end
end)
```

### 2.2 [待填充] 客户端安全输入文本弹窗与按钮回调
- **当前状态**：`[待从成熟工坊记事本/UI Mod 中定向提取填入]`
- **待填槽位**：按钮 `SetOnClick` 标准写法、`TextEdit` 或 `writeables` 弹窗标准写法。

---

## 3. 【范式 C】C/S 双向 RPC 数据通信与全局仓储模型

### 3.1 客户端数据仓储与服务端增删改查
- **实测出处**：`万象书原版 Mod 3555025039`
- **真实代码切片**：
```lua
-- 客户端全局仓储
GLOBAL.ATLAS_CLIENT_DATA = { team_tasks = {}, personal_tasks = {} }

-- 客户端向服务端发起动作 RPC
local add_rpc = GetModRPC(ATLAS_RPC.NAMESPACE, ATLAS_RPC.ADD_TASK)
if add_rpc then
    SendModRPCToServer(add_rpc, task_text, task_type)
end
```
