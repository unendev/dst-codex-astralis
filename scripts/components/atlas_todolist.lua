-- ====================================================================
-- 《万象全书》服务端 TodoList 组件（双列 Todo：个人私有 + 团队共享）
-- ====================================================================

local AtlasTodoList = Class(function(self, inst)
    self.inst = inst
    self.personal_tasks = {} -- [userid] = { tasks = {}, next_id = 1 }
    self.team_tasks = { tasks = {}, next_id = 1 } -- 团队公有池
end)

-- 获取个人数据仓储
function AtlasTodoList:GetPersonalStore(userid)
    userid = userid or "default_user"
    if not self.personal_tasks[userid] then
        self.personal_tasks[userid] = {
            tasks = {},
            next_id = 1,
        }
    end
    return self.personal_tasks[userid]
end

-- 添加任务 (is_team: true 为团队任务, false 为个人任务)
function AtlasTodoList:AddTask(is_team, userid, text)
    if not self.inst.ismastersim then return nil end
    if not text or text:gsub("%s+", "") == "" then return nil end

    local store = is_team and self.team_tasks or self:GetPersonalStore(userid)
    local task = {
        id = store.next_id,
        text = text,
        completed = false,
        timestamp = os.time(),
    }
    table.insert(store.tasks, task)
    store.next_id = store.next_id + 1

    if is_team then
        self:SyncToAllOnlineClients()
    else
        self:SyncToClient(userid)
    end
    return task
end

-- 切换任务完成状态
function AtlasTodoList:ToggleTask(is_team, userid, task_id, is_completed)
    if not self.inst.ismastersim then return false end
    local store = is_team and self.team_tasks or self:GetPersonalStore(userid)

    for _, task in ipairs(store.tasks) do
        if task.id == task_id then
            task.completed = is_completed
            if is_team then
                self:SyncToAllOnlineClients()
            else
                self:SyncToClient(userid)
            end
            return true
        end
    end
    return false
end

-- 删除任务
function AtlasTodoList:DeleteTask(is_team, userid, task_id)
    if not self.inst.ismastersim then return false end
    local store = is_team and self.team_tasks or self:GetPersonalStore(userid)

    for i, task in ipairs(store.tasks) do
        if task.id == task_id then
            table.remove(store.tasks, i)
            if is_team then
                self:SyncToAllOnlineClients()
            else
                self:SyncToClient(userid)
            end
            return true
        end
    end
    return false
end

-- 定向单播同步给指定玩家（下发该玩家的个人数据 + 全局团队数据）
function AtlasTodoList:SyncToClient(userid)
    if not self.inst.ismastersim or not userid then return end
    local personal_store = self:GetPersonalStore(userid)
    local payload = {
        personal = personal_store.tasks,
        team = self.team_tasks.tasks,
    }
    local tasks_json = json.encode(payload)
    local rpc_id = GetClientModRPC("atlas_book", "sync_tasks")
    if rpc_id then
        SendModRPCToClient(rpc_id, userid, tasks_json)
    end
end

-- 广播给所有在线玩家（各发各的私有数据 + 统一的团队数据）
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
        team_tasks = self.team_tasks,
    }
end

-- 读盘反序列化
function AtlasTodoList:OnLoad(data)
    if not self.inst.ismastersim then return end
    if data then
        self.personal_tasks = data.personal_tasks or {}
        self.team_tasks = data.team_tasks or { tasks = {}, next_id = 1 }
    end
    self.inst:DoTaskInTime(1, function()
        self:SyncToAllOnlineClients()
    end)
end

return AtlasTodoList