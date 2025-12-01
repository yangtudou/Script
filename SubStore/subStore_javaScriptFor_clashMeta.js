function main(config) {
  /* base config */
  // 全覆盖的方法如下
  // Object.keys(config).forEach(key => delete config[key]);
  // 不会全覆盖原先的配置
  Object.assign(config, {
    // --------------------
    "mixed-port": 7890,
    "ipv6":true,
    "allow-lan": true,
    "unified-delay": false,
    "tcp-concurrent": true,
    "external-controller": "127.0.0.1:9090",
    "external-ui": "ui",
    "external-ui-url": "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip",
    // --------------------
    "geodata-mode": true,
    "geox-url": {
      "geoip": "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat",
      "geosite": "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat",
      "mmdb": "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb",
      "asn": "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb"
    },
    // --------------------
    "find-process-mode": "strict",
    "global-client-fingerprint": "chrome",
    // --------------------
    "profile": {
      "store-selected": true,
      "store-fake-ip": true
    },
    // --------------------
    "sniffer": {
      "enable": true,
      "sniff": {"HTTP": {"ports": [80,"8080-8880"],"override-destination": true},"TLS": {"ports": [443,8443]},"QUIC": {ports: [443, 8443]}},
      "skip-domain":["Mijia Cloud","+.push.apple.com"]
    },
    // --------------------
    "tun": {
      "enable": true,
      "stack": "mixed",
      "dns-hijack": ["any:53","tcp://any:53"],
      "auto-route": true,
      "auto-redirect": true,
      "auto-detect-interface": true
    },
    // --------------------
    "dns": {
      "enable": true,
      "ipv6": true,
      "enhanced-mode": "fake-ip",
      "fake-ip-filter": ["*","+.lan","+.local","+.market.xiaomi.com"],
      "default-nameserver": ["tls://223.5.5.5","tls://223.6.6.6"],
      " nameserver": ["https://doh.pub/dns-query","https://dns.alidns.com/dns-query"]
    }
    // --------------------
  });
  
  /*------ 策略组 ------*/
  config["proxy-groups"] = [
    // 梦开始的地方
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/Static.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      name: "PROXY",
      type: "select",
      proxies: ["AUTO", "HK AUTO", "SG AUTO", "JP AUTO", "US AUTO"],
    },
    // 自动策略
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/Urltest.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      name: "AUTO",
      type: "url-test",
      interval: 300,
    },
    // 人工智能策略
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/OpenAI.png",
      name: "AIGC",
      type: "select",
      proxies: ["SG AUTO", "JP AUTO", "US AUTO"],
    },
    // 电报策略
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/Telegram.png",
      name: "Telegram",
      type: "select",
      proxies: ["HK AUTO", "SG AUTO", "JP AUTO", "US AUTO"],
    },
    // 谷歌策略
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/Google.png",
      name: "Google",
      type: "select",
      proxies: ["HK AUTO", "SG AUTO", "JP AUTO", "US AUTO"],
    },
    // 香港区域
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/HK.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      filter: "(?i)香港|Hong Kong|HK|🇭🇰",
      name: "HK AUTO",
      type: "url-test",
      interval: 300,
    },
    // 新加坡区域
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/SG.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      filter: "(?i)新加坡|Singapore|🇸🇬",
      name: "SG AUTO",
      type: "url-test",
      interval: 300,
    },
    // 日本区域
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/JP.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      filter: "(?i)日本|Japan|🇯🇵",
      name: "JP AUTO",
      type: "url-test",
      interval: 300,
    },
    // 美国区域
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/US.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      filter: "(?i)美国|USA|🇺🇸",
      name: "US AUTO",
      type: "url-test",
      interval: 300,
    },
    // 区域选择
    {
      icon: "https://testingcf.jsdelivr.net/gh/Orz-3/mini@master/Color/Global.png",
      "include-all": true,
      "exclude-filter": "(?i)GB|Traffic|Expire|Premium|频道|订阅|ISP|流量|到期|重置",
      proxies: ["AUTO", "HK AUTO", "SG AUTO", "JP AUTO", "US AUTO"],
      name: "GLOBAL",
      type: "select",
    }
  ];
  /*------ 远程规则集 ------*/
  // 如果不存在远程规则集合，那么新建字段
  if (!config['rule-providers']) {
    config['rule-providers'] = {};
  }
  // 在现有的规则集上添加新的
  // 这里可以衍生出是否要清空之前的规则集合
  // 或者不使用远程规则集，使用 GEOSITE 的方法之类
  config["rule-providers"] = Object.assign(config["rule-providers"], {
    AWAvenue-Ads: {
      url: "https://raw.githubusercontent.com/yangtudou/Script/refs/heads/main/RuleProviders/Stash/AWAvenue-Ads-Rule-Clash.yaml",
      path: "./ruleset/AWAvenue-Ads.yaml",
      behavior: "domain",
      interval: 86400,
      format: "yaml",
      type: "http",
    },
  });
  
  /*------ 分流规则 ------*/
  // 这里使用的方法是全覆盖
  // 也就是说之前配置里存在的分流规则会被清空
  config["rules"] = [
    // 内网网段
    "GEOIP,PRIVATE,DIRECT",
    "GEOSITE,PRIVATE,DIRECT",
    // GEOSITE
    "GEOSITE,microsoft,DIRECT",
    "GEOSITE,apple,DIRECT",
    "MATCH,DIRECT",
  ];

  
  return config;
}