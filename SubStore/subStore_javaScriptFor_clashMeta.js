/*
-------------------------------------
用于 SubStore 来覆写 Calsh 配置的脚本
版本 v1.0-250526
作者: yangtudou
FICalsh 版本: 0.8.84
-------------------------------------
脚本参考自：https://linux.do/t/topic/235314
转载的话请保留以上注释
*/

/* -------- 自定义参数部分 Start -------- */
// default: 节点选择
const proxyName = '节点选择';
// 国家地区分类
// 这里存在排列顺序
const REGION_NAMES = [
  '香港',
  '台湾',
  '新加坡',
  '日本',
  '美国'
];
// Rules 模式
// ruleGeoX ruleSet
// 混用的话，暂时不支持
const rulePattern = 'ruleSet';
// 增加去广告规则
const isAdRules = true;
// Adobe 跳激活弹窗
// Github 仓库 https://github.com/ignaciocastro/a-dove-is-dumb?tab=readme-ov-file
const isAdobeBug = true;

/* -------- 自定义参数部分 End -------- */

// 全局配置
const mihomoBaseOptions = {
  "port": 7890,
  "socks-port": 7891,
  "mixed-port": 7893,
  "ipv6": false,
  "allow-lan": false,
  "log-level": "info",
  "mode": "rule",
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
        ports: [
          80,
          "8080-8880"
        ]
      },
      TLS: {
        ports: [
          443,
          8443
        ]
      },
      QUIC: {
        ports: [
          443,
          8443
        ],
      },
    },
    "force-domain": [
      "+.v2ex.com"
    ],
    "skip-domain": [
      "Mijia Cloud",
      "+.oray.com"
    ],
  }
};
if (rulePattern === 'ruleGeoX') {
  mihomoBaseOptions['geo-auto-update'] = true;
  mihomoBaseOptions['geodata-mode'] = true;
  mihomoBaseOptions['geox-url'] = {
    geoip: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat",
    geosite: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat",
    mmdb: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb",
    asn: "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb"
  };
}

const stashBaseOptions = {
  'log-level': 'warning',
  'mode': 'rule'
}

/*
DNS 部分
防止 DNS 泄露，这部分真不太了解
照抄了网上的一些，不知都有没有用
*/
function overwriteDns(params) {
  const dnsOptions = {
    'enable': true,
    'ipv6': false,
    'listen': ':53',
    'enhanced-mode': 'fake-ip',
    'fake-ip-range': '198.18.0.1/16',
    'fake-ip-filter-mode': 'blacklist',
    'prefer-h3': false,
    'respect-rules': false,
    'use-hosts': false,
    'use-system-hosts': false,
    'fake-ip-filter': [
      '*.lan',
      '*.local',
      '*.arpa',
      'time.*.com',
      'ntp.*.com',
      'time.*.com',
      '+.market.xiaomi.com',
      'localhost.ptlogin2.qq.com',
      '*.msftncsi.com',
      'www.msftconnecttest.com'
    ],
    'default-nameserver': [
      'system',
      '114.114.115.115',
      '223.6.6.6'
    ],
    nameserver: [
      'https://doh.pub/dns-query',
      'https://dns.alidns.com/dns-query'
    ],
    'proxy-server-nameserver': [
      'https://doh.pub/dns-query',
      'https://dns.alidns.com/dns-query'
    ],
    'direct-nameserver': [
      'https://doh.pub/dns-query',
      'https://dns.alidns.com/dns-query'
    ],
  };
  params.dns = {
    // ...params.dns,
    ...dnsOptions
  };
}
/* -------- 主程序 Start -------- */
function main(params) {
  if (!params.proxies) return params; // 判断有无节点信息
  writeConfig(params, mihomoBaseOptions)
  overwriteRules(params); // 覆写规则
  overwriteProxyGroups(params); // 覆写代理组
  overwriteDns(params); // 覆写 DNS
  return params; // 返回覆写后的结果
}
/* -------- 主程序 End -------- */

/* 工具类函数 */
// 往配置文件全局添加内容
function writeConfig(target, source) {
    Object.keys(source).forEach(key => {
        target[key] = source[key];
    });
}

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
    "DOMAIN-SUFFIX,linux.do," + proxyName,
    "DOMAIN,limbopro.com," + proxyName,
    "DOMAIN-SUFFIX,y3-3am.top,DIRECT",
  ];
  // 基础分流规则
  // ruleSet
  const ruleSet = [
    'RULE-SET,private_ip,DIRECT,no-resolve', // 局域网 eg: 路由器之类的
    'RULE-SET,bilibili_domain,DIRECT', // b站 包括国际服
    'RULE-SET,github_domain,' + proxyName, // Github
    'RULE-SET,twitter_domain,' + proxyName, // Twitter
    'RULE-SET,youtube_domain,' + proxyName, // Youtube
    'RULE-SET,google_domain,' + proxyName, // Google
    'RULE-SET,telegram_domain,' + proxyName, // Telegram
    'RULE-SET,netflix_domain,' + proxyName, // Netfix 奈飞
    'RULE-SET,bahamut_domain,' + proxyName, // 巴哈姆特
    'RULE-SET,spotify_domain,' + proxyName, // Spotify
    'RULE-SET,cn_domain,DIRECT', // 国内
    'RULE-SET,geolocation-!cn,' + proxyName, // 非国内
    /* ipcidr */
    'RULE-SET,google_ip,' + proxyName,
    'RULE-SET,netflix_ip,' + proxyName,
    'RULE-SET,telegram_ip,' + proxyName,
    'RULE-SET,twitter_ip,' + proxyName,
    'RULE-SET,cn_ip,DIRECT',
    'MATCH,规则之外',
  ];
  const ruleGeoX = [
    'GEOIP,lan,DIRECT,no-resolve',
    'GEOSITE,github,' + proxyName,
    'GEOSITE,twitter,' + proxyName,
    'GEOSITE,youtube,' + proxyName,
    'GEOSITE,google,' + proxyName,
    'GEOSITE,telegram,' + proxyName,
    'GEOSITE,netflix,' + proxyName,
    'GEOSITE,bilibili,DIRECT',
    'GEOSITE,bahamut,' + proxyName,
    'GEOSITE,spotify,' + proxyName,
    'GEOSITE,CN,DIRECT',
    'GEOSITE,geolocation-!cn,' + proxyName,
    
    'GEOIP,google,' + proxyName,
    'GEOIP,netflix,' + proxyName,
    'GEOIP,telegram,' + proxyName,
    'GEOIP,twitter,' + proxyName,
    'GEOIP,CN,DIRECT',
    'MATCH,规则之外'
  ];
  // 两种规则方法
  const RULE_PATTERN = {
    ruleSet: ruleSet,
    ruleGeoX: ruleGeoX
  };
  // 整合所有 rules
  const rules = [
    ...(isAdRules ? adRules : []), // 如果开启广告，插入最顶部
    ...(isAdobeBug ? ['RULE-SET,Adobe_Bug,REJECT'] : []),
    ...customRules, // 在顶部插入自定义分流规则
    ...(RULE_PATTERN[rulePattern] || []) // 未匹配时返回空数组
  ];
  // 判断 rules 为什么 GeoX 的话，就是不需要下面的规则集了
  if (rulePattern === 'ruleSet') {
    // 定义 规则集
    const RULE_PROVIDERS_URL = {
      ruleSetDomain: {
        baseUrl: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite", // 独立 domain 源
        behavior: "domain",
        keySuffix: "_domain" // 键名生成规则
      },
      ruleSetIp: {
        baseUrl: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip", // 独立 ipcidr 源
        behavior: "ipcidr",
        keySuffix: "_ip"
      }
    };
    const createRuleProviders = (name, type) => ({
      type: "http",
      interval: 86400,
      format: "text",
      behavior: RULE_PROVIDERS_URL[type].behavior,
      url: `${RULE_PROVIDERS_URL[type].baseUrl}/${name}.list`
    });
    const ruleProvidersList = [
      // ruleSetDomain 配置组
      ...[
        'private',
        'bilibili',
        'github',
        'twitter',
        'youtube', 
        'google',
        'telegram',
        'netflix',
        'bahamut',
        'spotify',
        'cn',
        { customKey: 'geolocation-!cn', name: 'geolocation-!cn' }
      ].map(item => ({
        type: "ruleSetDomain",
        ...(typeof item === "string" ? { name: item } : item)
      })),
      // ruleSetIp 配置组
      ...[
        'private',
        'google',
        'netflix',
        'telegram',
        'twitter',
        'cn'
      ].map(name => ({
        type: 'ruleSetIp',
        name
      }))
    ];
    const ruleProviders = Object.fromEntries(
      ruleProvidersList.map(({ type, name, customKey }) => [
        customKey || `${name}${RULE_PROVIDERS_URL[type].keySuffix}`,
        createRuleProviders(name, type)
      ])
    );
    params["rule-providers"] = ruleProviders;
  }
  if (isAdRules) {
    params["rule-providers"] = {
      ...params["rule-providers"], // 保留已有规则
      "秋风广告规则": {
        type: "http",
        interval: 86400,
        behavior: "domain",
        format: "yaml",
        url: "https://gcore.jsdelivr.net/gh/TG-Twilight/AWAvenue-Ads-Rule@main/Filters/AWAvenue-Ads-Rule-Clash.yaml"
      }
    };
  }
  if (isAdobeBug) {
    params["rule-providers"] = {
      ...params["rule-providers"],
      "Adobe_Bug": {
        type: "http",
        interval: 86400,
        behavior: "domain",
        format: "yaml",
        url: "https://a.dove.isdumb.one/clash.yaml"
      }
    };
  }
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
      proxies: ["地区自动", "DIRECT"],
    },
    {
      name: "地区自动",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Auto.png",
      proxies: [...countryRegions.flatMap(region => [`${region.name}自动`]) ],
    },
    {
      name: "规则之外",
      type: "select",
      proxies: ["DIRECT", proxyName],
      icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Final.png",
    },
  ];

  groups.push(...autoProxyGroups);
  params["proxy-groups"] = groups;
}
