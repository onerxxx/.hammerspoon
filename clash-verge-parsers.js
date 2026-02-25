function main(config, profileName) {
    // 检查配置中是否包含代理
    const proxyCount = config?.proxies?.length ?? 0;
    const proxyProviderCount = 
        typeof config?.["proxy-providers"] === "object" ? Object.keys(config["proxy-providers"]).length : 0;
    if (proxyCount === 0 && proxyProviderCount === 0) {
        throw new Error("配置文件中未找到任何代理");
    }

    // 添加代理组
    const newProxyGroups = [
        {
            name: '🌍特定地区',
            type: 'select',
            proxies: [
                '🇯🇵 日本IEPL-原生',
                '🇯🇵 日本IEPL-电信',
                '🇸🇬 新加坡IEPL',
                '🇸🇬 新加坡IEPL-电信',
                '🇰🇷 韩国',
                '🇰🇷 韩国-首尔',
                '🇺🇸 美国IEPL',
                '🇺🇸 美国IEPL-电信'
            ]
        },
        {
            name: '🐟漏网之鱼',
            type: 'select',
            proxies: [
                '🇨🇳 台湾IEPL',
                '🇨🇳 台湾IEPL-电信',
                '🇯🇵 日本IEPL-原生',
                '🇯🇵 日本IEPL-电信',
                '🇸🇬 新加坡IEPL',
                '🇸🇬 新加坡IEPL-电信',
                '🇰🇷 韩国',
                '🇰🇷 韩国-首尔',
                '🇺🇸 美国IEPL',
                '🇺🇸 美国IEPL-电信'
            ]
        }
    ];


    // 添加规则
    const newRules = [
        'DOMAIN-KEYWORD,tiktokcdn-,🌍特定地区',
        'DOMAIN-SUFFIX,tiktok.com,🌍特定地区',
        'DOMAIN-SUFFIX,tiktokcdn.com,🌍特定地区',
        'DOMAIN-SUFFIX,tiktokv.com,🌍特定地区',
        'DOMAIN-SUFFIX,printables.com,🌍特定地区',
        'DOMAIN-SUFFIX,dmm.co.jp,🌍特定地区',
        'DOMAIN-SUFFIX,dmm.com,🌍特定地区',
        'DOMAIN-SUFFIX,kbjfree.com,🌍特定地区',
        'DOMAIN-KEYWORD,openai,🌍特定地区',
        'DOMAIN-KEYWORD,cults3d,🌍特定地区',
        'PROCESS-NAME,抖音 Helper,DIRECT',
        'DOMAIN-SUFFIX,afreecatv.com,🌍特定地区',
        'DOMAIN-KEYWORD,instagram,🌍特定地区',
        'DOMAIN-KEYWORD,topaz-labs,🌍特定地区',
        'DOMAIN-KEYWORD,chatgpt,🌍特定地区',
        'DOMAIN-KEYWORD,anthropic,🌍特定地区',
        'DOMAIN-KEYWORD,Claude,🌍特定地区',
        'PROCESS-NAME,Claude,🌍特定地区',
        'DOMAIN-KEYWORD,jav,🐟漏网之鱼',
        'DOMAIN-KEYWORD,dmm,🌍特定地区',
        'DOMAIN-KEYWORD,tiktok.com,🌍特定地区',
        'DOMAIN-KEYWORD,google,🌍特定地区',
        'DOMAIN-KEYWORD,chatgpt,🌍特定地区'
    ];

    // 将新的代理组添加到现有配置中
    config['proxy-groups'] = (config['proxy-groups'] || []).concat(newProxyGroups);

    // 将新的规则添加到现有规则前面，确保新规则优先级更高
    config.rules = newRules.concat(config.rules || []);

    // 打印处理后的配置文件名和配置，便于调试
    console.log('Processing profile:', profileName);
    console.log('Processed config:', config);

    return config;
}

// 新增：提供一个示例调用方式，实际使用时根据具体情况调用
function exampleUsage() {
    // 假设这是从某个订阅链接获取的初始配置
    const initialConfig = {
        // ... 初始配置内容 ...
    };


}

