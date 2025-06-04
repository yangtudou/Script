# 说明
> **自用规则集，使用请谨慎。**


**不同文件夹内对应不同的规则集**


## a_dobe_dumb 弹窗的规则
> 适用于 FIClash、Mihomo Party、Stash

使用方法：
```
rules:
  RULE-SET,a_dobe_dumb,REJECT
rule-providers:
  a_dobe_dumb:
    behavior: domain
    format: text
    interval: 86400
    url: https://raw.githubusercontent.com/yangtudou/Script/refs/heads/main/ruleProviders/a_dobe_dumb.list # 本仓库订阅地址
```

规则来源：https://github.com/ignaciocastro/a-dove-is-dumb

