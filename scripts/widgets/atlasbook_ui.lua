-- ====================================================================
-- 《万象全书》双页复古手札看板界面 (Twin Parchment Codex UI)
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

    -- 2. 官方精美复古羊皮纸外框 (宽 880, 高 580)
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(440, 520, STRINGS.WINDOW_TITLE or "★ 万象书 · 任务与协同看板 ★", nil, nil, ""))
    self.bg:SetPosition(0, 0, 0)

    -- 3. 左右双列分栏容器 (精确坐标规划，杜绝边缘溢出)
    -- ==================== 左列：个人私密手札 (x = -205) ====================
    self.left_col = self.root:AddChild(Widget("left_col"))
    self.left_col:SetPosition(-205, 0, 0)

    self.personal_header = self.left_col:AddChild(Text(CHATFONT, 23))
    self.personal_header:SetPosition(0, 195, 0)
    self.personal_header:SetColour(0.35, 0.65, 0.95, 1) -- 晨曦蓝
    self.personal_header:SetString(STRINGS.PERSONAL_HEADER or "📜 【 个人私密计划 】")

    self.add_personal_btn = self.left_col:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(false) end,
        STRINGS.ADD_PERSONAL_BUTTON or "+ 添加个人任务",
        { 175, 38 }
    ))
    self.add_personal_btn:SetPosition(0, 150, 0)

    self.personal_list = self.left_col:AddChild(Widget("personal_list"))
    self.personal_list:SetPosition(0, 0, 0)

    -- ==================== 右列：团队协同公约 (x = 205) ====================
    self.right_col = self.root:AddChild(Widget("right_col"))
    self.right_col:SetPosition(205, 0, 0)

    self.team_header = self.right_col:AddChild(Text(CHATFONT, 23))
    self.team_header:SetPosition(0, 195, 0)
    self.team_header:SetColour(0.95, 0.70, 0.30, 1) -- 烈阳金
    self.team_header:SetString(STRINGS.TEAM_HEADER or "⚔️ 【 团队协同目标 】")

    self.add_team_btn = self.right_col:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(true) end,
        STRINGS.ADD_TEAM_BUTTON or "+ 添加团队目标",
        { 175, 38 }
    ))
    self.add_team_btn:SetPosition(0, 150, 0)

    self.team_list = self.right_col:AddChild(Widget("team_list"))
    self.team_list:SetPosition(0, 0, 0)

    -- ==================== 底部关闭按钮 ====================
    self.close_button = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:Close() end,
        STRINGS.CLOSE_BUTTON or "关 闭",
        { 130, 42 }
    ))
    self.close_button:SetPosition(0, -240, 0)

    -- 4. 数据请求与事件挂载
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

-- 局部重绘双列任务列表 (精确计算间距与排版)
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

    -- 绘制左列（个人任务：最多显示 6 条，纵向间距紧凑优雅）
    if self.personal_list then
        local y_offset = 95
        for i, task_data in ipairs(personal_tasks) do
            if i <= 6 then
                local task_item = self:CreateTaskItem(task_data, false)
                if task_item then
                    task_item:SetPosition(0, y_offset, 0)
                    self.personal_list:AddChild(task_item)
                    table.insert(self.personal_task_items, task_item)
                    y_offset = y_offset - 48
                end
            end
        end
    end

    -- 绘制右列（团队任务：最多显示 6 条）
    if self.team_list then
        local y_offset = 95
        for i, task_data in ipairs(team_tasks) do
            if i <= 6 then
                local task_item = self:CreateTaskItem(task_data, true)
                if task_item then
                    task_item:SetPosition(0, y_offset, 0)
                    self.team_list:AddChild(task_item)
                    table.insert(self.team_task_items, task_item)
                    y_offset = y_offset - 48
                end
            end
        end
    end
end

-- 创建单行精美任务条目 (完美适配标准字符集，杜绝方块与乱码)
function AtlasBookUI:CreateTaskItem(task, is_team)
    local item = Widget("task_item")

    -- 1. 复选框按钮 [ ✔ ] 或 [   ]
    local checkbox_text = task.completed and (STRINGS.COMPLETED_TASK or "✔") or (STRINGS.PENDING_TASK or " ")
    local checkbox = item:AddChild(TEMPLATES.StandardButton(
        function()
            self:ToggleTask(is_team, task.id, not task.completed)
        end,
        checkbox_text,
        { 34, 34 }
    ))
    checkbox:SetPosition(-150, 0, 0)

    -- 2. 任务文字内容 (明亮高对比度，超长优雅截断)
    local text = item:AddChild(Text(CHATFONT, 20))
    text:SetPosition(-5, 0, 0)
    text:SetRegionSize(220, 36)
    text:SetHAlign(ANCHOR_LEFT)
    text:SetVAlign(ANCHOR_MIDDLE)

    local display_text = task.text or ""
    if #display_text > 24 then
        display_text = display_text:sub(1, 24) .. "..."
    end
    text:SetString(display_text)

    if task.completed then
        text:SetColour(0.48, 0.48, 0.48, 1) -- 已完成：柔和灰色
    else
        if is_team then
            text:SetColour(0.98, 0.90, 0.78, 1) -- 团队任务：暖米白
        else
            text:SetColour(0.88, 0.94, 1.0, 1)  -- 个人任务：淡冰蓝
        end
    end

    -- 3. 删除按钮 [ X ] (标准 ASCII 红色大写 X，100% 兼容所有语言字库)
    local delete_btn = item:AddChild(TEMPLATES.StandardButton(
        function()
            self:DeleteTask(is_team, task.id)
        end,
        STRINGS.DELETE_BUTTON or "X",
        { 30, 30 }
    ))
    delete_btn:SetPosition(145, 0, 0)

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
