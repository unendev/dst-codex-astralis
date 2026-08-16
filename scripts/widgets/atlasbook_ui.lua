local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local TEMPLATES = require "widgets/redux/templates"
local WriteableWidget = require "widgets/writeablewidget"

local strings_module = (_G and _G.ATLAS_STRINGS_MODULE)
if not (type(strings_module) == "table" and strings_module.GetGuideData) then
    local req_mod = require("strings")
    if type(req_mod) == "table" then
        strings_module = req_mod
    end
end
local GUIDE_DATA = (type(strings_module) == "table" and strings_module.GetGuideData and strings_module.GetGuideData()) or {}

-- 扁平化章节列表，用于翻页
local FLAT_CHAPTERS = {}
for section_id, section_data in pairs(GUIDE_DATA) do
    if section_data.is_section and section_data.children then
        for chapter_id, chapter_data in pairs(section_data.children) do
            if not chapter_data.is_section then
                table.insert(FLAT_CHAPTERS, { id = chapter_id, section_id = section_id })
            end
        end
    end
end

local AtlasBookUI = Class(Screen, function(self, owner)
    Screen._ctor(self, "AtlasBookUI")

    self.owner = owner or ThePlayer
    self.expanded_sections = {}
    self.current_view = "guide"
    self.task_items = {}

    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- 主窗口面板
    self.panel = self.root:AddChild(TEMPLATES.RectangleWindow(900, 600, STRINGS.WINDOW_TITLE or "生存指南"))
    self.panel:SetBackgroundTint(unpack(UICOLOURS.BROWN_DARK))

    -- 关闭按钮
    self.close_button = self.panel:AddChild(TEMPLATES.StandardButton(function() self:Close() end, STRINGS.CLOSE_BUTTON or "关闭", {100, 50}))
    self.close_button:SetPosition(900/2 - 50, 600/2 - 25, 0)

    -- 顶部 Tab 切换
    self.tabs_root = self.panel:AddChild(Widget("TABS_ROOT"))
    self.tabs_root:SetPosition(0, 260, 0)

    self.guide_tab_button = self.tabs_root:AddChild(TEMPLATES.StandardButton(function() self:SetView("guide") end, STRINGS.GUIDE_TAB or "静态攻略", {150, 50}))
    self.guide_tab_button:SetPosition(-80, 0, 0)

    self.planner_tab_button = self.tabs_root:AddChild(TEMPLATES.StandardButton(function() self:SetView("planner") end, STRINGS.PLANNER_TAB or "团队计划", {150, 50}))
    self.planner_tab_button:SetPosition(80, 0, 0)

    -- 两个视图容器
    self.guide_view = self.panel:AddChild(Widget("GUIDE_VIEW"))
    self.planner_view = self.panel:AddChild(Widget("PLANNER_VIEW"))

    -- ================================================================
    -- 1. 静态攻略视图 (Guide View)
    -- ================================================================
    self.menu_root = self.guide_view:AddChild(Widget("MENU_ROOT"))
    self.menu_root:SetPosition(-350, 0, 0)

    self.menu_scroll_root = self.menu_root:AddChild(Widget("MENU_SCROLL_ROOT"))
    self.menu_scroll_root:SetPosition(0, 0, 0)

    self.content_root = self.guide_view:AddChild(Widget("CONTENT_ROOT"))
    self.content_root:SetPosition(150, 0, 0)

    self.content_title = self.content_root:AddChild(Text(DEFAULTFONT, 40))
    self.content_title:SetPosition(0, 150, 0)
    self.content_title:SetColour(1, 0.9, 0.5, 1)

    self.content_text = self.content_root:AddChild(Text(DEFAULTFONT, 30))
    self.content_text:SetPosition(0, -20, 0)
    self.content_text:SetColour(1, 0.95, 0.8, 1)
    self.content_text:SetVAlign(ANCHOR_TOP)
    self.content_text:SetHAlign(ANCHOR_LEFT)
    self.content_text:SetRegionSize(400, 300)

    self:CreateMenuButtons()

    self.prev_button = self.guide_view:AddChild(TEMPLATES.StandardButton(function() self:OnPrevPage() end, STRINGS.PREV_PAGE or "<", {50, 50}))
    self.prev_button:SetPosition(-100, -260, 0)

    self.next_button = self.guide_view:AddChild(TEMPLATES.StandardButton(function() self:OnNextPage() end, STRINGS.NEXT_PAGE or ">", {50, 50}))
    self.next_button:SetPosition(100, -260, 0)

    -- ================================================================
    -- 2. 任务计划视图 (Planner View)
    -- ================================================================
    self.add_task_button = self.planner_view:AddChild(TEMPLATES.StandardButton(
        function() self:ShowSignInputModal() end,
        STRINGS.ADD_TASK_BUTTON or "添加任务", {120, 50}
    ))
    self.add_task_button:SetPosition(0, -250, 0)

    self.tasks_panel = self.planner_view:AddChild(Widget("TASKS_PANEL"))
    self.tasks_panel:SetPosition(0, 50, 0)

    self.task_list = self.tasks_panel:AddChild(Widget("TASK_LIST"))
    self.task_list:SetPosition(0, 0, 0)

    -- 初始化恢复上次阅读章节
    local last_page_id = self.owner and self.owner.atlas_book_data and self.owner.atlas_book_data.last_page
    if last_page_id then
        for _, chapter in ipairs(FLAT_CHAPTERS) do
            if chapter.id == last_page_id then
                self.expanded_sections[chapter.section_id] = true
                self:CreateMenuButtons()
                self:SetChapter(last_page_id)
                break
            end
        end
    else
        if #FLAT_CHAPTERS > 0 then
            self:SetChapter(FLAT_CHAPTERS[1].id)
        end
    end

    self:SetView("guide")
    self:RequestTaskSync()

    -- 监听任务列表同步事件
    self.inst:ListenForEvent("atlas_todolist_updated", function()
        self:UpdateTaskList()
    end, TheWorld)
end)

-- 纯客户端呼出官方 WriteableWidget 告示牌输入弹窗
function AtlasBookUI:ShowSignInputModal()
    local config = {
        prompt = STRINGS.INPUT_PROMPT or "输入任务内容:",
        animbank = "ui_board_5x3",
        animbuild = "ui_board_5x3",
        menuoffset = Vector3(6, -70, 0),
        maxcharacters = 100,
        cancelbtn = {
            text = STRINGS.CANCEL_BUTTON or "取消",
            control = CONTROL_CANCEL,
        },
        middlebtn = {
            text = STRINGS.CLEAR_BUTTON or "清空",
            cb = function(inst, doer, widget)
                widget:OverrideText("")
            end,
            control = CONTROL_MENU_MISC_2,
        },
        acceptbtn = {
            text = STRINGS.CONFIRM_BUTTON or "确定",
            cb = function(inst, doer, widget)
                local text = widget:GetText()
                if text and text:gsub("%s+", "") ~= "" then
                    self:AddTask(text)
                end
            end,
            control = CONTROL_ACCEPT,
        },
    }

    local dummy_inst = CreateEntity()
    local screen = WriteableWidget(self.owner or ThePlayer, dummy_inst, config)
    TheFrontEnd:PushScreen(screen)
    if TheFrontEnd:GetActiveScreen() == screen then
        screen.edit_text:SetEditing(true)
    end
end

function AtlasBookUI:AddTask(text)
    if TheWorld and TheWorld.components.atlas_todolist and TheWorld.ismastersim then
        TheWorld.components.atlas_todolist:AddTask(text)
    else
        local rpc = GetModRPC("atlas_book", "add_task")
        if rpc then SendModRPCToServer(rpc, text) end
    end
end

function AtlasBookUI:ToggleTask(id, is_completed)
    if TheWorld and TheWorld.components.atlas_todolist and TheWorld.ismastersim then
        TheWorld.components.atlas_todolist:ToggleTask(id, is_completed)
    else
        local rpc = GetModRPC("atlas_book", "toggle_task")
        if rpc then SendModRPCToServer(rpc, id, is_completed) end
    end
end

function AtlasBookUI:DeleteTask(id)
    if TheWorld and TheWorld.components.atlas_todolist and TheWorld.ismastersim then
        TheWorld.components.atlas_todolist:DeleteTask(id)
    else
        local rpc = GetModRPC("atlas_book", "delete_task")
        if rpc then SendModRPCToServer(rpc, id) end
    end
end

function AtlasBookUI:RequestTaskSync()
    if TheWorld and TheWorld.components.atlas_todolist and TheWorld.ismastersim then
        self:UpdateTaskList()
    else
        local rpc = GetModRPC("atlas_book", "sync_tasks")
        if rpc then SendModRPCToServer(rpc) end
    end
end

function AtlasBookUI:SetView(view_name)
    self.current_view = view_name
    if view_name == "guide" then
        self.guide_view:Show()
        self.planner_view:Hide()
        self.guide_tab_button:SetTextColour(0.8, 0, 0, 1)
        self.planner_tab_button:SetTextColour(0, 0, 0, 1)
    elseif view_name == "planner" then
        self.guide_view:Hide()
        self.planner_view:Show()
        self.guide_tab_button:SetTextColour(0, 0, 0, 1)
        self.planner_tab_button:SetTextColour(0.8, 0, 0, 1)
        self:UpdateTaskList()
    end
end

function AtlasBookUI:UpdateTaskList()
    if self.task_items then
        for _, item in pairs(self.task_items) do
            if item and item.Kill then item:Kill() end
        end
    end
    self.task_items = {}
    if not self.task_list then return end

    local tasks = {}
    if TheWorld and TheWorld.components and TheWorld.components.atlas_todolist and TheWorld.ismastersim then
        tasks = TheWorld.components.atlas_todolist:GetTasks() or {}
    elseif _G.ATLAS_CLIENT_DATA and _G.ATLAS_CLIENT_DATA.tasks then
        tasks = _G.ATLAS_CLIENT_DATA.tasks
    end

    local y_offset = 200
    for i, task_data in ipairs(tasks) do
        local task_item = self:CreateTaskItem(task_data)
        if task_item then
            task_item:SetPosition(0, y_offset, 0)
            self.task_list:AddChild(task_item)
            table.insert(self.task_items, task_item)
            y_offset = y_offset - 60
        end
    end
end

function AtlasBookUI:CreateTaskItem(task)
    if not task or not task.id or not task.text then return nil end

    local item = Widget("task_item_" .. task.id)

    -- 状态切换按钮
    local status_button = item:AddChild(TEMPLATES.StandardButton(
        function() self:ToggleTask(task.id, not task.completed) end,
        task.completed and (STRINGS.COMPLETED_TASK or "✓") or (STRINGS.PENDING_TASK or "□"),
        {40, 40}
    ))
    status_button:SetPosition(-400, 0, 0)

    -- 任务内容文本
    local task_text = item:AddChild(Text(DEFAULTFONT, 32))
    task_text:SetPosition(-180, 0, 0)
    task_text:SetRegionSize(400, 50)
    task_text:SetHAlign(ANCHOR_LEFT)
    task_text:SetString(task.text)

    if task.completed then
        task_text:SetColour(0.5, 0.5, 0.5, 1)
    else
        task_text:SetColour(1, 0.95, 0.8, 1)
    end

    -- 删除按钮
    local delete_button = item:AddChild(TEMPLATES.StandardButton(
        function() self:DeleteTask(task.id) end,
        STRINGS.DELETE_BUTTON or "删除",
        {80, 40}
    ))
    delete_button:SetPosition(250, 0, 0)

    return item
end

-- ================================================================
-- 静态攻略目录与翻页控制
-- ================================================================
function AtlasBookUI:CreateMenuButtons()
    if self.menu_buttons then
        for _, button in pairs(self.menu_buttons) do button:Kill() end
    end
    self.menu_buttons = {}
    local y_offset = 250

    for section_id, section_data in pairs(GUIDE_DATA) do
        if section_data.is_section then
            local section_button = self.menu_scroll_root:AddChild(TEMPLATES.StandardButton(
                function() self:ToggleSection(section_id) end,
                (self.expanded_sections[section_id] and "v " or "> ") .. section_data.title,
                {220, 50}
            ))
            section_button:SetPosition(0, y_offset, 0)
            section_button:SetTextColour(0, 0, 0, 1)
            section_button:SetTextSize(30)
            self.menu_buttons[section_id] = section_button
            y_offset = y_offset - 55

            if self.expanded_sections[section_id] and section_data.children then
                for chapter_id, chapter_data in pairs(section_data.children) do
                    if not chapter_data.is_section then
                        local chapter_button = self.menu_scroll_root:AddChild(TEMPLATES.StandardButton(
                            function() self:SetChapter(chapter_id) end,
                            "   " .. chapter_data.title,
                            {200, 45}
                        ))
                        chapter_button:SetPosition(10, y_offset, 0)
                        chapter_button:SetTextColour(0, 0, 0, 1)
                        chapter_button:SetTextSize(26)
                        self.menu_buttons[chapter_id] = chapter_button
                        y_offset = y_offset - 50
                    end
                end
            end
        end
    end
end

function AtlasBookUI:ToggleSection(section_id)
    self.expanded_sections[section_id] = not self.expanded_sections[section_id]
    self:CreateMenuButtons()
end

function AtlasBookUI:SetChapter(chapter_id)
    local chapter_data
    for sid, section in pairs(GUIDE_DATA) do
        if section.is_section and section.children and section.children[chapter_id] then
            chapter_data = section.children[chapter_id]
            break
        end
    end

    if chapter_data then
        self.current_chapter_id = chapter_id
        self.content_title:SetString(chapter_data.title)
        self.content_text:SetString(chapter_data.text)

        for id, button in pairs(self.menu_buttons) do
            if id == chapter_id then
                button:SetTextColour(0.8, 0, 0, 1)
            else
                button:SetTextColour(0, 0, 0, 1)
            end
        end

        if self.owner and self.owner.atlas_book_data then
            self.owner.atlas_book_data.last_page = chapter_id
        end
        self:UpdatePageButtons()
    end
end

function AtlasBookUI:OnPrevPage()
    local current_index
    for i, chapter in ipairs(FLAT_CHAPTERS) do
        if chapter.id == self.current_chapter_id then current_index = i break end
    end
    if current_index and current_index > 1 then
        local prev = FLAT_CHAPTERS[current_index - 1]
        self.expanded_sections[prev.section_id] = true
        self:CreateMenuButtons()
        self:SetChapter(prev.id)
    end
end

function AtlasBookUI:OnNextPage()
    local current_index
    for i, chapter in ipairs(FLAT_CHAPTERS) do
        if chapter.id == self.current_chapter_id then current_index = i break end
    end
    if current_index and current_index < #FLAT_CHAPTERS then
        local nxt = FLAT_CHAPTERS[current_index + 1]
        self.expanded_sections[nxt.section_id] = true
        self:CreateMenuButtons()
        self:SetChapter(nxt.id)
    end
end

function AtlasBookUI:UpdatePageButtons()
    local current_index
    for i, chapter in ipairs(FLAT_CHAPTERS) do
        if chapter.id == self.current_chapter_id then current_index = i break end
    end
    if current_index == 1 then self.prev_button:Disable() else self.prev_button:Enable() end
    if current_index == #FLAT_CHAPTERS then self.next_button:Disable() else self.next_button:Enable() end
end

function AtlasBookUI:Close()
    if self.owner and self.owner.atlas_book_data and self.current_chapter_id then
        self.owner.atlas_book_data.last_page = self.current_chapter_id
    end
    TheFrontEnd:PopScreen(self)
end

function AtlasBookUI:OnControl(control, down)
    if AtlasBookUI._base.OnControl(self, control, down) then return true end
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
end

return AtlasBookUI
