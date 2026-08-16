# 📜 万象书 · 任务协同看板 (Codex Astralis)

![万象全书 Banner](https://helpfulcraft-blog.oss-cn-beijing.aliyuncs.com/20250824164415.png)

> **Steam 创意工坊订阅地址**：[https://steamcommunity.com/sharedfiles/filedetails/?id=3555025039](https://steamcommunity.com/sharedfiles/filedetails/?id=3555025039)  
> **作者**：哈基米 (unendev)  
> **最新版本**：v5.2 (Major Release)  
> **支持平台**：《饥荒联机版》(Don't Starve Together)

---

## ✨ 核心特性 (Features)

* **🔒 个人私密计划 (Personal Todo List)**
  * **物理级隐私隔离**：每位玩家拥有专属的 `userid` 私有独立账本，你的个人计划仅你自己可见。
  * **开局即送**：出生自动获得《任务协同看板》，丢失后可在制作栏徒手（莎草纸×2 + 化石碎片×1）重新合成。

* **⚔️ 团队公有目标 (Shared Team Goals)**
  * **全服实时协同**：所有队员共享同一套团队目标，任何人添加、打勾完成或删除，全员毫秒级广播同步。
  * **永久持久化**：随世界存档（`OnSave` / `OnLoad`）自动序列化，服务器重启数据永不丢失。

* **⛶ 双模态自由切换 (Dual & Single Hybrid View)**
  * **全景双列看板**：左列个人、右列团队，全局战略一览无余。
  * **超宽单列聚焦**：顶部单键随时切换，提供超宽大字体与极佳的阅读舒适感。
  * **右上角极简切换**：一键在“双列全景”与“单列聚焦”之间毫秒级平滑过渡。

* **📜 官方原装平滑滚轮列表 (ScrollableList Integration)**
  * **支持 100+ 超长任务**：彻底告别文字溢出与穿帮。
  * **丝滑滚轮浏览**：鼠标悬停即可上下滑动，配备官方自适应复古木质滚动条。

* **⚡ 极速秒开模式 (Instant Opening)**
  * **0 动作硬直**：彻底消除原版 1.5 秒举书施法慢动作，边跑边看、极速响应。
  * **游戏中动态切换**：看板左上角支持随时在【⚡ 秒开模式】与【📖 经典施法】之间一键点选切换。

* **✍️ 官方原生打字弹窗 (Native IME Writing Modal)**
  * 原生木牌弹窗，完美支持中英文输入法流畅打字。
  * 支持确定、清空、取消及点击背景空白处一键关闭。

---

## 🏗️ 架构与技术实现 (Architecture & Best Practices)

本项目严格遵循《饥荒联机版》工业级 C/S 分离规范与防御性编程原则：

```
                              ┌────────────────────────────────────────────────────────┐
                              │          C/S 分层架构与全栈单一真理源 (Single Source)     │
                              └──────────────────────────┬─────────────────────────────┘
                                                         │
                   ┌─────────────────────────────────────┴─────────────────────────────────────┐
                   ▼                                                                           ▼
┌───────────────────────────────────────┐                   ┌─────────────────────────────────────────────────┐
│        服务端 (Authoritative Server)   │                   │             客户端 (Client UI Layer)            │
├───────────────────────────────────────┤                   ├─────────────────────────────────────────────────┤
│ • atlas_todolist.lua (世界挂载组件)   │                   │ • atlasbook_ui.lua (双模态自适应看板)            │
│ • personal_tasks[userid] 物理分池     │                   │ • ScrollableList 官方滚轮视口                   │
│ • team_tasks 团队公有池               │                   │ • WriteableWidget 原生输入弹窗                  │
│ • 单播 (Unicast) + 广播 (Broadcast)   │                   │ • _G.ATLAS_CLIENT_DATA 本地响应式渲染           │
└───────────────────────────────────────┘                   └─────────────────────────────────────────────────┘
```

* **安全通信总线**：基于 `SendModRPCToServer` 与 `SendModRPCToClient` 构建鉴权网络。
* **生命周期闭环**：通过 `AddPrefabPostInit("world")` 挂载组件，严格保证存档加载时序。
* **8 项全真端到端压测**：内置 `c_test_atlas()` 原生 E2E 自动化测试探针，覆盖协议、多用户隔离、存读盘与界面切换。

---

## 📂 工程目录结构 (Project Structure)

```
dst-codex-astralis/
├── .agent/                   # 核心架构知识库 (DATA_MODEL, BUSINESS_LOGIC, STANDARDS, LOGS, MEMORY)
├── anim/                     # 物品动画资源 (book_fossil.zip, swap_book_fossil.zip)
├── images/                   # 贴图与图标 Atlas (inventoryimages, dialogcurly_9slice)
├── scripts/
│   ├── components/
│   │   └── atlas_todolist.lua# 服务端权威数据组件 (物理隔离与持久化)
│   ├── prefabs/
│   │   └── atlas_book.lua    # 万象看板物品预制体
│   └── widgets/
│       └── atlasbook_ui.lua  # 双模态自适应 UI (ScrollableList + WriteableWidget)
├── modinfo.lua               # 模组元数据与配置定义 (v5.2)
├── modmain.lua               # 网络 RPC 协议、动作拦截与生命周期注入
├── modworldgenmain.lua       # 世界生成挂载入口
└── README.md                 # 项目说明文档
```

---

## 🤝 贡献与反馈 (Contribution)

欢迎提交 Issue 或 Pull Request！我们坚持“宁慢勿脏，步步留痕”的工程原则，共同打造高品质的《饥荒联机版》联机工具。

---

### 📄 开源协议 (License)
本项目基于 MIT 协议开源。
