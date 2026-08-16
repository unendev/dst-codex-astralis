name = "任务协同看板"
description = "一本出生自带的todo看板，支持个人与团队看板"
author = "哈基米"
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