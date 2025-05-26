/*
-------------------------------------
用于 SubStore 来覆写 FICalsh 配置的脚本
版本 v1.0-250526
作者: yangtudou
FICalsh 版本: 0.8.84
-------------------------------------
可以自定义的参数包括:
- 手动代理节点群组名称 proxyName
- 
-------------------------------------
脚本参考自：https://linux.do/t/topic/235314
理论来讲也是适用于 mihomo (Clash Meta), 但我没做测试
转载的话请保留以上注释
*/

/* -------- 自定义参数部分 Start -------- */
// default: Proxy
const proxyName = "节点选择";
// 国家地区分类
// 这里存在排列顺序
const REGION_NAMES = ['香港', '台湾', '新加坡', '日本', '美国'];
const isAdRules = false;

/* -------- 自定义参数部分 End -------- */

/* -------- 主程序 Start -------- */
function main(params) {
  if (!params.proxies) return params; // 判断有无节点信息
  overwriteRules(params); // 覆写规则
  overwriteProxyGroups(params); // 覆写代理组
  overwriteDns(params); // 覆写 DNS
  return params; // 返回覆写后的结果
}
/* -------- 主程序 End -------- */

/* -------- 过滤国家地区 Start -------- */
const createRegion = (name) => {
  // 完整的地区列表（包含所有预定义地区）
  const CONFIG_MAP = {
    '香港': { code: 'HK', emoji: '🇭🇰', aliases: ['HK', 'Hong Kong'] },
    '台湾': { code: 'TW', emoji: '🇨🇳', aliases: ['TW', 'Taiwan'] },
    '新加坡': { code: 'SG', emoji: '🇸🇬', aliases: ['SG', 'Singapore', '狮城'] },
    '日本': { code: 'JP', emoji: '🇯🇵', aliases: ['JP', 'Japan'] },
    '美国': { code: 'US', emoji: '🇺🇲', aliases: ['US', 'USA', 'United States', 'America'] },
    '德国': { code: 'DE', emoji: '🇩🇪', aliases: ['DE', 'Germany'] },
    '韩国': { code: 'KR', emoji: '🇰🇷', aliases: ['KR', 'Korea', 'South Korea'] },
    '英国': { code: 'UK', emoji: '🇬🇧', aliases: ['UK', 'United Kingdom', 'Britain', 'Great Britain'] },
    '加拿大': { code: 'CA', emoji: '🇨🇦', aliases: ['CA', 'Canada'] },
    '澳大利亚': { code: 'AU', emoji: '🇦🇺', aliases: ['AU', 'Australia'] }
  };

  const { code, emoji, aliases } = CONFIG_MAP[name];
  
  return {
    code,
    name: `${emoji} ${name}`,
    icon: `https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/${code.toLowerCase()}.svg`,
    regex: new RegExp(
      `^(?=.*(${[name, ...aliases, emoji].join('|')}))` + // 必须包含地区关键词
      `(?!.*海外用户专用).+$`, // 排除指定关键词
      'i' // 字符串结束，忽略大小写
    )
  };
};

const countryRegions = REGION_NAMES.map(createRegion);
/* -------- 过滤国家地区 End -------- */

/* -------- 功能函数 Start -------- */
// 覆写规则 & 规则集
function overwriteRules(params) {
  const adRules = [
    "RULE-SET,秋风广告规则,REJECT" // 目前使用秋风广告规则，体验还行
  ];
  const customRules = [
    "DOMAIN-SUFFIX,linux.do,节点选择",
    "DOMAIN,limbopro.com,节点选择",
    "DOMAIN-SUFFIX,y3-3am.top,DIRECT",
  ];
  // 基础分流规则
  const rules = [
    ...(isAdRules ? adRules : []), // 如果开启广告，插入最顶部
    ...customRules, // 在顶部插入自定义分流规则
    "GEOIP,lan,DIRECT,no-resolve",
    `RULE-SET,github_domain,${proxyName}`,
    `RULE-SET,twitter_domain,${proxyName}`,
    `RULE-SET,youtube_domain,${proxyName}`,
    `RULE-SET,google_domain,${proxyName}`,
    `RULE-SET,telegram_domain,${proxyName}`,
    "RULE-SET,bilibili_domain,DIRECT",
    `RULE-SET,geolocation-!cn,${proxyName}`, // 漏网之鱼?
    // geoip
    `RULE-SET,google_ip,${proxyName}`,
    `RULE-SET,telegram_ip,${proxyName}`,
    "RULE-SET,cn_domain,DIRECT",
    "RULE-SET,cn_ip,DIRECT",
    "MATCH,漏网之鱼",
  ];
  // 定义 规则集
  // 需要对应的上前面的分流规则，否则报错
  const GEO_CONFIG = {
    geosite: {
      baseUrl: "https://geosite-source.com/meta-rules-dat/meta/geo/geosite", // 独立 geosite 源
      behavior: "domain",
      keySuffix: "_domain" // 键名生成规则
    },
    geoip: {
      baseUrl: "https://geoip-source.net/meta-rules-dat/meta/geo/geoip", // 独立 geoip 源
      behavior: "ipcidr",
      keySuffix: "_ip" // 键名生成规则
    }
  };
  const createRuleProviders = (name, type) => ({
    type: "http",
    interval: 86400,
    format: "yaml",
    behavior: GEO_CONFIG[type].behavior,
    url: `${GEO_CONFIG[type].baseUrl}/${name}.yaml`
  });
  const ruleProvidersList = [
    // Geosite 配置组
    ...[
      'github', 'twitter', 'youtube', 
      'google', 'telegram', 'bilibili',
      { customKey: 'geolocation-!cn', name: 'geolocation-!cn' },
      { customKey: 'cn_domain', name: 'cn' }
    ].map(item => ({
      type: 'geosite',
      ...(typeof item === 'string' ? { name: item } : item)
    })),
    // Geoip 配置组
    ...['google', 'telegram', 'cn'].map(name => ({
      type: 'geoip',
      name
    }))
  ];
  const ruleProviders = Object.fromEntries(
    ruleProvidersList.map(({ type, name, customKey }) => [
      customKey || `${name}${GEO_CONFIG[type].keySuffix}`,
      createRuleProviders(name, type)
    ])
  );
  
  // const ruleProviders = {
  //   ...(isAdRules && {
  //     "秋风广告规则": {
  //       type: "http",
  //       interval: 86400,
  //       behavior: "domain",
  //       format: "yaml",
  //       url: "https://gcore.jsdelivr.net/gh/TG-Twilight/AWAvenue-Ads-Rule@main/Filters/AWAvenue-Ads-Rule-Clash.yaml",
  //     }
  //   }),
  //   github_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/github.yaml"
  //   },
  //   twitter_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/twitter.yaml"
  //   },
  //   youtube_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/youtube.yaml"
  //   },
  //   google_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/google.yaml"
  //   },
  //   telegram_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/telegram.yaml"
  //   },
  //   bilibili_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/bilibili.yaml"
  //   },
  //   "geolocation-!cn": {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/geolocation-!cn.yaml"
  //   },
  //   cn_domain: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "domain",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/cn.yaml"
  //   },
  //   // geoip
  //   google_ip: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "ipcidr",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/google.yaml"
  //   },
  //   telegram_ip: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "ipcidr",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/telegram.yaml"
  //   },
  //   cn_ip: {
  //     type: "http",
  //     interval: 86400,
  //     behavior: "ipcidr",
  //     format: "yaml",
  //     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/cn.yaml"
  //   },
  // };
  // 写入规则集合&规则
  params["rule-providers"] = ruleProviders;
  params["rules"] = rules;
}

// 定义过滤的函数
// 如未匹配到，将输出为 DIRECT （直连）
function getProxiesByRegex(params, regex) {
  const matchedProxies = params.proxies.filter((e) => regex.test(e.name)).map((e) => e.name);
  return matchedProxies.length > 0 ? matchedProxies : ["DIRECT"];
}

// 代理规则集
function overwriteProxyGroups(params) {
  const allProxies = params["proxies"].map((e) => e.name);

  // 定义自动选择节点
  const autoProxyGroupRegexs = countryRegions.map(region => ({
    // 代理组按照区域分组
    name: `${region.name}自动`,
    regex: region.regex,
  }));

  const autoProxyGroups = autoProxyGroupRegexs
    .map((item) => ({
      name: item.name,
      type: "url-test",
      url: "http://www.gstatic.com/generate_204",
      lazy: true,
      interval: 300,
      tolerance: 50,
      proxies: getProxiesByRegex(params, item.regex),
      hidden: true,
    }))
    .filter((item) => item.proxies.length > 0);
  // 定义代理组名
  const groups = [
    {
      name: proxyName,
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Proxy.png",
      proxies: ["区域自动", "DIRECT"],
    },
    {
      name: "区域自动",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Auto.png",
      proxies: [...countryRegions.flatMap(region => [`${region.name}自动`, ]), "DIRECT", ],
    },
    {
      name: "漏网之鱼",
      type: "select",
      proxies: ["DIRECT", proxyName],
      icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Final.png",
    },
  ];

  groups.push(...autoProxyGroups);
  params["proxy-groups"] = groups;
}
// DNS 部分
// 防止 DNS 泄露
function overwriteDns(params) {
  const cnDnsList = ["https://223.5.5.5/dns-query", "https://1.12.12.12/dns-query"];
  const trustDnsList = ["quic://dns.cooluc.com", "https://1.0.0.1/dns-query", "https://1.1.1.1/dns-query"];
  const dnsOptions = {
    enable: true,
    ipv6: false,
    "prefer-h3": false,
    "use-hosts": false,
    "use-system-hosts": false,
    "respect-rules": true,
    "enhanced-mode": "fake-ip",
    "fake-ip-range": "198.18.0.1/16",
    "fake-ip-filter": ["+.lan", "+.local", "+.msftconnecttest.com", "+.msftncsi.com", "localhost.ptlogin2.qq.com", "localhost.sec.qq.com", "localhost.work.weixin.qq.com"],
    "default-nameserver": ["tls://223.5.5.5", "tls://119.29.29.29"],
    "nameserver": ["https://223.5.5.5/dns-query", "https://1.12.12.12/dns-query"],
    "proxy-server-nameserver": ["https://doh.pub/dns-query"],
    "direct-nameserver": ["https://doh.pub/dns-query", "https://dns.alidns.com/dns-query"],
  };

  // geox-url
  const rawGeoxURLs = {
    geoip: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat",
    geosite: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat",
    mmdb: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb",
    asn: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb",
  };

  // 其他配置 部分
  const otherOptions = {
    "port": 7890,
    "socks-port": 7891,
    "mixed-port": 7893,
    "ipv6": false,
    "allow-lan": false,
    "log-level": "info",
    "mode": "rule",
    "geo-auto-update": true,
    profile: {
      "store-selected": true,
      "store-fake-ip": true
    },
    sniffer: {
      "enable": true,
      "force-dns-mapping": true,
      "parse-pure-ip": true,
      "override-destination": false,
      sniff: {
        HTTP: {
          ports: [80, "8080-8880"],
        },
        TLS: {
          ports: [443, 8443]
        },
        QUIC: {
          ports: [443, 8443],
        },
      },
      "force-domain": ["+.v2ex.com"],
      "skip-domain": ["Mijia Cloud", "+.oray.com"],
    },
    "geodata-mode": true,
    "geox-url": rawGeoxURLs,
  };
  params.dns = {
    ...params.dns,
    ...dnsOptions
  };

  Object.keys(otherOptions).forEach((key) => {
    params[key] = otherOptions[key];
  });
}
