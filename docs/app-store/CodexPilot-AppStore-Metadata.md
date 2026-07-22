# CodexPilot / Codex 驾驶舱 App Store 上架资料

> Version: 1.0 submission draft
> Primary audience: Mac users who actively use Codex and need a local quota, disk I/O, and cache cockpit.
> Positioning: independent local macOS utility for Codex users. Not affiliated with OpenAI.

## App Store Connect 基本信息 / Basic Information

### English Localization

App Name:
CodexPilot

Subtitle:
Codex quota cockpit

Promotional Text:
Track Codex quota, disk activity, cache growth, and Mac health from a native menu bar cockpit.

Description:
CodexPilot is a native macOS cockpit designed specifically for Mac users who work with Codex.

When Codex is running for long sessions, it can consume quota, read and write local files frequently, and leave behind large runtime caches. CodexPilot keeps these signals visible in one focused place, so you can understand what is happening on your Mac without digging through logs, system panels, or Terminal commands.

CodexPilot helps you:
- Track Codex remaining quota from local Codex session events when available
- Watch quota changes from the dashboard, menu bar, and supported Touch Bar Macs
- Monitor live disk read/write rates while Codex and other developer tools are active
- See disk I/O totals and disk growth since the app was opened
- Estimate cache generated during local development and Codex runs
- Clean common user cache locations from a dedicated cache module
- Monitor CPU, memory, disk usage, and battery status in a native macOS interface
- Switch between a calm Normal dashboard and a faster Sport cockpit with one-second refresh

CodexPilot is built for local-first use. It reads system metrics, disk counters, cache locations, and local Codex session logs on your Mac. It does not require a cloud account and does not upload your Codex logs or Mac monitoring data.

Important notes:
Codex quota information depends on quota-related events written by your local Codex installation. If Codex does not expose a quota event in local logs, CodexPilot will show quota as not reported. CodexPilot is an independent utility and is not affiliated with OpenAI.

Keywords:
Codex,quota,Mac,developer,monitor,disk,cache,menu bar,Touch Bar

Category:
Developer Tools

Secondary Category:
Utilities

Support URL:
TODO: Add support page URL

Marketing URL:
TODO: Add product page URL

Privacy Policy URL:
TODO: Add hosted privacy policy URL

Copyright:
© 2026 TODO: Developer or Company Name

### 简体中文本地化 / Simplified Chinese Localization

App 名称:
Codex 驾驶舱

副标题:
Codex 额度状态中枢

宣传文本:
为 Mac 上的 Codex 用户设计，随时跟踪剩余额度、硬盘读写、缓存增长与系统状态。

描述:
Codex 驾驶舱是专门为在 Mac 上使用 Codex 的用户设计的原生状态中枢。

长时间运行 Codex 时，你通常会同时关心几件事：Codex 剩余额度还够不够、本地硬盘是否被频繁读写、运行过程中产生了多少缓存垃圾，以及 Mac 的 CPU、内存、硬盘和电池是否稳定。Codex 驾驶舱把这些信号集中到一个清晰的原生界面里，让你不用反复打开系统监视器、翻日志或执行命令。

Codex 驾驶舱可以帮助你：
- 在本地 Codex session 事件可用时，跟踪 Codex 剩余额度变化
- 在主界面、菜单栏和支持的 Touch Bar 上随时查看 Codex 状态
- 监控 Codex 与开发工具运行时的硬盘实时读取/写入速率
- 统计从打开软件开始的硬盘读写总量和硬盘空间变化
- 估算本地开发和 Codex 运行过程中产生的缓存
- 通过独立缓存模块清理常见用户缓存目录中的缓存垃圾
- 同时查看 CPU、内存、硬盘使用率和电池状态
- 在浅色 Normal 模式和 1 秒刷新一次的 Sport 码表模式之间切换

Codex 驾驶舱优先本地运行。它读取你的 Mac 系统指标、硬盘计数器、缓存目录和本地 Codex session 日志，不需要云端账号，也不会上传你的 Codex 日志或 Mac 监控数据。

重要说明：
Codex 额度信息取决于本机 Codex 是否在本地日志中写入额度事件。如果当前 Codex 版本没有暴露对应日志，应用会显示额度未报告。Codex 驾驶舱是一款独立工具，与 OpenAI 无隶属关系。

关键词:
Codex,额度,Mac,开发者,监控,硬盘,缓存,菜单栏,Touch Bar

类别:
开发者工具

第二类别:
工具

支持 URL:
TODO: 添加支持页面 URL

营销 URL:
TODO: 添加产品页面 URL

隐私政策 URL:
TODO: 添加隐私政策 URL

版权:
© 2026 TODO: 开发者或公司名称

## Screenshot Plan / 截图规划

Use 5 screenshots if possible.

1. Main Normal dashboard
   - EN caption: Codex quota and Mac health in one cockpit
   - CN caption: Codex 额度与 Mac 状态中枢
   - Show: light Normal dashboard, six top modules, system health, disk/cache, Codex quota column.

2. Sport cockpit
   - EN caption: One-second Sport mode gauges
   - CN caption: 1 秒刷新 Sport 码表模式
   - Show: Sport mode top gauge modules for CPU, memory, disk, disk I/O, battery, and quota.

3. Disk I/O monitoring
   - EN caption: See Codex-related disk activity
   - CN caption: 监控 Codex 运行时硬盘读写
   - Show: disk read/write module, live read/write rates, since-launch read/write totals.

4. Cache module
   - EN caption: Clean cache created during local runs
   - CN caption: 清理本地运行产生的缓存垃圾
   - Show: cache estimate, cache directory list, clean cache button.

5. Menu bar and Touch Bar
   - EN caption: Key signals stay visible
   - CN caption: 菜单栏与 Touch Bar 随时可见
   - Show: colored menu bar progress, cockpit popover, and Touch Bar strip if available.

## Review Notes / 审核备注

English:
CodexPilot is a local macOS utility for users who run Codex on Mac. It displays Mac system status, disk usage, disk read/write activity, cache estimates, and Codex quota-related information parsed from local Codex session logs when those events are present. The app does not require sign-in, does not upload user data, and does not provide or resell Codex service access. Cache cleaning is performed locally on user-accessible cache directories. CodexPilot is an independent utility and is not affiliated with OpenAI.

Simplified Chinese:
Codex 驾驶舱是一款面向 Mac 上 Codex 用户的本地 macOS 工具。它显示 Mac 系统状态、硬盘使用率、硬盘读写活动、缓存估算，并在本地 Codex session 日志存在额度事件时解析并显示 Codex 额度相关信息。应用不要求登录，不上传用户数据，也不提供或转售 Codex 服务访问权限。缓存清理仅在用户本机可访问的缓存目录中本地执行。本应用是独立工具，与 OpenAI 无隶属关系。

## Privacy Label Draft / 隐私标签草案

Recommended answer if the app remains local-only and has no analytics, advertising, account system, network upload, or third-party SDK data collection:

- Data Collection: Data Not Collected
- Tracking: No
- Third-party advertising: No
- Analytics SDK: No

Developer verification checklist:
- Confirm the app does not send Codex logs, system metrics, disk I/O metrics, cache paths, or usage information to any server.
- Confirm no analytics/crash-reporting SDK is added before submission.
- Confirm the privacy policy is hosted and linked in App Store Connect.
- Confirm any future network feature updates this privacy label.

## Age Rating / 年龄分级建议

Likely 4+, assuming:
- No user-generated public content
- No web browsing
- No gambling, medical, financial advice, or mature content
- No account or social features

## Pricing / 定价建议

Suggested options:

1. Free, no in-app purchases
   - Best for first release and easiest review path.

2. Paid upfront
   - Suitable if the app is already polished, has complete screenshots, support docs, and clear ongoing maintenance.

3. Freemium
   - Not recommended for first release unless subscription/IAP logic is fully designed.

## App Store Connect 填写检查 / Submission Checklist

- App name under 30 characters.
- Subtitle under 30 characters.
- Promotional text under 170 characters.
- Description under 4000 characters.
- Keywords under 100 bytes per localization.
- Privacy Policy URL hosted and publicly accessible.
- Support URL hosted and publicly accessible.
- Primary category: Developer Tools.
- App Sandbox enabled in entitlements.
- Privacy answers match actual behavior.
- Review notes explain local Codex log parsing and independent/non-affiliated status.

## Sources / 参考

- Apple App Store Connect app information reference: app name and subtitle requirements, privacy policy URL requirement.
- Apple App Store Connect platform version reference: promotional text, description, keywords, screenshots, support URL.
- Apple App privacy reference: privacy policy URL and data handling disclosure expectations.
