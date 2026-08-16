-- ====================================================================
-- 《万象全书》纯净双列任务看板界面 (Dual-Column Todo UI)
-- ====================================================================

local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local TEMPLATES = require "widgets/redux/templates"
local WriteableWidget = require "widgets/writeablewidget"

local AtlasBookUI = Class(Screen, function(self, owner)
    Screen._ctor(self, "AtlasBookUI")

    self.owner = owner
    self.personal_task_items = {}
    self.team_task_items = {}

    -- 1. 根节点与屏幕居中适配
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- 2. 羊皮纸主背景底板 (宽 960, 高 650)
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(440, 560, STRINGS.WINDOW_TITLE or "万象书 · 任务与协同看板", nil, nil, ""))
    self.bg:SetPosition(0, 0, 0)

    -- 3. 顶部主标题
    self.title = self.root:AddChild(Text(HEADERFONT, 34))
    self.title:SetPosition(0, 245, 0)
    self.title:SetColour(0.3, 0.2, 0.1, 1)
    self.title:SetString(STRINGS.WINDOW_TITLE or "万象书 · 任务与协同看板")

    -- 4. 左右双列分栏容器
    -- ==================== 左列：个人私密计划 (x = -225) ====================
    self.left_col = self.root:AddChild(Widget("left_col"))
    self.left_col:SetPosition(-225, 0, 0)

    self.personal_header = self.left_col:AddChild(Text(CHATFONT, 24))
    self.personal_header:SetPosition(0, 200, 0)
    self.personal_header:SetColour(0.2, 0.4, 0.7, 1)
    self.personal_header:SetString(STRINGS.PERSONAL_HEADER or "【 个人私密计划 】")

    self.add_personal_btn = self.left_col:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(false) end,
        STRINGS.ADD_PERSONAL_BUTTON or "+ 添加个人任务",
        { 190, 42 }
    ))
    self.add_personal_btn:SetPosition(0, 155, 0)

    self.personal_list = self.left_col:AddChild(Widget("personal_list"))
    self.personal_list:SetPosition(0, 0, 0)

    -- ==================== 中间分割装饰线 ====================
    self.divider = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.divider:SetPosition(0, 0, 0)
    self.divider:SetScale(0.003, 0.75, 1)
    self.divider:SetTint(0.6, 0.5, 0.4, 0.5)

    -- ==================== 右列：团队协同目标 (x = 225) ====================
    self.right_col = self.root:AddChild(Widget("right_col"))
    self.right_col:SetPosition(225, 0, 0)

    self.team_header = self.right_col:AddChild(Text(CHATFONT, 24))
    self.team_header:SetPosition(0, 200, 0)
    self.team_header:SetColour(0.7, 0.3, 0.1, 1)
    self.team_header:SetString(STRINGS.TEAM_HEADER or "【 团队协同目标 】")

    self.add_team_btn = self.right_col:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(true) end,
        STRINGS.ADD_TEAM_BUTTON or "+ 添加团队目标",
        { 190, 42 }
    ))
    self.add_team_btn:SetPosition(0, 155, 0)

    self.team_list = self.right_col:AddChild(Widget("team_list"))
    self.team_list:SetPosition(0, 0, 0)

    -- ==================== 底部关闭按钮 ====================
    self.close_button = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:Close() end,
        STRINGS.CLOSE_BUTTON or "关闭",
        { 140, 45 }
    ))
    self.close_button:SetPosition(0, -260, 0)

    -- 5. 初始化与数据监听
    self:RequestTaskSync()
    self:UpdateTaskList()

    self.inst:ListenForEvent("atlas_todolist_updated", function()
        self:UpdateTaskList()
    end, TheWorld)
end)

-- 呼出官方木牌输入弹窗
function AtlasBookUI:ShowSignInputModal(is_team)
    local dummy_inst = CreateEntity()
    local player = self.owner or ThePlayer
    local config = {
        prompt = (is_team and "【团队目标】" or "【个人计划】") .. " 输入内容:",
        animbank = "ui_board_5x3",
        animbuild = "ui_board_5x3",
        menuoffset = Vector3(6, -70, 0),
        maxcharacters = 80,
        cancelbtn = {
            text = STRINGS.CANCEL_BUTTON or "取消",
            control = CONTROL_CANCEL,
            cb = function(inst, doer, widget)
                if widget and widget.Close then
                    widget:Close()
                elseif player and player.HUD then
                    player.HUD:CloseWriteableWidget()
                end
            end,
        },
        middlebtn = {
            text = STRINGS.CLEAR_BUTTON or "清空",
            cb = function(inst, doer, widget)
                if widget and widget.OverrideText then
                    widget:OverrideText("")
                end
            end,
            control = CONTROL_MENU_MISC_2,
        },
        acceptbtn = {
            text = STRINGS.CONFIRM_BUTTON or "确定",
            cb = function(inst, doer, widget)
                local text = widget and widget.GetText and widget:GetText()
                if text and text:gsub("%s+", "") ~= "" then
                    self:AddTask(is_team, text)
                end
                if widget and widget.Close then
                    widget:Close()
                elseif player and player.HUD then
                    player.HUD:CloseWriteableWidget()
                end
            end,
            control = CONTROL_ACCEPT,
        },
    }

    if player and player.HUD and player.HUD.OpenWriteableWidget then
        player.HUD:OpenWriteableWidget(dummy_inst, config)
    else
        local screen = WriteableWidget(player, dummy_inst, config)
        TheFrontEnd:PushScreen(screen)
    end
end

-- 网络操作
function AtlasBookUI:AddTask(is_team, text)
    local rpc = GetModRPC("atlas_book", "add_task")
    if rpc then
        SendModRPCToServer(rpc, is_team, text)
    end
end

function AtlasBookUI:ToggleTask(is_team, id, is_completed)
    local rpc = GetModRPC("atlas_book", "toggle_task")
    if rpc then
        SendModRPCToServer(rpc, is_team, id, is_completed)
    end
end

function AtlasBookUI:DeleteTask(is_team, id)
    local rpc = GetModRPC("atlas_book", "delete_task")
    if rpc then
        SendModRPCToServer(rpc, is_team, id)
    end
end

function AtlasBookUI:RequestTaskSync()
    local rpc = GetModRPC("atlas_book", "sync_tasks")
    if rpc then
        SendModRPCToServer(rpc)
    end
end

-- 局部重绘双列任务列表
function AtlasBookUI:UpdateTaskList()
    -- 清理个人列
    if self.personal_task_items then
        for _, item in pairs(self.personal_task_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.personal_task_items = {}

    -- 清理团队列
    if self.team_task_items then
        for _, item in pairs(self.team_task_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.team_task_items = {}

    local client_data = _G.ATLAS_CLIENT_DATA or {}
    local personal_tasks = client_data.personal or {}
    local team_tasks = client_data.team or {}

    -- 绘制左列（个人任务）
    if self.personal_list then
        local y_offset = 105
        for i, task_data in ipairs(personal_tasks) do
            if i <= 6 then -- 单列展示最多 6 条
                local task_item = self:CreateTaskItem(task_data, false)
                if task_item then
                    task_item:SetPosition(0, y_offset, 0)
                    self.personal_list:AddChild(task_item)
                    table.insert(self.personal_task_items, task_item)
                    y_offset = y_offset - 50
                end
            end
        end
    end

    -- 绘制右列（团队任务）
    if self.team_list then
        local y_offset = 105
        for i, task_data in ipairs(team_tasks) do
            if i <= 6 then -- 单列展示最多 6 条
                local task_item = self:CreateTaskItem(task_data, true)
                if task_item then
                    task_item:SetPosition(0, y_offset, 0)
                    self.team_list:AddChild(task_item)
                    table.insert(self.team_task_items, task_item)
                    y_offset = y_offset - 50
                end
            end
        end
    end
end

-- 创建单行任务条目
function AtlasBookUI:CreateTaskItem(task, is_team)
    local item = Widget("task_item")

    -- 1. 单行底板
    local bg = item:AddChild(Image("images/global.xml", "square.tex"))
    bg:SetPosition(0, 0, 0)
    bg:SetScale(0.40, 0.052, 1)
    if is_team then
        bg:SetTint(0.95, 0.90, 0.82, 0.6)
    else
        bg:SetTint(0.88, 0.92, 0.98, 0.6)
    end

    -- 2. 复选框按钮 [✓] 或 [□]
    local checkbox_text = task.completed and (STRINGS.COMPLETED_TASK or "✓") or (STRINGS.PENDING_TASK or "□")
    local checkbox = item:AddChild(TEMPLATES.StandardButton(
        function()
            self:ToggleTask(is_team, task.id, not task.completed)
        end,
        checkbox_text,
        { 38, 38 }
    ))
    checkbox:SetPosition(-150, 0, 0)

    -- 3. 任务内容文本
    local text = item:AddChild(Text(CHATFONT, 20))
    text:SetPosition(0, 0, 0)
    text:SetRegionSize(240, 40)
    text:SetHAlign(ANCHOR_LEFT)
    text:SetVAlign(ANCHOR_MIDDLE)

    local display_text = task.text or ""
    if #display_text > 24 then
        display_text = display_text:sub(1, 24) .. "..."
    end
    text:SetString(display_text)

    if task.completed then
        text:SetColour(0.5, 0.5, 0.5, 1)
    else
        text:SetColour(0.1, 0.1, 0.1, 1)
    end

    -- 4. 删除按钮 [✕]
    local delete_btn = item:AddChild(TEMPLATES.StandardButton(
        function()
            self:DeleteTask(is_team, task.id)
        end,
        STRINGS.DELETE_BUTTON or "✕",
        { 34, 34 }
    ))
    delete_btn:SetPosition(160, 0, 0)

    return item
end

function AtlasBookUI:Close()
    TheFrontEnd:PopScreen(self)
end

function AtlasBookUI:OnControl(control, down)
    if AtlasBookUI._base.OnControl(self, control, down) then return true end

    if not down and (control == CONTROL_CANCEL or control == CONTROL_OPEN_DEBUG_CONSOLE) then
        self:Close()
        return true
    end
end

return AtlasBookUI
