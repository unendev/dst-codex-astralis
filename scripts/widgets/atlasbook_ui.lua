-- ====================================================================
-- 《万象全书》纯净任务看板界面 (Atlas Book Codex UI)
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
    self.current_tab = "personal" -- "personal" 或 "team"
    self.task_items = {}

    -- 1. 根节点与屏幕居中自适应（全分辨率等比缩放）
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- 2. 官方精美复古羊皮纸外框 (重置 Scale 为 1.0，彻底解除官方 0.7 缩放限制)
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(680, 500, STRINGS.WINDOW_TITLE or "看 板", nil, nil, ""))
    self.bg:SetScale(1.0, 1.0)
    self.bg:SetPosition(0, 0, 0)

    -- 3. 顶部单按钮胶囊切换（点击在 个人 ⇄ 团队 之间秒速切换）
    self.tab_toggle_btn = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:ToggleTab() end,
        "📜 当前视图：【 个人计划 】  (点击切换)",
        { 340, 42 }
    ))
    self.tab_toggle_btn:SetPosition(0, 185, 0)

    -- 4. 添加任务主操作按钮
    self.add_task_btn = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal(self.current_tab == "team") end,
        "+ 添加新任务",
        { 220, 38 }
    ))
    self.add_task_btn:SetPosition(0, 135, 0)

    -- 5. 任务列表容器（全宽居中，单行宽度达 460 像素，字再多也不挤）
    self.task_list = self.root:AddChild(Widget("task_list"))
    self.task_list:SetPosition(0, 0, 0)

    -- 6. 底部关闭按钮
    self.close_button = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:Close() end,
        STRINGS.CLOSE_BUTTON or "关 闭",
        { 130, 42 }
    ))
    self.close_button:SetPosition(0, -225, 0)

    -- 7. 初始化与事件监听
    self:RequestTaskSync()
    self:RefreshView()

    self.inst:ListenForEvent("atlas_todolist_updated", function()
        self:RefreshView()
    end, TheWorld)
end)

-- 视图切换逻辑（个人 ⇄ 团队）
function AtlasBookUI:ToggleTab()
    if self.current_tab == "personal" then
        self.current_tab = "team"
    else
        self.current_tab = "personal"
    end
    self:RefreshView()
end

function AtlasBookUI:RefreshView()
    local is_team = (self.current_tab == "team")
    if is_team then
        self.tab_toggle_btn:SetText("⚔️ 当前视图：【 团队目标 】  (点击切至个人)")
        self.add_task_btn:SetText("+ 添加团队目标")
    else
        self.tab_toggle_btn:SetText("📜 当前视图：【 个人计划 】  (点击切至团队)")
        self.add_task_btn:SetText("+ 添加个人任务")
    end
    self:UpdateTaskList()
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

-- 局部重绘任务列表
function AtlasBookUI:UpdateTaskList()
    if self.task_items then
        for _, item in pairs(self.task_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.task_items = {}

    local is_team = (self.current_tab == "team")
    local client_data = _G.ATLAS_CLIENT_DATA or {}
    local tasks = is_team and (client_data.team or {}) or (client_data.personal or {})

    if self.task_list then
        local y_offset = 80
        for i, task_data in ipairs(tasks) do
            if i <= 6 then
                local task_item = self:CreateTaskItem(task_data, is_team)
                if task_item then
                    task_item:SetPosition(0, y_offset, 0)
                    self.task_list:AddChild(task_item)
                    table.insert(self.task_items, task_item)
                    y_offset = y_offset - 48
                end
            end
        end
    end
end

-- 创建单行全宽舒适任务条目
function AtlasBookUI:CreateTaskItem(task, is_team)
    local item = Widget("task_item")

    -- 1. 复选框按钮 [ √ ] 或 [   ]（标准数学根号对勾，杜绝乱码）
    local checkbox_text = task.completed and (STRINGS.COMPLETED_TASK or "√") or (STRINGS.PENDING_TASK or "")
    local checkbox = item:AddChild(TEMPLATES.StandardButton(
        function()
            self:ToggleTask(is_team, task.id, not task.completed)
        end,
        checkbox_text,
        { 36, 36 }
    ))
    checkbox:SetPosition(-200, 0, 0)

    -- 2. 任务文字内容（超宽 370 像素，字迹清晰温润，完全不截断）
    local text = item:AddChild(Text(CHATFONT, 22))
    text:SetPosition(0, 0, 0)
    text:SetRegionSize(350, 36)
    text:SetHAlign(ANCHOR_LEFT)
    text:SetVAlign(ANCHOR_MIDDLE)
    text:SetString(task.text or "")

    if task.completed then
        text:SetColour(0.48, 0.48, 0.48, 1) -- 已完成：柔和灰色
    else
        if is_team then
            text:SetColour(0.98, 0.90, 0.78, 1) -- 团队目标：暖阳白
        else
            text:SetColour(0.88, 0.94, 1.0, 1)  -- 个人计划：晨曦蓝
        end
    end

    -- 3. 删除按钮 [ X ] (标准 ASCII 红色 X)
    local delete_btn = item:AddChild(TEMPLATES.StandardButton(
        function()
            self:DeleteTask(is_team, task.id)
        end,
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
