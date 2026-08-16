# 掌上徐工 UI 设计规范

> **文档状态**：项目规范（Normative）
> **版本**：1.3.0
> **更新日期**：2026-08-16
> **适用范围**：`lib/` 下全部 Flutter 页面、组件、主题和交互
> **实现基线**：Flutter + Forui `0.25.0` + Lucide icons
> **阅读对象**：开发者、设计师、自动化编码 AI

这不是灵感收集，而是后续实现 UI 时的约束文件。实现与本文件冲突时，优先级如下：

1. 平台安全区、可访问性和系统行为。
2. 本文件的 MUST 规则和设计令牌。
3. Forui 现有组件的 API 和项目公共组件。
4. 单个页面的局部视觉偏好。

## 0. AI 快速契约

下面的值是实现前必须读取的最小上下文。完整规则见后文。

```yaml
product: 掌上徐工
platform: Flutter mobile-first
component_system: Forui 0.25.0
icon_system: Forui FLucideIcons / FIcons.lucide
base_spacing_dp: 4
compact_breakpoint_dp: 600
medium_breakpoint_dp: 840
compact_page_gutter_dp: 16
medium_page_gutter_dp: 24
expanded_page_gutter_dp: 32
content_max_width_dp: 960
form_max_width_dp: 560
default_card_radius_dp: 8
default_control_height_dp: 48
minimum_touch_target_dp: 44
preferred_touch_target_dp: 48
default_body: 16/24
default_secondary: 14/20
letter_spacing: 0
allow_system_text_scaling: true
```

### MUST / MUST NOT

- **MUST** 使用 Forui 组件和项目公共封装（`AppPage`、`AppCard`、`AppTextField`、`AppIconButton` 等）。
- **MUST** 使用 `context.theme.colors`、`context.theme.typography` 或项目语义令牌，不得在页面内散落品牌色和状态色。
- **MUST** 按本文的响应式边距实现：手机窄屏不是固定 24dp，而是 16dp。
- **MUST** 给加载、空数据、错误、离线、禁用和缓存状态保留稳定的布局尺寸。
- **MUST** 让所有可操作目标至少 44dp，优先 48dp；图标视觉尺寸和点击热区分开处理。
- **MUST** 允许系统文字放大，并在 1.0、1.3、2.0 倍文字下检查溢出和遮挡。
- **MUST** 为只有图标的操作提供语义标签和 tooltip。
- **MUST NOT** 引入新的 Material UI 组件来替代 Forui；`MaterialApp` 和 Forui 的适配层是例外。
- **MUST NOT** 在页面中使用 `Colors.*`、任意 `Color(0x...)`、渐变背景或装饰性光晕；颜色必须来自主题令牌。
- **MUST NOT** 在卡片里再嵌套卡片；页面分区优先使用全宽布局、`FTileGroup` 或分隔线。
- **MUST NOT** 把普通正文写成大标题，也不得用负字距或根据视口宽度缩放字号。
- **MUST NOT** 为了“看起来有设计感”增加无功能的插图、圆球、bokeh、阴影层或动画。

## 1. 产品定位

掌上徐工是校园信息工具，不是营销首页。用户会反复执行查询、查看课表、设置偏好和提交业务，因此界面应当：

- **安静**：中性背景、少量品牌色、低装饰密度。
- **高可扫读性**：标题、数值、状态和操作在一眼内分层。
- **适度紧凑**：减少无意义的左右空白，但不牺牲 48dp 触控和文字可读性。
- **可恢复**：网络失败、缓存、校园网限制和空数据都要有明确状态。
- **可预测**：相同任务使用相同控件、边距、图标和反馈方式。

视觉重心是“信息和动作”，而不是卡片数量。卡片只用于承载独立的可操作项目或一组重复数据；页面本身不应由层层悬浮卡片组成。

## 2. 调研依据

以下资料均为官方设计系统或标准页面，检索日期为 2026-08-16。它们用于提炼共同原则，不意味着把多个组件库混用到项目中。

| 来源 | 官方要点 | 本项目采用方式 |
| --- | --- | --- |
| [Material 3 Grids & spacing](https://m3.material.io/foundations/layout/grids-spacing/spacing) | 网格、边距和间距组织内容层级；采用一致的 spacing 节奏。 | 固定 4dp 基础网格，页面边距按窗口尺寸响应。 |
| [Material 3 Color roles](https://m3.material.io/styles/color/overview) | 使用 primary、surface、on-color 等语义角色，而不是页面散落色值。 | 对接 `FColors`，状态色使用项目扩展令牌。 |
| [Android window size classes](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes) | 以 compact、medium、expanded 窗口类别决定布局，而非为某个设备写死尺寸。 | 采用 600dp、840dp 两个项目断点。 |
| [Android touch target size](https://support.google.com/accessibility/android/answer/7101858?hl=en) | Android 建议交互目标至少 48dp，并为较小视觉元素保留足够触控空间。 | 视觉图标可为 20–22dp，但首选 48dp 热区。 |
| [Apple HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | 内容应适应不同屏幕、方向、安全区和上下文。 | SafeArea、最大内容宽度、键盘和横竖屏都纳入验收。 |
| [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | 关注可读性、可操作性、动态文字和非颜色信息。 | 保留系统文字缩放，状态同时显示文字/图标。 |
| [Apple HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | 排版需要同时保证可读性、信息层级和平台适配。 | 使用有限的语义字号，支持系统文字缩放，不按视口缩放字号。 |
| [Fluent 2 Layout](https://fluent2.microsoft.design/layout) | 全局 spacing ramp 以 4px 为基准；临近元素表示关联，更多空白表示分组。 | 4dp 令牌和“组内小间距、组间大间距”。 |
| [IBM Carbon Spacing](https://carbondesignsystem.com/elements/spacing/overview/) | 使用可复用 spacing token，避免每个组件自行发明距离。 | 所有新页面只能从间距令牌选值。 |
| [Atlassian Spacing](https://atlassian.design/foundations/spacing/) | 用 2、4、6、8、12、16、20、24、32、40、48 等 token 表达关系。 | 保留 2dp 仅作微调，其余使用本项目 4dp 阶梯。 |
| [Ant Design Layout](https://ant.design/docs/spec/layout/) / [Theme tokens](https://ant.design/docs/react/customize-theme/) | `sizeUnit`、`sizeStep`、padding、margin 和语义 token 统一管理。 | 以 4dp 为 size unit，建立 Flutter 版令牌表。 |
| [WCAG 2.2](https://www.w3.org/TR/WCAG22/) | 普通文字对比度至少 4.5:1，大文字 3:1，非文本 UI 边界 3:1，目标尺寸至少 24 CSS px。 | 移动端使用更严格的 44/48dp 触控目标和可验证对比度。 |
| [Forui Themes](https://forui.dev/docs/concepts/themes) / [Forui docs](https://forui.dev/docs) | 通过 `FThemeData`、`FColors`、`FStyle` 和组件控制外观。 | Forui 是唯一组件来源，主题令牌集中在 `lib/ui/app_theme.dart`。 |

## 3. 设计令牌

### 3.1 间距令牌

所有数值单位为 Flutter 的 logical pixel（在 Android 上通常按 dp 理解）。默认基准是 4。

| 令牌 | 值 | 使用场景 |
| --- | ---: | --- |
| `space-0` | 0 | 无间距、边到边内容 |
| `space-0.5` | 2 | 仅用于图标与文字的光学微调、分隔线偏移 |
| `space-1` | 4 | 标签与辅助文字、紧邻行 |
| `space-2` | 8 | 图标与标题、同组控件、紧凑卡片间距 |
| `space-3` | 12 | 卡片之间、字段之间、弹层内边距 |
| `space-4` | 16 | 页面手机边距、标准卡片横向内边距 |
| `space-5` | 20 | 组与组之间、主要区域上下留白 |
| `space-6` | 24 | 中等屏幕边距、表单段落、主要操作前间距 |
| `space-8` | 32 | 大区块之间、宽屏内容呼吸空间 |
| `space-10` | 40 | 仅用于宽屏布局或空状态，不用于普通列表 |
| `space-12` | 48 | 页面级分隔或大尺寸空状态 |
| `space-16` | 64 | 极少使用，必须有明确层级理由 |

禁止使用 5、7、9、10、14、18、22 等任意值来“试到看起来合适”。如果 Forui 组件内部产生这些值，不要覆盖组件内部实现；项目自有布局仍应使用令牌。

### 3.2 页面边距和断点

| 窗口宽度 | 类别 | 页面左右边距 | 内容最大宽度 | 典型布局 |
| ---: | --- | ---: | ---: | --- |
| `< 600` | compact | **16** | 视口宽度减边距 | 单列为主，Tool 顶部摘要固定两列 |
| `600–839` | medium | **24** | 720 | 两列表单/摘要、较宽列表 |
| `>= 840` | expanded | **32** | 960 | 居中内容、多列或侧栏 |

规则：

- 边距是内容容器的边距，不包括系统状态栏、导航栏和 SafeArea。
- `Tool` 和已登录 `Profile` 页面在常见 360/390/412 宽度必须使用 16dp；不得把 24dp 当作手机默认值。
- 课表网格是唯一允许真正 edge-to-edge 的主要页面；网格外的标题、筛选和操作仍遵循容器边距。
- 表单内容最大宽度 560，结果详情最大宽度 720；宽屏上不要拉伸成整屏长行。
- 普通两列布局必须保证每列至少 148dp，不满足时改为单列。Tool 首页的一卡通与电费摘要是明确例外，始终并排，内部文字通过换行或省略保持布局稳定。
- 内容底部默认留 `space-5`，再叠加系统安全区；不要为了填满屏幕增加空白卡片。

### 3.3 尺寸、触控和形状

| 对象 | 规范尺寸 |
| --- | --- |
| 顶部栏 | 高度约 56，标题视觉居中；操作热区 44–48 |
| 底部导航 | 内容高度约 64，额外保留底部安全区 |
| 普通列表行 | 最小高度 52，含开关/选择器时优先 56 |
| 主要按钮 | 最小高度 48；左右内边距 16–20 |
| 文本输入框 | 独立输入框最小可操作高度 48；设置行内编辑器可视觉压缩，但父级行热区不得低于 48 |
| 图标 | 工具栏视觉 20–22，空状态 40–48；热区独立为 44–48 |
| 卡片 | 默认圆角 **8**，描边 1；不使用夸张胶囊形 |
| 输入框/按钮 | 圆角 8；只有标签、状态徽标和明确的 pill 控件可用全圆角 |
| 底部弹层 | 顶部圆角 16，内边距横向 12–16 |
| 对话框 | 圆角 12–16，内边距 20–24 |
| 焦点环 | 2dp，必须与相邻背景有清晰对比 |

`44dp` 是可操作目标下限，`48dp` 是本项目首选；WCAG 的 24px 只是最低网页标准，不能当作移动端按钮设计目标。视觉图标可以只有 20dp，但点击区域不能跟着缩小。

### 3.4 阴影、描边和层级

- 默认卡片优先使用 `card` 背景 + 1dp `border`，不同时使用厚描边和强阴影。
- 阴影仅用于确实浮起的弹层、菜单和对话框；普通页面卡片使用无阴影或 Forui 的极弱默认阴影。
- 不使用大面积阴影、发光边框或渐变来制造层级。
- 同一层级的卡片必须有相同圆角、内边距、边框和交互反馈。
- 禁止“卡片套卡片”。需要分组时使用 `FTileGroup`、`FDivider` 或增加组间距。

## 4. 色彩系统

### 4.1 色彩原则

本项目是校园工具，不使用高饱和蓝色填满整个界面。主色只用于主要动作、当前选中、链接、焦点和关键图标；状态色只表示状态，不作为装饰。

- 背景使用中性偏冷白/深色，不使用米色、棕色或大面积紫色渐变。
- 主色为青蓝，绿色承担成功/可用，琥珀承担警告，红色承担错误/破坏性操作，蓝色承担信息提示。
- 任何状态必须同时有文字、图标或结构变化，不能只靠颜色区分。
- 不在页面代码中写颜色字面量；统一在 `AppTheme` 和语义色扩展中维护。

### 4.2 建议语义色令牌

这些值是本项目的建议基线，亮/暗主题都必须成对定义。`background`、`foreground`、`primary`、`secondary`、`muted`、`destructive`、`error`、`card`、`border` 及其 foreground 对接 Forui `FColors`；`controlBorder` 和状态色通过 `ThemeExtension` 或项目 `AppSemanticColors` 实现。

#### Light

| 令牌 | 色值 | 用途 |
| --- | --- | --- |
| `background` | `#F7F9FA` | 页面底色 |
| `foreground` | `#182126` | 主文字、图标 |
| `card` | `#FFFFFF` | 卡片、列表组 |
| `primary` | `#087EA4` | 主要按钮、选中、焦点 |
| `primaryForeground` | `#FFFFFF` | 主色上的文字/图标 |
| `secondary` | `#E8F1EE` | 次级动作背景、低强调选中 |
| `secondaryForeground` | `#183B32` | 次级背景上的文字 |
| `muted` | `#EEF2F3` | 禁用区、辅助背景、输入填充 |
| `mutedForeground` | `#58686F` | 次要文字、辅助说明 |
| `border` | `#D7E0E3` | 分隔线、卡片边界 |
| `controlBorder` | `#7A8B92` | 输入框等需要可见边界的控件 |
| `destructive/error` | `#B42318` | 错误、删除、退出登录 |
| `destructiveForeground/errorForeground` | `#FFFFFF` | 错误色上的文字 |
| `success` | `#147A55` | 成功、在线、可用 |
| `successContainer` | `#E5F5EE` | 成功提示背景 |
| `onSuccessContainer` | `#0E4A34` | 成功提示文字 |
| `warning` | `#8A5B00` | 即将过期、注意 |
| `warningContainer` | `#FFF3D6` | 警告背景 |
| `onWarningContainer` | `#4B3100` | 警告文字 |
| `info` | `#285FA8` | 网络、缓存、说明 |
| `infoContainer` | `#E7EFFA` | 信息背景 |
| `onInfoContainer` | `#153B6B` | 信息文字 |

#### Dark

| 令牌 | 色值 | 用途 |
| --- | --- | --- |
| `background` | `#0E1417` | 页面底色 |
| `foreground` | `#E8EEF0` | 主文字、图标 |
| `card` | `#151D21` | 卡片、列表组 |
| `primary` | `#65C9EA` | 主要按钮、选中、焦点 |
| `primaryForeground` | `#06252F` | 主色上的文字/图标 |
| `secondary` | `#1C302A` | 次级动作背景 |
| `secondaryForeground` | `#DDF2E9` | 次级背景上的文字 |
| `muted` | `#1D292D` | 禁用区、辅助背景 |
| `mutedForeground` | `#A5B6BC` | 次要文字、辅助说明 |
| `border` | `#304047` | 分隔线、卡片边界 |
| `controlBorder` | `#71868F` | 输入框等控件边界 |
| `destructive/error` | `#FF8A80` | 错误、删除、退出登录 |
| `destructiveForeground/errorForeground` | `#2B0806` | 错误色上的文字 |
| `success` | `#6DD6A7` | 成功、在线、可用 |
| `successContainer` | `#143A2B` | 成功提示背景 |
| `onSuccessContainer` | `#B9F0D2` | 成功提示文字 |
| `warning` | `#F4C060` | 即将过期、注意 |
| `warningContainer` | `#3A2B0D` | 警告背景 |
| `onWarningContainer` | `#FFE3A3` | 警告文字 |
| `info` | `#8FC2FF` | 网络、缓存、说明 |
| `infoContainer` | `#15324F` | 信息背景 |
| `onInfoContainer` | `#C6E1FF` | 信息文字 |

### 4.3 对比度验收

- 普通正文和背景至少 4.5:1；大字号至少 3:1。
- 需要识别的控件边界、焦点环和图形至少 3:1。
- 推荐基线中的 `foreground`、`mutedForeground`、`primary`、`destructive` 均已按 sRGB 对比度计算；修改色值后必须重新计算。
- 半透明文字不能作为唯一信息。`withAlpha` 只适用于装饰性背景叠加，不适用于正文、错误、时间和按钮标签。
- 暗色主题不是把亮色主题反相；要维持层级，卡片应略亮于背景，边界应可辨而不刺眼。

## 5. 字体与文字

### 5.1 项目文字层级

字号不可随视口宽度变化，字距固定为 0。以下是项目自有语义层级；可以用 Forui typography 作为基准，再用 `copyWith` 固定行高。

| 角色 | 字号/行高 | 权重 | 使用场景 |
| --- | --- | ---: | --- |
| `pageTitle` | 20/28 | 600 | 页面标题、关键结果标题 |
| `sectionTitle` | 14/20 | 600 | `Profile` 分组标签、区块标题 |
| `tileTitle` | 16/24 | 500 | 设置项、工具项主标题 |
| `body` | 16/24 | 400 | 普通正文、表单输入 |
| `bodySmall` | 14/20 | 400 | 辅助说明、时间、缓存标记 |
| `label` | 14/20 | 500 | 字段标签、按钮文字 |
| `caption` | 12/16 | 400 | 版本、法律信息、非关键元数据 |
| `metric` | 22/28 | 600 | 电量、余额、考试倒计时等关键数值 |
| `timetable` | 11–14/16–20 | 400/500 | 课表网格，必须保证可读和不重叠 |

规则：

- 普通工具卡片不要使用 20dp 以上正文；当前代码里 `body.lg` 用作普通卡片标题的地方应逐步改为 `tileTitle`。
- 不使用全大写、负字距、过度粗体或连续三层以上标题。
- 中文优先使用系统无衬线字体和平台 fallback；不要为一页引入新的字体包。
- 文字必须允许换行；只有日志、代码、学号等明确的等宽数据才使用横向滚动。
- 任何截断都要有明确理由，并使用 `TextOverflow.ellipsis`；不能让按钮文字被裁切。
- `MediaQuery` 不应把文字缩放硬限制在 1.0。至少测试系统 1.3 和 2.0 倍文字。

## 6. Forui 组件契约

### 6.1 组件选择

| 需求 | 必选组件/封装 | 规则 |
| --- | --- | --- |
| 页面容器 | `AppPage` + `FScaffold` | 统一 header、SafeArea、键盘和页面背景 |
| 页面标题 | `FHeader` / `FHeader.nested` | 根页面视觉居中；嵌套页返回按钮不挤压标题 |
| 可点击信息块 | `AppCard` / `FCard` + `FTappable` | 卡片只承载独立项目，不嵌套卡片 |
| 设置列表 | `FTileGroup` + `FTile` | 组内使用完整边界和一致分隔线 |
| 文本输入 | `AppTextField` / `AppTextFormField` | 标签、提示、错误和前后缀走 Forui API |
| 主要动作 | `FButton` | 主要/次要/描边/危险变体语义明确 |
| 图标动作 | `AppIconButton` / `FButton.icon` | 44–48 热区、Lucide 图标、tooltip 和 semantics |
| 二值设置 | `FSwitch` | 会立即生效的设置优先使用开关 |
| 多选 | `FCheckbox` 或 `FSelectTileGroup` | 选择多个项目时不能伪装成 radio |
| 单选 | `FSelectTileGroup` + managed radio | 弹层顶部不放重复标题；选项标题保留 |
| 标签页 | `FTabs` | 只用于同一上下文的平级视图，不当作页面导航 |
| 弹层/确认 | `showFSheet` / `showFDialog` | 遵循弹层内边距、圆角和返回行为 |
| 反馈 | `FToaster` / `showAppSnackBar` | 文案短、可读、不会遮挡当前操作 |
| 加载 | `FCircularProgress` 或稳定尺寸 skeleton | 不因 spinner 出现而改变行高 |

### 6.2 图标规则

- 全项目图标固定为 `FIcons.lucide()` / `FLucideIcons`；不混用 Material Icons、Cupertino Icons 或手写 SVG。
- 图标视觉尺寸通常为 20dp；列表 leading 图标 20–22dp；空状态图标 40–48dp。
- 图标颜色跟随语义文字或状态，不为了装饰给每一项使用不同颜色。
- 只有图标的按钮必须提供 `tooltip`、`semanticsLabel` 和足够热区。
- 破坏性操作使用 `destructive` 变体和明确文字；不能只显示一个红色叉号。

### 6.3 表单与选择器

- 字段标签用于说明字段；选择器弹层中的选项标题用于说明选项，两者不是同一层级。
- 当触发字段已经清楚表达上下文时，单选弹层不显示重复的顶部 title；确实需要上下文时，使用有背景的 `FHeader` 或 `FDialog` 标题。
- 只读选择字段应显示当前值、placeholder 和 chevron；不能让用户误以为可以直接编辑。
- 星期、周次、节次等有限且有序的数据使用 Forui `FPicker` 或等价的滚轮选择器，不使用自由文本输入或自制下拉框。
- 同一个选择器同时编辑一组强关联范围值时，表单只提供一个触发字段并组合展示结果；例如课程节次显示为 `第3节` 或 `第3-5节`，弹层内部再使用开始、结束两个滚轮。禁止放置两个会打开同一弹层的重复字段。
- 课程颜色是业务数据，不属于页面样式色值：使用单个文本字段输入 `#RRGGBB`，始终保留前导 `#`、统一转为大写并在保存前校验；不提供颜色选择器或色板。第 4 节“页面代码不得写颜色字面量”的限制仅针对界面样式，不限制用户输入和持久化的颜色数据。
- 表单错误显示在字段附近，并保留用户已输入内容；失败请求不得无理由清空密码或表单。
- 键盘弹出时页面整体上移缩小（Android `adjustResize` + `resizeToAvoidBottomInset`），聚焦输入框保持在键盘上方；禁止输入框在滚动容器内单独滚动定位。

## 7. 页面模板

### 7.1 Tool 首页（`tools_page.dart`）

目标是快速扫描工具状态，不是把每个功能做成大卡片。

```text
AppPage(root, centered title)
└─ SafeArea
   └─ ListView
      padding: horizontal 16 / top 12 / bottom 20 (compact)
      ├─ 顶部摘要：固定两列，gap 8；一卡通与电费始终并排
      ├─ gap 12
      ├─ 其余工具行：每行最小高度 56
      ├─ gap 12
      └─ 最后一个项目
```

- `Tool` 页面使用断点式 16/24/32dp 边距，不得退回固定手机边距。
- 摘要卡片内边距横向 12–16、纵向 12；标题与副标题间距 4。
- 工具行只保留一个主标题、一个可选状态和一个动作指示；不要重复展示同一状态。
- 校园网不可用、电费为缓存、请求加载等状态使用语义色 + 文字，不把整张卡片染色。
- 顶部栏与第一组内容之间只留 12dp；禁止出现无法解释的空白带。

### 7.2 已登录 Profile 首页（`pages/profile/profile_page.dart`）

```text
AppPage(root, centered title)
└─ ListView
   padding: horizontal 16 / top 12 / bottom 20 (compact)
   ├─ 版本/法律元数据：caption，最多一行
   ├─ gap 20
   ├─ section label
   ├─ gap 8
   ├─ FTileGroup（全宽）
   ├─ gap 20
   ├─ 下一分组
   └─ 退出按钮（48 高度，底部留安全区）
```

- 分组标题不做成悬浮卡片；标题与组之间 8dp，组与组之间 20dp。
- `FTile` 最小高度 52，设置项左右内边距统一；开关和选择器在视觉右侧对齐。
- 学号、姓名等只读信息使用弱交互样式，不显示无意义的 chevron。
- 主题模式、课堂勿扰等即时设置优先使用 `FSwitch` 或 Forui 选择器；不要混用自制下拉框。
- 软件信息、许可证和调试入口使用同一组列表样式，不额外塞装饰图标或段落计数。
- 手机左右边距固定使用 compact 令牌 16dp；只有中屏和宽屏使用 24/32dp。

### 7.3 工具子页、查询结果和表单

- 子页统一 `AppPage`，内容最大宽度 720，手机左右 16dp。
- 查询页优先“状态/关键结果/详情/操作”的顺序；不要让用户先穿过说明文本才能看到结果。
- 表单字段间距 12–16；不同业务段落间距 20–24。
- 结果列表使用 `FTileGroup`、表格或单层 `AppCard`；不要把每一行包进多层卡片。
- 网络、缓存、过期和校园网限制要在结果附近显示；刷新按钮在不可用时明确禁用。
- 空状态包含图标、短标题和必要说明；错误状态说明下一步，不只写“失败”。

### 7.4 底部弹层和对话框

- 弹层横向内边距 12–16，顶部/底部遵循 SafeArea；最大高度一般不超过屏幕 60–70%。
- 单选/多选列表项最小高度 48，选中态有背景或勾选，但不靠颜色单独表达。
- 没有必要时不显示重复 title；需要标题时必须在有背景的 header 区域内渲染。
- 对话框只用于需要用户确认、输入或处理错误的中断场景；普通选择优先底部弹层。

### 7.5 课表和密集网格

- 课表是信息密集特例，允许 edge-to-edge 和更小字号，但不能遮挡、重叠或把操作热区缩小。
- 网格外的筛选、周次、编辑操作仍使用 44–48dp 热区和 16dp 容器边距。
- 颜色用于区分课程类别时，必须同时保留文本/位置/边框等非颜色线索；暗色主题要重新检查对比度。
- 课程编辑表单的周次、星期和节次使用只读选择字段；节次范围合并为一个字段，颜色使用包含 `#` 的六位 Hex 文本字段。

## 8. 交互、状态和动效

### 8.1 状态模型

每个会发请求或依赖网络的页面至少考虑：`idle`、`loading`、`success`、`empty`、`error`、`offline`、`stale/cache`、`disabled`。状态变化不能造成按钮、列表行或卡片突然改变高度。

- 加载：保留标题和布局，使用小型 progress 或 skeleton。
- 空数据：说明“没有数据”的原因和可执行下一步。
- 错误：保留已有缓存/用户输入，提供重试或返回路径。
- 缓存：显示“缓存”或更新时间；不能把旧数据伪装成实时数据。
- 禁用：降低对比度但仍保证文字可读，并说明禁用原因。

### 8.2 动效令牌

| 场景 | 时长 | 规则 |
| --- | ---: | --- |
| pressed/hover 状态 | 100ms | 只改变颜色/透明度，不移动布局 |
| 控件状态切换 | 160–200ms | 使用 ease-out，保持尺寸稳定 |
| 底部弹层/对话框 | 220–280ms | 只用于进入/退出，不循环 |
| 页面切换 | 180–240ms | 优先淡入或轻微位移 |

必须响应 `MediaQuery.disableAnimations` 或平台减少动效设置；减少动效时保留状态变化和焦点反馈。

## 9. 响应式与无障碍验收

### 9.1 必测尺寸

- Android 窄屏：360×800、412×915。
- 小屏横屏：800×360。
- 平板/宽屏：840×1280、1200×800。
- 亮色和暗色各测一遍。
- 系统文字比例 1.0、1.3、2.0 各测一遍。

### 9.2 验收清单

- [ ] Tool 和 Profile 在 360/390/412 宽度左右边距为 16dp，不出现过宽空白。
- [ ] 页面标题在有无右侧 action 时都以页面视觉中心对齐。
- [ ] 第一组内容与 header 之间没有无法解释的空白带。
- [ ] 所有按钮、列表行、图标操作的热区至少 44dp，优先 48dp。
- [ ] 打开和关闭键盘时页面整体上移/复位，聚焦输入框始终不被键盘遮挡，底部导航不覆盖输入内容。
- [ ] 文字在 2.0 倍系统字号下仍可读、可滚动、可换行；不截断关键数据。
- [ ] 正文对比度 >= 4.5:1，非文本控件边界/焦点 >= 3:1。
- [ ] 错误、成功、离线和缓存状态不只依靠颜色。
- [ ] 加载前后尺寸稳定，没有跳动或布局闪烁。
- [ ] 横向日志/代码区域只对明确的等宽数据启用，普通中文正文不强制横向滚动。
- [ ] 语义树能读出页面标题、按钮动作、开关状态和错误说明。
- [ ] 不存在 Material/Forui 混用造成的图标、圆角、按钮高度或字体风格不一致。

## 10. AI 实施流程

后续任何 UI 任务按以下顺序执行：

1. 阅读本文件、`lib/ui/app_theme.dart`、`lib/ui/app_components.dart` 和目标页面。
2. 先判断页面类别、断点、状态模型和可访问性风险，再决定组件。
3. 优先补充/复用语义令牌和公共组件；不要在页面里复制一套样式。
4. 按手机 16dp 边距先实现，再验证 medium/expanded 断点。
5. 用 Forui API 实现交互；查阅当前锁定版本的 API，不根据其他版本猜参数。
6. 检查空、错、加载、离线、缓存、禁用和长文本状态。
7. 运行 `dart format lib`、`flutter analyze`、`flutter test`；涉及 UI 的改动补充 widget/golden 或真机截图检查。
8. 逐项执行第 9 节验收清单，并在变更说明中记录未解决的视觉风险。

### 当前代码令牌

项目已在 `lib/ui/app_tokens.dart` 中集中实现以下令牌；新增页面必须复用这些名称与语义：

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
}

abstract final class AppLayout {
  static const compactGutter = 16.0;
  static const mediumGutter = 24.0;
  static const expandedGutter = 32.0;
  static const contentMaxWidth = 960.0;
  static const formMaxWidth = 560.0;
}
```

页面必须按本表取值；不要继续新增散落的 `EdgeInsets` 和颜色字面量。

## 11. 当前实施基线与持续检查

以下项目已于 2026-08-16 完成，属于后续修改必须保持的代码基线，不是可选建议。

### 已完成的页面与布局基线

- Tool 与 Profile 页面使用断点式 16/24/32dp 横向边距；结果页、表单和通用内容分别受 720/560/960dp 最大宽度约束。
- 页面统一使用 `AppPage`、`AppPageListView` 或 `AppPageBody`，标题居中且不保留无法解释的 header 下空白。
- 页面路由统一通过 `appRoute` 和 `AppRouteNames` 创建，每个 push 都必须具有稳定的语义名称。
- 图标操作统一使用 `AppIconButton`，热区不小于 44dp；业务页面不直接使用 Material 控件。

### 已完成的组件与主题基线

- spacing、页面 gutter、圆角、控制高度集中在 `lib/ui/`；`lib/ui/` 不放业务页面。
- `AppTheme` 已提供 success/warning/info/controlBorder 语义色，页面不得复制同义颜色常量。
- 普通工具标题使用 `tileTitle`，关键数值使用 `metric`，系统文字缩放不再锁定为 1.0。
- 设置类二值操作使用 `FSwitch`，多选使用 `FCheckbox`，单选/下拉使用 Forui sheet 或 select 组件。
- 业务图标统一采用 Forui Lucide 图标，许可证正文等不需要图形提示的列表不添加装饰图标。

### 持续质量控制

- 为 Tool、Profile、表单和弹层补充亮/暗色 widget/golden 截图。
- 对长中文、长错误、缓存标记、离线状态和 2.0 倍字体增加回归测试。
- 每次升级 Forui 或 Flutter 后重新核对组件默认圆角、内边距、触控尺寸和主题 token。
- 每次结构调整后运行旧类名、匿名路由和 Material 业务组件扫描，并执行 `flutter analyze`、`dart fix --dry-run`、`flutter test`。

## 12. 变更记录

| 版本 | 日期 | 说明 |
| --- | --- | --- |
| 1.3.0 | 2026-08-16 | 明确有限有序数据使用 Forui 滚轮选择器；关联范围共用单个触发字段；课程颜色改为始终包含 `#` 的 `#RRGGBB` 文本输入。 |
| 1.2.0 | 2026-08-16 | 键盘改为整体上移（`adjustResize` + `resizeToAvoidBottomInset`），输入框保持在键盘上方；设置行内输入器允许紧凑显示；Tool 一卡通与电费摘要固定并排。 |
| 1.1.0 | 2026-08-16 | 完成 Forui 全量迁移、响应式容器、语义主题、命名路由和页面目录整理；将偏差清单更新为实施基线。 |
| 1.0.0 | 2026-08-16 | 基于官方设计系统调研和当前 Forui 代码基线建立项目规范；明确 Tool/Profile 手机边距为 16dp。 |
