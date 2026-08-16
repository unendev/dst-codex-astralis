-- ====================================================================
-- 《万象全书》多模态任务看板界面 (Dual & Single Hybrid View)
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
    self.layout_mode = "dual"    -- "dual" (双列并排) 或 "single" (单列聚焦)
    self.single_tab = "personal"  -- 单列模式下的子页: "personal" 或 "team"
    
    self.dual_personal_items = {}
    self.dual_team_items = {}
    self.single_task_items = {}

    -- 1. 根节点与屏幕居中自适应
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- 2. 官方精美复古羊皮纸外框 (宽 740, 高 520, 1.0 真实比例)
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(740, 520, STRINGS.WINDOW_TITLE or "看 板", nil, nil, ""))
    self.bg:SetScale(1.0, 1.0)
    self.bg:SetPosition(0, 0, 0)

    -- 3. 右上角模式切换开关（极简"切 换"二字）
    self.mode_toggle_btn = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:ToggleLayoutMode() end,
        "切 换",
        { 85, 32 }
    ))
    self.mode_toggle_btn:SetPosition(260, 205, 0)

    -- ====================================================================
    -- 4. 模式 A：双列并排容器 (Dual Container)
    -- ====================================================================
    self.dual_container = self.root:AddChild(Widget("dual_container"))
    self.dual_container:SetPosition(0, 0, 0)

    -- 左列：个人 (x = -175)
    self.left_col = self.dual_container:AddChild(Widget("left_col"))
    self.left_col:SetPosition(-175, 0, 0)

    self.personal_header = self.left_col:AddChild(Text(HEADERFONT, 28))
    self.personal_header:SetPosition(0, 195, 0)
    self.personal_header:SetColour(0.35, 0.65, 0.95, 1)
    self.personal_header:SetString(STRINGS.PERSONAL_HEADER or "个 人")

    self.add_personal_btn = self.left_col:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(false) end,
        STRINGS.ADD_PERSONAL_BUTTON or "+ 添加个人任务",
        { 155, 36 }
    ))
    self.add_personal_btn:SetPosition(0, 150, 0)

    self.dual_personal_list = self.left_col:AddChild(Widget("dual_personal_list"))
    self.dual_personal_list:SetPosition(0, 0, 0)

    -- 右列：团队 (x = 175)
    self.right_col = self.dual_container:AddChild(Widget("right_col"))
    self.right_col:SetPosition(175, 0, 0)

    self.team_header = self.right_col:AddChild(Text(HEADERFONT, 28))
    self.team_header:SetPosition(0, 195, 0)
    self.team_header:SetColour(0.95, 0.70, 0.30, 1)
    self.team_header:SetString(STRINGS.TEAM_HEADER or "团 队")

    self.add_team_btn = self.right_col:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(true) end,
        STRINGS.ADD_TEAM_BUTTON or "+ 添加团队目标",
        { 155, 36 }
    ))
    self.add_team_btn:SetPosition(0, 150, 0)

    self.dual_team_list = self.right_col:AddChild(Widget("dual_team_list"))
    self.dual_team_list:SetPosition(0, 0, 0)

    -- ====================================================================
    -- 5. 模式 B：单列聚焦容器 (Single Container - 左右并排顶栏)
    -- ====================================================================
    self.single_container = self.root:AddChild(Widget("single_container"))
    self.single_container:SetPosition(0, 0, 0)
    self.single_container:Hide()

    -- 单列顶部左侧：个人/团队切换按钮 (同一行并排，x = -115)
    self.single_tab_btn = self.single_container:AddChild(TEMPLATES.StandardButton(
        function() self:ToggleSingleTab() end,
        "当前：个人计划 ⇄ 团队",
        { 220, 36 }
    ))
    self.single_tab_btn:SetPosition(-115, 155, 0)

    -- 单列顶部右侧：添加任务按钮 (同一行并排，x = 125)
    self.single_add_btn = self.single_container:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(self.single_tab == "team") end,
        "+ 添加个人任务",
        { 180, 36 }
    ))
    self.single_add_btn:SetPosition(125, 155, 0)

    self.single_task_list = self.single_container:AddChild(Widget("single_task_list"))
    self.single_task_list:SetPosition(0, 0, 0)

    -- ====================================================================
    -- 6. 底部关闭按钮
    -- ====================================================================
    self.close_button = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:Close() end,
        STRINGS.CLOSE_BUTTON or "关 闭",
        { 130, 42 }
    ))
    self.close_button:SetPosition(0, -225, 0)

    -- 7. 初始化与数据同步
    self:RequestTaskSync()
    self:RefreshLayout()

    self.inst:ListenForEvent("atlas_todolist_updated", function()
        self:RefreshLayout()
    end, TheWorld)
end)

-- 模式切换（双列 ⇄ 单列）
function AtlasBookUI:ToggleLayoutMode()
    if self.layout_mode == "dual" then
        self.layout_mode = "single"
    else
        self.layout_mode = "dual"
    end
    self:RefreshLayout()
end

-- 单列模式下的子 Tab 切换（个人 ⇄ 团队）
function AtlasBookUI:ToggleSingleTab()
    if self.single_tab == "personal" then
        self.single_tab = "team"
    else
        self.single_tab = "personal"
    end
    self:RefreshLayout()
end

-- 兼容性刷新接口
function AtlasBookUI:UpdateTaskList()
    self:RefreshLayout()
end

-- 统一重绘界面排版与内容
function AtlasBookUI:RefreshLayout()
    if self.layout_mode == "dual" then
        self.dual_container:Show()
        self.single_container:Hide()
        self:UpdateDualTaskList()
    else
        self.dual_container:Hide()
        self.single_container:Show()
        if self.single_tab == "team" then
            self.single_tab_btn:SetText("当前：团队目标 ⇄ 个人")
            self.single_add_btn:SetText("+ 添加团队目标")
        else
            self.single_tab_btn:SetText("当前：个人计划 ⇄ 团队")
            self.single_add_btn:SetText("+ 添加个人任务")
        end
        self:UpdateSingleTaskList()
    end
end

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

-- 网络 RPC 操作
function AtlasBookUI:AddTask(is_team, text)
    local rpc = GetModRPC("atlas_book", "add_task")
    if rpc then SendModRPCToServer(rpc, is_team, text) end
end

function AtlasBookUI:ToggleTask(is_team, id, is_completed)
    local rpc = GetModRPC("atlas_book", "toggle_task")
    if rpc then SendModRPCToServer(rpc, is_team, id, is_completed) end
end

function AtlasBookUI:DeleteTask(is_team, id)
    local rpc = GetModRPC("atlas_book", "delete_task")
    if rpc then SendModRPCToServer(rpc, is_team, id) end
end

function AtlasBookUI:RequestTaskSync()
    local rpc = GetModRPC("atlas_book", "sync_tasks")
    if rpc then SendModRPCToServer(rpc) end
end

-- 绘制双列模式任务列表
function AtlasBookUI:UpdateDualTaskList()
    if self.dual_personal_items then
        for _, item in pairs(self.dual_personal_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.dual_personal_items = {}

    if self.dual_team_items then
        for _, item in pairs(self.dual_team_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.dual_team_items = {}

    local client_data = _G.ATLAS_CLIENT_DATA or {}
    local personal_tasks = client_data.personal or {}
    local team_tasks = client_data.team or {}

    -- 左列 (个人)
    if self.dual_personal_list then
        local y_offset = 95
        for i, task_data in ipairs(personal_tasks) do
            if i <= 6 then
                local item = self:CreateDualTaskItem(task_data, false)
                if item then
                    item:SetPosition(0, y_offset, 0)
                    self.dual_personal_list:AddChild(item)
                    table.insert(self.dual_personal_items, item)
                    y_offset = y_offset - 48
                end
            end
        end
    end

    -- 右列 (团队)
    if self.dual_team_list then
        local y_offset = 95
        for i, task_data in ipairs(team_tasks) do
            if i <= 6 then
                local item = self:CreateDualTaskItem(task_data, true)
                if item then
                    item:SetPosition(0, y_offset, 0)
                    self.dual_team_list:AddChild(item)
                    table.insert(self.dual_team_items, item)
                    y_offset = y_offset - 48
                end
            end
        end
    end
end

-- 绘制单列模式任务列表 (全宽舒适排版)
function AtlasBookUI:UpdateSingleTaskList()
    if self.single_task_items then
        for _, item in pairs(self.single_task_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.single_task_items = {}

    local is_team = (self.single_tab == "team")
    local client_data = _G.ATLAS_CLIENT_DATA or {}
    local tasks = is_team and (client_data.team or {}) or (client_data.personal or {})

    if self.single_task_list then
        local y_offset = 95
        for i, task_data in ipairs(tasks) do
            if i <= 6 then
                local item = self:CreateSingleTaskItem(task_data, is_team)
                if item then
                    item:SetPosition(0, y_offset, 0)
                    self.single_task_list:AddChild(item)
                    table.insert(self.single_task_items, item)
                    y_offset = y_offset - 48
                end
            end
        end
    end
end

-- 创建双列下的单条任务项
function AtlasBookUI:CreateDualTaskItem(task, is_team)
    local item = Widget("dual_task_item")

    local checkbox_text = task.completed and (STRINGS.COMPLETED_TASK or "√") or (STRINGS.PENDING_TASK or "")
    local checkbox = item:AddChild(TEMPLATES.StandardButton(
        function() self:ToggleTask(is_team, task.id, not task.completed) end,
        checkbox_text,
        { 34, 34 }
    ))
    checkbox:SetPosition(-125, 0, 0)

    local text = item:AddChild(Text(CHATFONT, 20))
    text:SetPosition(-5, 0, 0)
    text:SetRegionSize(185, 36)
    text:SetHAlign(ANCHOR_LEFT)
    text:SetVAlign(ANCHOR_MIDDLE)
    text:SetString(task.text or "")

    if task.completed then
        text:SetColour(0.48, 0.48, 0.48, 1)
    else
        text:SetColour(is_team and 0.98 or 0.88, is_team and 0.90 or 0.94, is_team and 0.78 or 1.0, 1)
    end

    local delete_btn = item:AddChild(TEMPLATES.StandardButton(
        function() self:DeleteTask(is_team, task.id) end,
        STRINGS.DELETE_BUTTON or "X",
        { 30, 30 }
    ))
    delete_btn:SetPosition(125, 0, 0)

    return item
end

-- 创建单列下的超宽舒适任务项
function AtlasBookUI:CreateSingleTaskItem(task, is_team)
    local item = Widget("single_task_item")

    local checkbox_text = task.completed and (STRINGS.COMPLETED_TASK or "√") or (STRINGS.PENDING_TASK or "")
    local checkbox = item:AddChild(TEMPLATES.StandardButton(
        function() self:ToggleTask(is_team, task.id, not task.completed) end,
        checkbox_text,
        { 36, 36 }
    ))
    checkbox:SetPosition(-200, 0, 0)

    local text = item:AddChild(Text(CHATFONT, 22))
    text:SetPosition(0, 0, 0)
    text:SetRegionSize(350, 36)
    text:SetHAlign(ANCHOR_LEFT)
    text:SetVAlign(ANCHOR_MIDDLE)
    text:SetString(task.text or "")

    if task.completed then
        text:SetColour(0.48, 0.48, 0.48, 1)
    else
        text:SetColour(is_team and 0.98 or 0.88, is_team and 0.90 or 0.94, is_team and 0.78 or 1.0, 1)
    end

    local delete_btn = item:AddChild(TEMPLATES.StandardButton(
        function() self:DeleteTask(is_team, task.id) end,
        STRINGS.DELETE_BUTTON or "X",
        { 32, 32 }
    ))
    delete_btn:SetPosition(200, 0, 0)

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
