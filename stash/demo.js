// Stash 注入脚本：删除第一条规则
let config = JSON.parse($files[0]);

if (config.rules && config.rules.length > 0) {
    // 删掉第一条规则
    config.rules.shift(); 
    console.log("成功删除第一条规则");
} else {
    console.log("未找到规则列表或规则为空");
}

// 必须调用 $done 把修改后的配置传回给 Stash
$done(config);