// 获取整个配置文件对象
let config = JSON.parse($files[0]);

// 逻辑：如果规则存在，删除第一条
if (config.rules && config.rules.length > 0) {
    config.rules.splice(0, 1);
    console.log("成功执行远程脚本：已删除第一条规则");
}

// 必须写 $done 否则配置无法加载
$done(config);