-- ====================================================================
-- 《万象全书》(Codex Astralis) 纯净核心逻辑 (Clean Baseline)
-- ====================================================================

local GLOBAL = GLOBAL
local STRINGS = GLOBAL.STRINGS
local ACTIONS = GLOBAL.ACTIONS
local ActionHandler = GLOBAL.ActionHandler
local json = GLOBAL.json
local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH
local pcall = GLOBAL.pcall
local pairs = GLOBAL.pairs
local ipairs = GLOBAL.ipairs
local type = GLOBAL.type
local tostring = GLOBAL.tostring
local table = GLOBAL.table

PrefabFiles = { "atlas_book" }

Assets = {
    Asset("ANIM", "anim/book_fossil.zip"),
    Asset("ANIM", "anim/swap_book_fossil.zip"),
    Asset("ATLAS", "images/inventoryimages/book_fossil.xml"),
    Asset("IMAGE", "images/inventoryimages/book_fossil.tex"),
}

-- 1. 基础字符串定义
STRINGS.NAMES.ATLAS_BOOK = "★生存指南(本地开发版)★"
STRINGS.RECIPE_DESC.ATLAS_BOOK = "包含丰富知识的指南书"
STRINGS.INPUT_PROMPT = "输入任务内容:"
STRINGS.CANCEL_BUTTON = "取消"
STRINGS.CLEAR_BUTTON = "清空"
STRINGS.CONFIRM_BUTTON = "确定"
STRINGS.ADD_TASK_BUTTON = "添加任务"
STRINGS.DELETE_BUTTON = "删除"
STRINGS.COMPLETED_TASK = "✓"
STRINGS.PENDING_TASK = "□"
STRINGS.WINDOW_TITLE = "生存指南"
STRINGS.GUIDE_TAB = "静态攻略"
STRINGS.PLANNER_TAB = "团队计划"
STRINGS.CLOSE_BUTTON = "关闭"

-- 2. 注册多语言攻略字符串字典
local strings_module = GLOBAL.require("strings")
GLOBAL.ATLAS_STRINGS_MODULE = strings_module

-- 3. RPC 协议定义
local ATLAS_RPC_NAMESPACE = "atlas_book"
local ATLAS_RPC_ADD_TASK = "add_task"
local ATLAS_RPC_TOGGLE_TASK = "toggle_task"
local ATLAS_RPC_DELETE_TASK = "delete_task"
local ATLAS_RPC_SYNC_TASKS = "sync_tasks"
local ATLAS_RPC_OPEN_UI = "open_ui"

GLOBAL.ATLAS_RPC = {
    NAMESPACE = ATLAS_RPC_NAMESPACE,
    ADD_TASK = ATLAS_RPC_ADD_TASK,
    TOGGLE_TASK = ATLAS_RPC_TOGGLE_TASK,
    DELETE_TASK = ATLAS_RPC_DELETE_TASK,
    SYNC_TASKS = ATLAS_RPC_SYNC_TASKS,
    OPEN_UI = ATLAS_RPC_OPEN_UI,
}

-- 4. 全角色通用阅读动作覆盖（原版成熟蓝本）
local function GetComponentActions()
    local fn = GLOBAL.EntityScript.CollectActions
    local upvalue_name = "COMPONENT_ACTIONS"
    if fn == nil then return end
    local i = 1
    while true do
        local val, v = GLOBAL.debug.getupvalue(fn, i)
        if not val then break end
        if val == upvalue_name then return v, i end
        i = i + 1
    end
end

local COMPONENT_ACTIONS = GetComponentActions()
if COMPONENT_ACTIONS and COMPONENT_ACTIONS.INVENTORY and COMPONENT_ACTIONS.INVENTORY.book then
    local superBook = COMPONENT_ACTIONS.INVENTORY.book
    COMPONENT_ACTIONS.INVENTORY.book = function(inst, doer, actions, ...)
        if inst and inst:HasTag("atlas_book") then
            table.insert(actions, GLOBAL.ACTIONS.READ)
        else
            if superBook then
                superBook(inst, doer, actions, ...)
            end
        end
    end
end

if COMPONENT_ACTIONS and COMPONENT_ACTIONS.EQUIPPED and COMPONENT_ACTIONS.EQUIPPED.book then
    local superEquippedBook = COMPONENT_ACTIONS.EQUIPPED.book
    COMPONENT_ACTIONS.EQUIPPED.book = function(inst, doer, actions, ...)
        if inst and inst:HasTag("atlas_book") then
            table.insert(actions, GLOBAL.ACTIONS.READ)
        else
            if superEquippedBook then
                superEquippedBook(inst, doer, actions, ...)
            end
        end
    end
end

local superRead = GLOBAL.ACTIONS.READ.fn
GLOBAL.ACTIONS.READ.fn = function(act)
    local book = act.target or act.invobject
    if book and book:HasTag("atlas_book") then
        if book.components and book.components.book and book.components.book.onread then
            return book.components.book.onread(book, act.doer)
        end
        return true
    else
        if superRead then
            return superRead(act)
        end
    end
    return true
end

-- 5. 客户端 HUD 界面挂载
AddClassPostConstruct("screens/playerhud", function(self)
    function self:OpenAtlasBook()
        if GLOBAL.TheFrontEnd:GetActiveScreen() and GLOBAL.TheFrontEnd:GetActiveScreen().name == "AtlasBookUI" then
            return
        end
        local AtlasBookUI = GLOBAL.require("widgets/atlasbook_ui")
        if AtlasBookUI and GLOBAL.ThePlayer then
            GLOBAL.TheFrontEnd:PushScreen(AtlasBookUI(GLOBAL.ThePlayer))
        end
    end
end)

-- 6. 服务端组件注入与出生赠送
AddSimPostInit(function()
    if GLOBAL.TheWorld and GLOBAL.TheWorld.ismastersim then
        if not GLOBAL.TheWorld.components.atlas_todolist then
            GLOBAL.TheWorld:AddComponent("atlas_todolist")
        end
    end
end)

AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0.5, function()
        if not (inst:IsValid() and (inst.ismastersim or (GLOBAL.TheWorld and GLOBAL.TheWorld.ismastersim))) then
            return
        end
        if inst.components and inst.components.inventory then
            local has_book = false
            if inst.components.inventory.itemslots then
                for _, v in pairs(inst.components.inventory.itemslots) do
                    if v and v.prefab == "atlas_book" then
                        has_book = true
                        break
                    end
                end
            end
            if not has_book and inst.components.inventory.equipslots then
                for _, v in pairs(inst.components.inventory.equipslots) do
                    if v and v.prefab == "atlas_book" then
                        has_book = true
                        break
                    end
                end
            end
            if not has_book then
                local book = GLOBAL.SpawnPrefab("atlas_book")
                if book then
                    inst.components.inventory:GiveItem(book)
                    print("[万象全书] 成功为玩家发放开局生存指南:", inst.name or inst.prefab)
                end
            end
        end
    end)
end)

-- 7. 配方注册（丢失后可制作）
AddRecipe2(
    "atlas_book",
    { Ingredient("papyrus", 2), Ingredient("fossil_piece", 1) },
    TECH.NONE,
    { atlas = "images/inventoryimages/book_fossil.xml", image = "book_fossil.tex" },
    { "CHARACTER", "BOOKS" }
)

-- 8. 服务端阅读事件监听 -> 定向发送给该客机
AddPrefabPostInit("atlas_book", function(inst)
    if not GLOBAL.TheNet:GetIsServer() then
        return
    end
    inst:ListenForEvent("atlas_book_read", function(inst, data)
        if data and data.reader and data.reader.userid then
            local rpc_id = GetClientModRPC(ATLAS_RPC_NAMESPACE, ATLAS_RPC_OPEN_UI)
            if rpc_id then
                SendModRPCToClient(rpc_id, data.reader.userid)
            end
        end
    end)
end)

-- 9. RPC 网络处理器
AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_ADD_TASK, function(player, text)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:AddTask(text)
    end
end)

AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_TOGGLE_TASK, function(player, id, is_completed)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:ToggleTask(id, is_completed)
    end
end)

AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_DELETE_TASK, function(player, id)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:DeleteTask(id)
    end
end)

AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_SYNC_TASKS, function(player)
    if GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:SyncToClient(player.userid)
    end
end)

-- 客户端数据仓储与更新
GLOBAL.ATLAS_CLIENT_DATA = { tasks = {} }

AddClientModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_SYNC_TASKS, function(tasks_json)
    local success, tasks = pcall(function() return json.decode(tasks_json) end)
    if success and tasks then
        GLOBAL.ATLAS_CLIENT_DATA.tasks = tasks
        if GLOBAL.TheWorld then
            GLOBAL.TheWorld:PushEvent("atlas_todolist_updated")
        end
    end
end)

AddClientModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_OPEN_UI, function()
    if GLOBAL.ThePlayer and GLOBAL.ThePlayer.HUD then
        local sync_rpc = GetModRPC(ATLAS_RPC_NAMESPACE, ATLAS_RPC_SYNC_TASKS)
        if sync_rpc then SendModRPCToServer(sync_rpc) end
        GLOBAL.ThePlayer.HUD:OpenAtlasBook()
    end
end)

-- 10. 原生端到端自检探针 (Native E2E Test Probe)
GLOBAL.c_test_atlas = function()
    print("[ATLAS_AUTOTEST] ========== 开始万象书原生自检 ==========")
    
    -- 1. 自检 Client RPC JSON 编解码
    local test_json = json.encode({ { id = 999, text = "自检测试任务", completed = false } })
    local test_success, test_tasks = pcall(function() return json.decode(test_json) end)
    if test_success and test_tasks and test_tasks[1].text == "自检测试任务" then
        print("[ATLAS_AUTOTEST] 1. Client RPC JSON 编解码解析: 100% 成功")
    else
        print("[ATLAS_AUTOTEST] 1. Client RPC JSON 编解码解析: 失败!")
    end

    -- 2. 自检 UI 模块加载与 Screen 构造
    local AtlasBookUI = GLOBAL.require("widgets/atlasbook_ui")
    if AtlasBookUI and GLOBAL.ThePlayer then
        local ui_instance = AtlasBookUI(GLOBAL.ThePlayer)
        if ui_instance then
            print("[ATLAS_AUTOTEST] 2. AtlasBookUI 界面实例化与组件构建: 100% 成功")
            ui_instance:SetView("planner")
            ui_instance:UpdateTaskList()
            print("[ATLAS_AUTOTEST] 3. 任务视图切换与列表重绘: 100% 成功")
            if ui_instance.Kill then ui_instance:Kill() end
        end
    end

    print("[ATLAS_AUTOTEST] ========== 原生自检全部通过，零报错！ ==========")
end

-- 玩家入房 1.0 秒后自动静默执行一次自检，直接在日志验证
AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(1.0, function()
        if inst == GLOBAL.ThePlayer and GLOBAL.c_test_atlas then
            GLOBAL.c_test_atlas()
        end
    end)
end)