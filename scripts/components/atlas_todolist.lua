local AtlasTodoList = Class(function(self, inst)
    self.inst = inst
    self.tasks = {}
    self.next_id = 1
end)

function AtlasTodoList:AddTask(text)
    if not self.inst.ismastersim then return nil end

    if text and text:gsub("%s+", "") ~= "" then
        local task = {
            id = self.next_id,
            text = text,
            completed = false,
            timestamp = os.time()
        }
        table.insert(self.tasks, task)
        self.next_id = self.next_id + 1
        self:SyncToClients()
        return task
    end
    return nil
end

function AtlasTodoList:ToggleTask(task_id, is_completed)
    if not self.inst.ismastersim then return false end

    for _, task in ipairs(self.tasks) do
        if task.id == task_id then
            task.completed = is_completed
            self:SyncToClients()
            return true
        end
    end
    return false
end

function AtlasTodoList:DeleteTask(task_id)
    if not self.inst.ismastersim then return false end

    for i, task in ipairs(self.tasks) do
        if task.id == task_id then
            table.remove(self.tasks, i)
            self:SyncToClients()
            return true
        end
    end
    return false
end

function AtlasTodoList:GetTasks()
    return self.tasks
end

function AtlasTodoList:SyncToClient(userid)
    if not self.inst.ismastersim then return end
    local tasks_json = json.encode(self.tasks)
    local rpc_id = GetClientModRPC("atlas_book", "sync_tasks")
    if rpc_id and userid then
        SendModRPCToClient(rpc_id, userid, tasks_json)
    end
end

function AtlasTodoList:SyncToClients()
    if not self.inst.ismastersim then return end
    local tasks_json = json.encode(self.tasks)
    local rpc_id = GetClientModRPC("atlas_book", "sync_tasks")
    if rpc_id then
        local players = AllPlayers or (_G and _G.AllPlayers) or {}
        for _, v in ipairs(players) do
            if v:IsValid() and v.userid then
                SendModRPCToClient(rpc_id, v.userid, tasks_json)
            end
        end
    end
end

function AtlasTodoList:OnSave()
    if not self.inst.ismastersim then return nil end
    return {
        tasks = self.tasks,
        next_id = self.next_id
    }
end

function AtlasTodoList:OnLoad(data)
    if not self.inst.ismastersim then return end
    if data then
        self.tasks = data.tasks or {}
        self.next_id = data.next_id or 1
    end
    self.inst:DoTaskInTime(1, function()
        self:SyncToClients()
    end)
end

return AtlasTodoList