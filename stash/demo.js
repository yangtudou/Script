/**
 * Stash 配置文件覆写脚本 - 节点清理测试
 * 作用：清空所有手动节点和订阅节点，并将所有策略组指向 DIRECT
 */

// 1. 获取当前配置对象
let config = JSON.parse($files[0]);

// 2. 清空手动定义的节点列表
if (config.proxies) {
    console.log("正在清理手动节点...");
    config.proxies = [];
}

// 3. 清空订阅节点 (Providers)
if (config["proxy-providers"]) {
    console.log("正在清理订阅 Provider...");
    config["proxy-providers"] = {};
}

// 4. 修复策略组 (防止 Stash 因为找不到节点而报错)
if (config["proxy-groups"]) {
    config["proxy-groups"].forEach(group => {
        // 将所有组的节点列表重置为只包含 DIRECT
        group.proxies = ["DIRECT"];
        
        // 如果该组使用了 use (provider)，也一并删掉
        if (group.use) {
            delete group.use;
        }
    });
}

// 5. 返回修改后的配置
$done(config);