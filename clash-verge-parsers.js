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
            name: '🟡专属地区',
            type: 'select',
            proxies: [
                '台湾01-IEPL-倍率1.0', '台湾02-IEPL-倍率1.0', '台湾03-IEPL-倍率1.0',
                '台湾04-IEPL-倍率1.0', '台湾05-IEPL-倍率1.0', '台湾06-IEPL-倍率1.0',
                '日本01-IEPL-倍率1.0', '日本02-IEPL-倍率1.0', '日本03-IEPL-倍率1.0',
                '日本04-IEPL-倍率1.0', '日本05-IEPL-倍率1.0', '日本06-IEPL-倍率1.0',
                '韩国01-IEPL-倍率1.0', '韩国02-IEPL-倍率1.0',
                '新加坡01-IEPL-倍率1.0', '新加坡02-IEPL-倍率1.0', '新加坡03-IEPL-倍率1.0',
                '新加坡04-IEPL-倍率1.0', '新加坡05-IEPL-倍率1.0', '新加坡06-IEPL-倍率1.0'
            ]
        },
        {
            name: '🫧openai',
            type: 'select',
            proxies: [
                '美国01-IEPL-倍率1.0', '美国02-IEPL-倍率1.0', '美国03-IEPL-倍率1.0',
                '美国04-IEPL-倍率1.0', '美国05-IEPL-倍率1.0', '美国06-IEPL-倍率1.0',
                'DIRECT', '🚀节点选择',
                '香港01-IEPL-倍率1.0', '香港02-IEPL-倍率1.0', '香港03-IEPL-倍率1.0',
                '香港04-IEPL-倍率1.0', '香港05-IEPL-倍率1.0', '香港06-IEPL-倍率1.0',
                '台湾01-IEPL-倍率1.0', '台湾02-IEPL-倍率1.0', '台湾03-IEPL-倍率1.0',
                '台湾04-IEPL-倍率1.0', '台湾05-IEPL-倍率1.0', '台湾06-IEPL-倍率1.0',
                '新加坡01-IEPL-倍率1.0', '新加坡02-IEPL-倍率1.0', '新加坡03-IEPL-倍率1.0',
                '新加坡04-IEPL-倍率1.0', '新加坡05-IEPL-倍率1.0', '新加坡06-IEPL-倍率1.0',
                '日本01-IEPL-倍率1.0', '日本02-IEPL-倍率1.0', '日本03-IEPL-倍率1.0',
                '日本04-IEPL-倍率1.0', '日本05-IEPL-倍率1.0', '日本06-IEPL-倍率1.0',
                '韩国01-IEPL-倍率1.0', '韩国02-IEPL-倍率1.0'
            ]
        }
    ];

    // 将新的代理组添加到现有代理组前面，确保新代理组优先级更高
    config["proxy-groups"] = newProxyGroups.concat(config["proxy-groups"] || []);

    // 添加规则
    const newRules = [
        'DOMAIN-KEYWORD,tiktokcdn-,🟡专属地区',
        'DOMAIN-SUFFIX,tiktok.com,🟡专属地区',
        'DOMAIN-SUFFIX,tiktokcdn.com,🟡专属地区',
        'DOMAIN-SUFFIX,tiktokv.com,🟡专属地区',
        'DOMAIN-SUFFIX,printables.com,🟡专属地区',
        'DOMAIN-SUFFIX,dmm.co.jp,🟡专属地区',
        'DOMAIN-SUFFIX,dmm.com,🟡专属地区',
        'PROCESS-NAME,DownloadService,🧱直接连接',
        'PROCESS-NAME,Thunder,🧱直接连接',
        'DOMAIN-SUFFIX,kbjfree.com,🟡专属地区',
        'DOMAIN-KEYWORD,openai,🫧openai',
        'DOMAIN-KEYWORD,cults3d,🫧openai',
        'DOMAIN-SUFFIX,printables.com,🟡专属地区',
        'DOMAIN-KEYWORD,instagram,🟡专属地区',
        'DOMAIN-KEYWORD,topaz-labs,🛑全球拦截',
        'DOMAIN-KEYWORD,chatgpt,🫧openai',
        'DOMAIN-SUFFIX,chatgpt.com,🫧openai',
        'DOMAIN-KEYWORD,anthropic,🫧openai',
        'DOMAIN-KEYWORD,Claude,🫧openai',
        'PROCESS-NAME,Claude,🫧openai',
        'DOMAIN-KEYWORD,macked,🚀节点选择',

    ];



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

    const processedConfig = main(initialConfig, 'ShaoShuRen_Clash');
    console.log('Final processed config:', processedConfig);
}

// exampleUsage(); // 解注释以运行示例
