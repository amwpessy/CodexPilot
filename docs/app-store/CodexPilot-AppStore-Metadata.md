# Lynncat Pilot / 林猫驾驶舱 App Store 上架资料

> Version: 1.4 (7)
> Primary audience: developers who need local coding-quota, disk I/O, and system monitoring.
> Public brand: Lynncat Pilot. Bundle ID remains `com.lynncat.codexpilot`.

## Review Remediation / 审核整改

1. Guideline 4.1(c)
   - Changed the public app name from `CodexPilot` to the developer-owned brand `Lynncat Pilot`.
   - Changed the Simplified Chinese name to `林猫驾驶舱`.
   - Removed `Codex` from the app name and subtitle.
   - Kept the existing Bundle ID, as requested by App Review.

2. Guideline 5.2.5
   - Removed `Mac` from both localized subtitles.
   - Replaced product references in subtitles and keywords with functional descriptions.

3. Guideline 5 / China mainland availability
   - China mainland was deselected in App Store Connect under Pricing and Availability on July 24, 2026.
   - App Store Connect reports the storefront transition as `Processing` to `Not Available`.
   - Confirm in Review Notes that this version is not distributed in China mainland.

4. Simulated gambling / individual developer eligibility
   - Removed the Texas Hold'em points table and all Poker source files from the App Store `Release` configuration.
   - The Mac App Store binary has no betting, wagering, casino, Poker, or other simulated-gambling content.
   - The separately distributed and notarized Direct edition retains the entertainment-only points table and is not the binary submitted to App Store Connect.
   - Update the App Store Connect age-rating questionnaire to `Simulated Gambling: None`.

## App Store Connect Basic Information / 基本信息

### English Localization

App Name:
Lynncat Pilot

Subtitle:
Developer usage cockpit

Promotional Text:
Track coding quota signals, disk activity, and system health from a focused native desktop cockpit.

Description:
Lynncat Pilot is a native developer cockpit for monitoring coding-assistant usage signals and computer health in one focused place.

During long development sessions, local tools can consume usage quota and read and write files frequently. Lynncat Pilot keeps these signals visible without requiring you to search through logs, system panels, or Terminal commands.

Lynncat Pilot helps you:
- Track remaining quota from supported local coding-session events when available
- Watch quota changes from the dashboard, menu bar, and supported Touch Bar devices
- Monitor live disk read and write rates while development tools are active
- See disk I/O totals, disk growth, and precise session duration since launch
- Monitor CPU, memory, disk usage, and battery status
- Switch between a calm Normal dashboard and a Sport cockpit with one-second refresh
- Optionally sign in with Apple to join the user community, earn participation points, and appear on the leaderboard
- Collect all 108 Water Margin heroes through an equal-odds card collection using participation points

Monitoring is local-first. System metrics, disk counters, and readable local session logs remain on your computer. An account is optional and is used only for community, points, leaderboard, and card collection features; monitoring does not require sign-in.

Quota information depends on events written by a supported local coding assistant. When a compatible quota event is unavailable, the app clearly reports that no quota information was found.

Keywords:
developer,quota,monitor,disk,system,menu bar,Touch Bar,usage

Category:
Developer Tools

Secondary Category:
Utilities

Support URL:
https://lynncat.com/codexpilot/support.html

Marketing URL:
https://lynncat.com/codexpilot/

Privacy Policy URL:
https://lynncat.com/codexpilot/privacy.html

Copyright:
© 2026 Lynncat

### 简体中文本地化 / Simplified Chinese Localization

App 名称:
林猫驾驶舱

副标题:
开发额度与系统状态中枢

宣传文本:
在原生桌面驾驶舱中跟踪开发额度信号、硬盘读写与系统健康状态。

描述:
林猫驾驶舱是一款原生开发状态中枢，用于集中监控编码助手的额度信号与电脑健康状态。

长时间开发时，本地工具可能持续消耗使用额度并频繁读写文件。林猫驾驶舱把这些信号集中在清晰的原生界面里，无需反复翻查日志、系统面板或终端命令。

林猫驾驶舱可以帮助你：
- 在受支持的本地编码会话事件可用时跟踪剩余额度
- 在主界面、菜单栏和支持的 Touch Bar 设备上查看额度变化
- 监控开发工具运行时的硬盘实时读取与写入速率
- 统计从打开软件开始的硬盘读写总量、空间变化与精确运行时长
- 同时查看 CPU、内存、硬盘使用率和电池状态
- 在浅色 Normal 模式和每秒刷新的 Sport 码表模式之间切换
- 可选择使用 Apple 登录，加入用户交流、累计参与积分并查看排行榜
- 使用参与积分收集等概率出现的水浒一百单八将卡牌

监控功能以本地优先方式运行。系统指标、硬盘计数器和可读取的本地会话日志保留在本机。账户为可选功能，只用于用户交流、积分、排行榜和卡册；监控功能无需登录。

额度信息取决于受支持的本地编码助手是否写入相关事件。如果当前没有兼容的额度事件，应用会明确显示未找到额度信息。

关键词:
开发者,额度,监控,硬盘,系统,菜单栏,Touch Bar,用量

类别:
开发者工具

第二类别:
工具

支持 URL:
https://lynncat.com/codexpilot/support.html

营销 URL:
https://lynncat.com/codexpilot/

隐私政策 URL:
https://lynncat.com/codexpilot/privacy.html

版权:
© 2026 Lynncat

## Screenshot Plan / 截图规划

Use three updated screenshots. Every screenshot must show the new public name and the
Poker-free App Store navigation.

1. Main Normal dashboard
   - EN caption: Quota and system health in one cockpit
   - CN caption: 额度与系统状态集中呈现
   - Show: light Normal dashboard, six top modules, system health, disk activity, and quota column.

2. User community
   - EN caption: Optional community and participation points
   - CN caption: 可选用户交流与参与积分
   - Show: Sign in with Apple, public leaderboard, and moderated discussion.

3. Water Margin collection
   - EN caption: Collect 108 equal-odds heroes
   - CN caption: 收集等概率出现的一百单八将
   - Show: collection progress, disclosed 1/108 odds, card details, and draw controls.

## Review Notes / 审核备注

English:

Thank you for the review. We made the following changes:

1. We removed the Texas Hold'em points table and all Poker source files from the App Store Release configuration. This submitted binary contains no betting, wagering, casino, Poker, or simulated-gambling content.
2. We updated the age-rating questionnaire to accurately report `Simulated Gambling: None`.
3. The remaining Water Margin card collection uses non-purchasable, non-redeemable participation points. All 108 cards have equal odds of 1/108, disclosed before every draw.
4. The public app name is Lynncat Pilot, and the Simplified Chinese name is 林猫驾驶舱. The existing Bundle ID remains unchanged.
5. China mainland remains unavailable in Pricing and Availability.

Lynncat Pilot displays local system status, disk usage, disk read/write activity, and quota-related information parsed from readable local coding-session logs when compatible events are present. Monitoring does not require sign-in, and local logs or monitoring data are not uploaded.

Sign in with Apple is optional and enables the user community, participation points, leaderboard, and Water Margin card collection. Participation points have no cash value, cannot be purchased, and cannot be redeemed.

The app does not provide or resell access to OpenAI, ChatGPT, or Codex services and is not affiliated with OpenAI.

简体中文:

感谢审核。我们已完成以下修改：

1. 我们已从 App Store 的 Release 构建中删除德州扑克牌桌及全部 Poker 源文件。本次提交的二进制不包含下注、投注、赌场、扑克牌桌或任何模拟赌博内容。
2. 我们已将年龄分级问卷中的“模拟赌博”准确修改为“无”。
3. 保留的水浒卡册只使用不可购买、不可兑换的参与积分；108 张卡牌出现概率均为 1/108，并在每次抽卡前明确显示。
4. 应用公开名称为 Lynncat Pilot，简体中文名称为“林猫驾驶舱”，原 Bundle ID 保持不变。
5. 中国大陆仍未列入销售范围。

林猫驾驶舱显示本地系统状态、硬盘使用率和硬盘读写活动，并在可读取的本地编码会话日志存在兼容事件时解析额度相关信息。监控功能无需登录，本地日志和监控数据不会上传。

Apple 登录为可选功能，用于用户交流、参与积分、排行榜和水浒卡册。参与积分没有现金价值，不能购买或兑现。

本应用不提供或转售 OpenAI、ChatGPT 或 Codex 服务访问权限，与 OpenAI 无隶属关系。

## Privacy Labels / 隐私标签

Update App Store Connect for the current optional account, community, points, and card-collection implementation:

- Data Collection: Data Collected
- Tracking: No
- Third-party advertising: No
- Analytics SDK: No
- Email or Messages: linked to the user; used for app functionality
- Game Content: linked to the user; used for app functionality
- Other User Content: linked to the user; used for app functionality
- User ID: linked to the user; used for app functionality and account authentication
- Device ID: linked to the user; used for app functionality, session security, and point-award deduplication
- Product Interaction: linked to the user; account heartbeat, points balance, leaderboard preference, and card-draw records used for app functionality
- Other Usage Data: linked to the user; used for app functionality

Developer verification checklist:
- Confirm the app does not send local coding-session logs, system metrics, disk I/O metrics, or usage information to any server.
- Confirm no analytics or crash-reporting SDK is added before submission.
- Confirm the privacy policy is hosted and linked in App Store Connect.
- Confirm any future network feature updates this privacy label.

## Age Rating / 年龄分级

Required answers for the Poker-free App Store build:

- User-generated content and social media: Yes, because Lynncat Pilot includes public community messages with reporting and blocking controls
- Simulated gambling: None
- Contests: Occasional, because the optional points leaderboard ranks participating users
- Real-money gambling and purchasable wagering currency: No
- Loot boxes: No; the app has no in-app purchases, points cannot be purchased, and every draw awards one card
- Unrestricted web access, medical advice, mature content, violence, and advertising: No
- Save the questionnaire and use the rating calculated by App Store Connect

## Pricing / 定价建议

Recommended for the first release:

- Free, no in-app purchases.
- China mainland unavailable.

## App Store Connect Submission Checklist / 填写检查

- Change app name to `Lynncat Pilot`.
- Change Simplified Chinese app name to `林猫驾驶舱`.
- Replace both subtitles with the text above.
- Replace promotional text, description, keywords, and screenshot captions in both localizations.
- Confirm China mainland remains unavailable after the 24-hour storefront update finishes.
- Upload screenshots showing the new public name.
- Upload a build whose product name and display name are `Lynncat Pilot`.
- Paste the revised Review Notes into the new version before resubmission.
- Keep Bundle ID `com.lynncat.codexpilot` unchanged.
- Confirm App Sandbox remains enabled.
- Confirm privacy answers match actual behavior.
- Confirm `Simulated Gambling` is set to `None` before resubmission.
- Confirm `Loot Boxes` remains `No`; the app sells neither points nor randomized items.
- Paste the revised bilingual Review Notes above into the version submitted for review.
