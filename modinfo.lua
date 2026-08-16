name = "★【本地开发版】万象书 (Codex Astralis)★"
description = "【当前为本地开发工程目录: workshop-todo-sync】\n★一本出生自带的超级指南，内置新手攻略、团队规划！★"
author = "Codex Team"
version = "4.2"
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