/**
 * Stash 控制面板脚本 (Tile)
 * 作用：在首页显示当前的配置状态和 IP
 */

$httpClient.get('http://ip-api.com/json', (error, response, data) => {
    if (error) {
        $done({
            title: "网络错误",
            content: "无法获取 IP 信息",
            icon: "exclamationmark.triangle",
            "icon-color": "#FF0000"
        });
    } else {
        const info = JSON.parse(data);
        $done({
            title: "当前节点位置",
            content: `地区: ${info.city}\n运营商: ${info.isp}\nIP: ${info.query}`,
            icon: "network",
            "icon-color": "#5AC8FA"
        });
    }
});