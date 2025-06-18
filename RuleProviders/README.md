# 说明
> **自用规则集，使用请谨慎。**


**不同文件夹内对应不同的规则集**


## a_dobe_dumb 弹窗的规则
> 适用于 FIClash、Mihomo Party、Stash
> 
> 在源规则 [a-dove-is-dumb](https://github.com/ignaciocastro/a-dove-is-dumb) 的基础上
> 去掉了所有开头的 `DOMAIN` ，使 ` behavior: domain` 而不是原版的 ` behavior: classical`
> 
> 同时我重写了一份 yaml ，用了 clash 的域名匹配方法，精简了规则文件。

使用方法：
```
# 原版修改
rules:
  RULE-SET,a_dobe_dumb,REJECT
rule-providers:
  a_dobe_dumb:
    behavior: domain
    format: text
    interval: 86400
    url: https://raw.githubusercontent.com/yangtudou/Script/refs/heads/main/RuleProviders/Stash/AWAvenue-Ads-Rule-Clash.yaml # 本仓库订阅地址
```

```
# yP0tat0 重写
rules:
  RULE-SET,a_dobe_dumb,REJECT
rule-providers:
  a_dobe_dumb:
    behavior: domain
    format: text
    interval: 86400
    url: https://raw.githubusercontent.com/yangtudou/Script/refs/heads/main/RuleProviders/Stash/a_dobe_dumb_bug.yaml
```

