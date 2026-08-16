-- ====================================================================
-- 《万象全书》服务端 TodoList 组件（多玩家私有化隔离）
-- ====================================================================

local AtlasTodoList = Class(function(self, inst)
    self.inst = inst
    self.personal_tasks = {} -- 结构: [userid] = { tasks = {}, next_id = 1 }
end)

-- 获取或初始化指定玩家的数据仓储
function AtlasTodoList:GetPlayerStore(userid)
    userid = userid or "default_user"
    if not self.personal_tasks[userid] then
        self.personal_tasks[userid] = {
            tasks = {},
            next_id = 1,
        }
    end
    return self.personal_tasks[userid]
end

-- 添加任务（绑定该玩家 userid）
function AtlasTodoList:AddTask(userid, text)
    if not self.inst.ismastersim then return nil end
    if not text or text:gsub("%s+", "") == "" then return nil end

    local store = self:GetPlayerStore(userid)
    local task = {
        id = store.next_id,
        text = text,
        completed = false,
        timestamp = os.time(),
    }
    table.insert(store.tasks, task)
    store.next_id = store.next_id + 1
    self:SyncToClient(userid)
    return task
end

-- 切换任务完成状态
function AtlasTodoList:ToggleTask(userid, task_id, is_completed)
    if not self.inst.ismastersim then return false end
    local store = self:GetPlayerStore(userid)
    for _, task in ipairs(store.tasks) do
        if task.id == task_id then
            task.completed = is_completed
            self:SyncToClient(userid)
            return true
        end
    end
    return false
end

-- 删除任务
function AtlasTodoList:DeleteTask(userid, task_id)
    if not self.inst.ismastersim then return false end
    local store = self:GetPlayerStore(userid)
    for i, task in ipairs(store.tasks) do
        if task.id == task_id then
            table.remove(store.tasks, i)
            self:SyncToClient(userid)
            return true
        end
    end
    return false
end

-- 获取指定玩家的任务列表
function AtlasTodoList:GetTasks(userid)
    local store = self:GetPlayerStore(userid)
    return store.tasks
end

-- 定向单播同步给指定玩家
function AtlasTodoList:SyncToClient(userid)
    if not self.inst.ismastersim or not userid then return end
    local store = self:GetPlayerStore(userid)
    local tasks_json = json.encode(store.tasks)
    local rpc_id = GetClientModRPC("atlas_book", "sync_tasks")
    if rpc_id then
        SendModRPCToClient(rpc_id, userid, tasks_json)
    end
end

-- 广播给当前在线的所有玩家（各发各的专属数据）
function AtlasTodoList:SyncToAllOnlineClients()
    if not self.inst.ismastersim then return end
    local players = AllPlayers or (_G and _G.AllPlayers) or {}
    for _, player in ipairs(players) do
        if player:IsValid() and player.userid then
            self:SyncToClient(player.userid)
        end
    end
end

-- 存盘序列化
function AtlasTodoList:OnSave()
    if not self.inst.ismastersim then return nil end
    return {
        personal_tasks = self.personal_tasks,
    }
end

-- 读盘反序列化
function AtlasTodoList:OnLoad(data)
    if not self.inst.ismastersim then return end
    if data and data.personal_tasks then
        self.personal_tasks = data.personal_tasks
    end
    self.inst:DoTaskInTime(1, function()
        self:SyncToAllOnlineClients()
    end)
end

return AtlasTodoList