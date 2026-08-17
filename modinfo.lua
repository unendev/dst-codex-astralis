name = "任务协同看板"
description = "一本出生自带的todo看板，支持个人与团队看板"
author = "哈基米"
version = "5.3"
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
        name = "reading_anim",
        hover = "设置右键阅读时是否播放举书施法动画 (游戏中也可在看板内随时切换)",
        label = "翻书动作",
        options = {
            { description = "极速秒开 (推荐/0硬直)", data = false, hover = "右键瞬间打开看板，角色不停步零硬直" },
            { description = "经典施法动作", data = true, hover = "播放原版角色举书施法动作" },
        },
        default = false,
    },
    {
        name = "fos",
        hover = "设置化石碎片配方数量 Configure the number of fossil pieces",
        label = "化石数量 num_fossil pieces",
        options = {
            { description = "1", data = 1, hover = "" },
            { description = "2", data = 2, hover = "" },
        },
        default = 1,
    }
}