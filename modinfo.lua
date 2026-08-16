name = "万象书 · 任务与协同看板 (Codex Astralis)"
description = "【万象全书】一本出生自带的生存看板全书，支持个人私密计划与团队公有目标双模态自由切换！\n\n★ 核心特性：\n1. 个人私密计划：专属待办事项，物理隔离，仅自己可见；\n2. 团队公有目标：全服实时共享，任何人打勾即刻全员毫秒级同步；\n3. 双模态自由切换：支持【全景双列看板】与【超宽单列聚焦】秒级一键切换；\n4. 官方原生打字弹窗：支持中文输入法流畅打字与关闭；\n5. 永久持久化：随世界存档自动保存，退出重进数据永久不丢。"
author = "Codex Team"
version = "5.0"
forumthread = ""

api_version_dst = 10

all_clients_require_mod = true
client_only_mod = false

reign_of_giants_compatible = false
dont_starve_compatible = false
dst_compatible = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options =
{
    {
        name = "fos",
        hover = "设置化石碎片配方数量 Configure the number of fossil pieces",
        label = "化石数量 num_fossil pieces",
        options = {
            {description = "1", data = 1, hover = ""},
            {description = "2", data = 2, hover = ""},
        },
        default = 1,
    }
}