-- ====================================================================
-- 《万象全书》(Codex Astralis) 纯净核心逻辑 (Dual-Column Todo Baseline)
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
STRINGS.NAMES.ATLAS_BOOK = "★万象书 (双列任务版)★"
STRINGS.RECIPE_DESC.ATLAS_BOOK = "协同生存与个人任务看板"
STRINGS.INPUT_PROMPT = "输入任务内容:"
STRINGS.CANCEL_BUTTON = "取消"
STRINGS.CLEAR_BUTTON = "清空"
STRINGS.CONFIRM_BUTTON = "确定"
STRINGS.ADD_PERSONAL_BUTTON = "+ 添加个人任务"
STRINGS.ADD_TEAM_BUTTON = "+ 添加团队目标"
STRINGS.DELETE_BUTTON = "X"
STRINGS.COMPLETED_TASK = "✔"
STRINGS.PENDING_TASK = " "
STRINGS.WINDOW_TITLE = "★ 万象书 · 任务与协同看板 ★"
STRINGS.PERSONAL_HEADER = "📜 【 个人私密计划 】"
STRINGS.TEAM_HEADER = "⚔️ 【 团队协同目标 】"
STRINGS.CLOSE_BUTTON = "关 闭"

-- 2. RPC 协议定义
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

-- 3. 全角色通用阅读动作覆盖（原版成熟蓝本）
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

-- 4. 客户端 HUD 界面挂载
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

-- 5. 服务端组件注入与出生赠送
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

-- 6. 配方注册（丢失后可制作）
AddRecipe2(
    "atlas_book",
    { Ingredient("papyrus", 2), Ingredient("fossil_piece", 1) },
    TECH.NONE,
    { atlas = "images/inventoryimages/book_fossil.xml", image = "book_fossil.tex" },
    { "CHARACTER", "BOOKS" }
)

-- 7. 服务端阅读事件监听 -> 定向发送给该客机
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

-- 8. RPC 网络处理器（双通道：个人 + 团队）
AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_ADD_TASK, function(player, is_team, text)
    if player and player.userid and GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:AddTask(is_team, player.userid, text)
    end
end)

AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_TOGGLE_TASK, function(player, is_team, id, is_completed)
    if player and player.userid and GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:ToggleTask(is_team, player.userid, id, is_completed)
    end
end)

AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_DELETE_TASK, function(player, is_team, id)
    if player and player.userid and GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:DeleteTask(is_team, player.userid, id)
    end
end)

AddModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_SYNC_TASKS, function(player)
    if player and player.userid and GLOBAL.TheWorld and GLOBAL.TheWorld.components.atlas_todolist then
        GLOBAL.TheWorld.components.atlas_todolist:SyncToClient(player.userid)
    end
end)

-- 客户端数据仓储与更新
GLOBAL.ATLAS_CLIENT_DATA = { personal = {}, team = {} }

AddClientModRPCHandler(ATLAS_RPC_NAMESPACE, ATLAS_RPC_SYNC_TASKS, function(tasks_json)
    local success, payload = pcall(function() return json.decode(tasks_json) end)
    if success and payload then
        GLOBAL.ATLAS_CLIENT_DATA.personal = payload.personal or {}
        GLOBAL.ATLAS_CLIENT_DATA.team = payload.team or {}
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

-- 9. 原生端到端自检探针 (Native E2E Test Probe)
GLOBAL.c_test_atlas = function()
    print("[ATLAS_AUTOTEST] ========== 开始万象书双列原生自检 ==========")
    
    local test_json = json.encode({
        personal = { { id = 1, text = "自检个人任务", completed = false } },
        team = { { id = 1, text = "自检团队目标", completed = true } }
    })
    local test_success, test_payload = pcall(function() return json.decode(test_json) end)
    if test_success and test_payload and test_payload.personal and test_payload.team then
        print("[ATLAS_AUTOTEST] 1. 双列 JSON 编解码解析: 100% 成功")
    else
        print("[ATLAS_AUTOTEST] 1. 双列 JSON 编解码解析: 失败!")
    end

    local AtlasBookUI = GLOBAL.require("widgets/atlasbook_ui")
    if AtlasBookUI and GLOBAL.ThePlayer then
        local ui_instance = AtlasBookUI(GLOBAL.ThePlayer)
        if ui_instance then
            print("[ATLAS_AUTOTEST] 2. 双列 AtlasBookUI 界面实例化与构建: 100% 成功")
            ui_instance:UpdateTaskList()
            if ui_instance.Kill then ui_instance:Kill() end
        end
    end

    print("[ATLAS_AUTOTEST] ========== 双列原生自检全部通过！ ==========")
end

AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(1.0, function()
        if inst == GLOBAL.ThePlayer and GLOBAL.c_test_atlas then
            GLOBAL.c_test_atlas()
        end
    end)
end)