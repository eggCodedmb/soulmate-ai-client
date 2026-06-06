# AI伴侣App — UI设计文档（Flutter 双端版）

**文档版本：** v3.0
**编写日期：** 2026年6月5日
**文档状态：** 修订稿
**设计平台：** Flutter 3.x / iOS 15+ / Android 7.0+

---

## 1. 设计原则

### 1.1 核心理念

本应用采用 Flutter 构建跨平台 UI，以 iOS Human Interface Guidelines（HIG）为主要设计语言，同时兼顾 Android Material Design 3 的交互习惯。通过 `Cupertino` 组件库在 iOS 端呈现原生风格，`Material` 组件库在 Android 端呈现 Material You 风格，实现"两端各自原生"的体验。

### 1.2 五大设计原则

| 原则       | 说明                     | 落地方式                                |
| -------- | ---------------------- | ----------------------------------- |
| **平台适配** | iOS 和 Android 各自呈现原生风格 | 使用 `Cupertino` / `Material` 组件按平台切换 |
| **温暖感**  | 整体氛围柔和、有情感温度           | 暖色调渐变、圆润卡片、柔和阴影、微动效                 |
| **沉浸感**  | 对话成为绝对焦点，减少干扰          | 聊天页全屏沉浸、极简导航、内容优先                   |
| **个性化**  | 不同 AI 伴侣呈现不同视觉风格       | 主题色随性格变化、头像表情联动、自定义背景               |
| **安全感**  | 隐私与数据控制清晰可见            | 端到端加密标识、隐私仪表盘、数据导出/删除入口             |

### 1.3 平台差异化策略

| UI 元素   | iOS 端                    | Android 端                  |
| ------- | ------------------------ | -------------------------- |
| 导航栏     | CupertinoNavigationBar   | AppBar (Material 3)        |
| 返回手势    | 左滑返回（CupertinoPageRoute） | 系统返回按钮 + 手势返回              |
| 选择器     | CupertinoPicker          | Material Dropdown          |
| 弹窗      | CupertinoAlertDialog     | AlertDialog (Material 3)   |
| 滚动行为    | iOS 弹性滚动                 | Material 光晕 overscroll     |
| Tab 指示器 | CupertinoTabBar          | NavigationBar (Material 3) |

> 以下文档中，组件描述以通用设计语言为主，具体实现使用 Flutter 的 `Platform.isIOS` 判断或 `Theme.of(context).platform` 自动适配。

---

## 2. 设计规范

### 2.1 色彩体系

使用 Flutter 的 `ColorScheme` 体系，通过 `ThemeData` 统一管理 Light / Dark 主题。

#### 品牌色

| 色彩名称                | Light 色值            | Dark 色值             | 用途              |
| ------------------- | ------------------- | ------------------- | --------------- |
| Brand Pink          | `Color(0xFFFF6B8A)` | `Color(0xFFFF8FA8)` | 品牌主色、CTA按钮、重要操作 |
| Brand Lavender      | `Color(0xFFA78BFA)` | `Color(0xFFC4B5FD)` | 次要按钮、标签高亮、渐变终点  |
| Brand Warm Gradient | `#FF6B8A → #FFB88C` | `#FF8FA8 → #FFCBA4` | 首页背景渐变、氛围营造     |

#### 语义色（通过 ThemeData 配置）

```dart
// Light Theme
ColorScheme.light(
  surface: Color(0xFFFAFAFA),        // 页面底色
  surfaceContainerHighest: Color(0xFFFFFFFF),  // 卡片背景
  surfaceContainerLow: Color(0xFFF2F2F7),      // 输入框背景
  onSurface: Color(0xFF000000),       // 主文字色
  onSurfaceVariant: Color(0xFF6B7280), // 辅助文字色
  outline: Color(0xFFE5E7EB),         // 分割线
)

// Dark Theme
ColorScheme.dark(
  surface: Color(0xFF000000),
  surfaceContainerHighest: Color(0xFF1C1C1E),
  surfaceContainerLow: Color(0xFF2C2C2E),
  onSurface: Color(0xFFFFFFFF),
  onSurfaceVariant: Color(0xFF9CA3AF),
  outline: Color(0xFF374151),
)
```

#### 语义功能色

| 色彩  | Flutter 值                          | 用途        |
| --- | ---------------------------------- | --------- |
| 成功  | `Colors.green`                     | 在线状态、操作成功 |
| 警告  | `Colors.amber`                     | 提醒、注意     |
| 错误  | `Colors.red` / `colorScheme.error` | 错误提示、删除操作 |
| 信息  | `Colors.blue`                      | 链接、可点击元素  |

#### AI 伴侣性格主题色

每种性格类型对应一组主题色，用于气泡背景、头像边框、首页氛围色：

| 性格类型 | 主题色（Light）          | 主题色（Dark）           | 色彩名          |
| ---- | ------------------- | ------------------- | ------------ |
| 温柔型  | `Color(0xFFFFE4EC)` | `Color(0xFF3D2A30)` | Soft Rose    |
| 活泼型  | `Color(0xFFFFF3E0)` | `Color(0xFF3D3225)` | Warm Peach   |
| 沉稳型  | `Color(0xFFE3F2FD)` | `Color(0xFF1E2A3A)` | Calm Blue    |
| 幽默型  | `Color(0xFFFFFDE7)` | `Color(0xFF3D3A25)` | Sunny Yellow |
| 知性型  | `Color(0xFFF3E5F5)` | `Color(0xFF2E1F35)` | Muted Purple |
| 高冷型  | `Color(0xFFECEFF1)` | `Color(0xFF25282C)` | Cool Gray    |

**主题切换实现：** 通过 Riverpod 的 `StateProvider<ThemeMode>` 管理主题状态，`MaterialApp` 的 `theme` / `darkTheme` / `themeMode` 属性自动切换。AI 伴侣性格主题色通过 `ThemeData` 的 `extensions` 注入自定义主题扩展。

### 2.2 字体规范

使用 Flutter 原生的 `TextTheme` 体系，支持系统字体自动适配：

| 文字层级            | TextTheme Key    | 字号   | 字重       | 用途      |
| --------------- | ---------------- | ---- | -------- | ------- |
| Display Large   | `displayLarge`   | 57sp | Regular  | 品牌数字展示  |
| Headline Large  | `headlineLarge`  | 32sp | Bold     | 页面主标题   |
| Headline Medium | `headlineMedium` | 28sp | Bold     | 导航栏标题   |
| Title Large     | `titleLarge`     | 22sp | SemiBold | 模块标题    |
| Title Medium    | `titleMedium`    | 16sp | SemiBold | 卡片标题    |
| Body Large      | `bodyLarge`      | 16sp | Regular  | 正文、对话内容 |
| Body Medium     | `bodyMedium`     | 14sp | Regular  | 辅助说明    |
| Label Large     | `labelLarge`     | 14sp | Medium   | 按钮文字    |
| Label Medium    | `labelMedium`    | 12sp | Medium   | 标签、角标   |
| Label Small     | `labelSmall`     | 11sp | Regular  | 时间戳、徽章  |

```dart
// 主题字体配置
ThemeData(
  textTheme: GoogleFonts.notoSansScTextTheme().copyWith(
    // 中文使用 Noto Sans SC，英文使用 SF Pro（iOS）/ Roboto（Android）
    // Google Fonts 自动处理平台字体回退
  ),
)
```

**字体回退策略：**

- iOS 端：SF Pro（系统默认）→ PingFang SC（中文）
- Android 端：Roboto（系统默认）→ Noto Sans SC（中文）
- 使用 `google_fonts` 包统一管理字体，自动处理平台差异

### 2.3 圆角规范

| 元素       | 圆角值       | Flutter 实现                                                               |
| -------- | --------- | ------------------------------------------------------------------------ |
| 大型卡片     | 20dp      | `RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))`        |
| 中型卡片     | 16dp      | `BorderRadius.circular(16)`                                              |
| 小型卡片     | 12dp      | `BorderRadius.circular(12)`                                              |
| 按钮       | 全圆角胶囊形    | `StadiumBorder()` 或 `RoundedRectangleBorder(borderRadius: 999)`          |
| 对话气泡（AI） | 18dp，左上尖角 | 自定义 `CustomClipper<Path>`                                                |
| 对话气泡（用户） | 18dp，右上尖角 | 自定义 `CustomClipper<Path>`                                                |
| 头像       | 50% 圆形    | `CircleBorder()`                                                         |
| 弹窗       | 16dp      | `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` |
| 输入框      | 20dp      | `OutlineInputBorder(borderRadius: BorderRadius.circular(20))`            |

### 2.4 间距与布局

基于 8dp 网格系统：

| 场景            | 值                | Flutter 实现                                            |
| ------------- | ---------------- | ----------------------------------------------------- |
| 页面水平边距        | 16dp             | `padding: EdgeInsets.symmetric(horizontal: 16)`       |
| 卡片内边距         | 16dp             | `padding: EdgeInsets.all(16)`                         |
| 卡片间距          | 12dp             | `ListView.separated(separator: SizedBox(height: 12))` |
| 组件内元素间距       | 8dp              | `SizedBox(width/height: 8)`                           |
| 状态栏安全区域       | 系统自动             | `SafeArea` widget                                     |
| 底部 Tab Bar 高度 | 56dp + safe area | `BottomNavigationBar` 或 `CupertinoTabBar`             |

### 2.5 图标与图形

#### 应用图标（App Icon）

应用图标需同时适配 iOS 和 Android 两套规范：

| 平台 | 尺寸要求 | 形状 | 说明 |
|------|----------|------|------|
| iOS | 1024×1024px | 无（系统自动裁切为圆角矩形） | 不要自行添加圆角或透明通道 |
| Android | 432×432px（自适应图标） | 前景 + 背景分层 | 系统自动裁切圆形/圆角方形/Squircle |

**图标设计规范：**
- 主体：品牌心形 + AI 伴侣剪影的融合图形
- 背景：品牌渐变（Brand Pink → Brand Lavender），45° 角线性渐变
- 前景：白色心形，内部包含一个抽象的对话气泡轮廓
- 禁止：文字、过细线条、照片、透明背景

**资源文件命名：**
```
assets/
├── app_icon/
│   ├── icon_ios_1024.png          # iOS App Icon
│   ├── icon_android_foreground.png # Android 自适应图标前景（432×432）
│   └── icon_android_background.png # Android 自适应图标背景（432×432）
```

#### 启动页（Splash Screen）资源

iOS 和 Android 各有原生启动屏机制，Flutter 通过以下方式配置：

**iOS — LaunchScreen.storyboard：**
- 使用 Xcode 的 LaunchScreen.storyboard 配置
- 背景：品牌色 `#FF6B8A`（纯色，不使用渐变，避免 storyboard 渲染问题）
- 中央：品牌 Logo 图片（`splash_logo.png`，@1x/@2x/@3x 三套）
- 底部：品牌名称文字（UILabel，白色，PingFang SC Semibold 18pt）
- 安全区域：自动适配刘海/Dynamic Island

**Android — themes.xml + drawable：**
- 使用 `android:windowBackground` 配置启动窗口背景
- 背景：drawable XML 定义品牌色渐变（`#FF6B8A` → `#FFB88C`，从上到下）
- 中央：`layer-list` drawable 叠加品牌 Logo（`splash_logo.png`，mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi 五套）
- 底部：品牌名称文字（通过 `TextView` 在 `SplashActivity` 中设置）

**Flutter 侧过渡页（SplashPage）：**

原生启动屏消失后，Flutter 渲染接管，需要一个过渡页实现无缝衔接：

```dart
// 启动页完整实现规范
class SplashPage extends StatefulWidget { ... }

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Logo: 从 0.8 缩放至 1.0 + 淡入
    _logoScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.4)),
    );

    // 文字: 延迟 400ms 后淡入 + 上移
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.3, 0.7)),
    );
    _textSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    _logoController.forward();

    // 1.5 秒后跳转
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }
}
```

**启动页视觉规范（Light / Dark 双模式）：**

| 元素 | Light 模式 | Dark 模式 |
|------|-----------|-----------|
| 背景 | 品牌渐变 `LinearGradient(begin: topCenter, end: bottomCenter, colors: [Color(0xFFFF6B8A), Color(0xFFFFB88C)])` | 深色渐变 `LinearGradient(colors: [Color(0xFF1A0A10), Color(0xFF2D1520)])` |
| Logo | 白色 Logo（`assets/app_icon/splash_logo_light.png`） | 浅粉 Logo（`assets/app_icon/splash_logo_dark.png`） |
| 品牌名称 | 白色文字，`headlineMedium`，字重 SemiBold | 浅粉文字 `Color(0xFFFFB8C8)`，同字重 |
| 副标题（可选） | 白色 70% 不透明度，`bodyMedium` | 浅粉 70% 不透明度 |
| 底部版本号 | 白色 50% 不透明度，`labelSmall` | 浅粉 50% 不透明度 |

```dart
// 启动页背景 — 自动适配 Light/Dark
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: Theme.of(context).brightness == Brightness.light
          ? [Color(0xFFFF6B8A), Color(0xFFFFB88C)]   // Light
          : [Color(0xFF1A0A10), Color(0xFF2D1520)],   // Dark
    ),
  ),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo — 根据主题加载不同资源
        FadeTransition(
          opacity: _logoOpacity,
          child: ScaleTransition(
            scale: _logoScale,
            child: Image.asset(
              Theme.of(context).brightness == Brightness.light
                  ? 'assets/app_icon/splash_logo_light.png'
                  : 'assets/app_icon/splash_logo_dark.png',
              width: 100,
              height: 100,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 品牌名称
        FadeTransition(
          opacity: _textOpacity,
          child: SlideTransition(
            position: _textSlide,
            child: Text(
              'SoulMate AI',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Color(0xFFFFB8C8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 副标题
        FadeTransition(
          opacity: _textOpacity,
          child: Text(
            '你的专属AI伴侣',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: (Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Color(0xFFFFB8C8)).withOpacity(0.7),
            ),
          ),
        ),
      ],
    ),
  ),
)
```

#### 引导页（Onboarding）视觉规范

引导页同样需要完整的 Light / Dark 双模式适配：

**第 1 页 — "遇见你的专属伴侣"**

| 元素 | Light 模式 | Dark 模式 |
|------|-----------|-----------|
| 背景渐变 | `Brand Pink → Brand Lavender` 从上到下 | `Color(0xFF1A0A10) → Color(0xFF1A1025)` |
| 插画 | 彩色插画（`onboarding_1_light.png`） | 彩色插画（`onboarding_1_dark.png`），整体降低亮度 15% |
| 底部卡片背景 | `Colors.white` | `Color(0xFF1C1C1E)` |
| 标题文字 | `Color(0xFF1A1A2E)`，`headlineMedium` | `Colors.white`，`headlineMedium` |
| 副标题文字 | `Color(0xFF6B7280)`，`bodyMedium` | `Color(0xFF9CA3AF)`，`bodyMedium` |
| 指示器-未选中 | `Color(0xFFE5E7EB)` | `Color(0xFF374151)` |
| 指示器-选中 | `Brand Pink` | `Brand Pink`（保持不变） |
| 按钮背景 | `Brand Pink` | `Brand Pink`（保持不变） |
| 按钮文字 | `Colors.white` | `Colors.white`（保持不变） |

**第 2 页 — "随时倾听，永远陪伴"**

| 元素 | Light 模式 | Dark 模式 |
|------|-----------|-----------|
| 背景渐变 | `Color(0xFFF3E5F5) → Color(0xFFE8EAF6)` 淡紫 | `Color(0xFF1A1025) → Color(0xFF0F1525)` 深紫 |
| 其余元素 | 同第 1 页配色规则 | 同第 1 页配色规则 |

**第 3 页 — "独一无二，为你而生"**

| 元素 | Light 模式 | Dark 模式 |
|------|-----------|-----------|
| 背景渐变 | `Color(0xFFFFF3E0) → Color(0xFFFFE4EC)` 暖粉 | `Color(0xFF2D1520) → Color(0xFF1A0A10)` 深暖 |
| 其余元素 | 同第 1 页配色规则 | 同第 1 页配色规则 |

```dart
// 引导页单页组件 — 统一主题适配
class OnboardingPageContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final String lightIllustration;
  final String darkIllustration;
  final List<Color> lightGradient;
  final List<Color> darkGradient;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight ? lightGradient : darkGradient,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Image.asset(
              isLight ? lightIllustration : darkIllustration,
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isLight ? Colors.white : Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isLight ? Color(0xFF1A1A2E) : Colors.white,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isLight ? Color(0xFF6B7280) : Color(0xFF9CA3AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 系统图标映射

iOS 端使用 **SF Symbols** 风格图标，Android 端使用 **Material Icons**，通过 `Icon` widget 自动适配：

| 位置 | iOS (CupertinoIcons) | Android (Icons) |
|------|---------------------|-----------------|
| Tab - 首页 | `CupertinoIcons.house_fill` | `Icons.home_filled` |
| Tab - 对话 | `CupertinoIcons.chat_bubble_2_fill` | `Icons.chat_bubble_rounded` |
| Tab - 伴侣 | `CupertinoIcons.heart_circle_fill` | `Icons.favorite_rounded` |
| Tab - 我的 | `CupertinoIcons.person_crop_circle_fill` | `Icons.person_rounded` |
| 发送按钮 | `CupertinoIcons.arrow_up_circle_fill` | `Icons.send_rounded` |
| 语音按钮 | `CupertinoIcons.mic_fill` | `Icons.mic_rounded` |
| 图片按钮 | `CupertinoIcons.photo_on_rectangle` | `Icons.image_rounded` |
| 表情按钮 | `CupertinoIcons.smiley_fill` | `Icons.emoji_emotions_rounded` |
| 返回 | `CupertinoIcons.back` | `Icons.arrow_back_rounded` |
| 更多 | `CupertinoIcons.ellipsis_circle` | `Icons.more_vert_rounded` |
| 设置 | `CupertinoIcons.settings_solid` | `Icons.settings_rounded` |
| 记忆 | `CupertinoIcons brain` | `Icons.psychology_rounded` |
| 日记 | `CupertinoIcons.book_fill` | `Icons.menu_book_rounded` |
| 订阅 | `CupertinoIcons.money_dollar_circle_fill` | `Icons.workspace_premium_rounded` |

```dart
// 平台自适应图标封装 — 同时支持 Light/Dark 颜色自适应
class AdaptiveIcon extends StatelessWidget {
  final IconData iosIcon;
  final IconData androidIcon;
  final double? size;
  final Color? color; // 留空则自动使用 onSurfaceVariant

  const AdaptiveIcon({
    required this.iosIcon,
    required this.androidIcon,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Platform.isIOS ? iosIcon : androidIcon,
      size: size ?? 24,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
```

#### AI 伴侣形象

采用 2D 半写实风格插画，通过 **Lottie** 动画引擎驱动表情变化系统：

- 基础表情集：微笑、开心、害羞、思考、难过、惊讶、困倦、生气（共 8 种）
- 每种表情提供 Light / Dark 两套 Lottie 文件（背景透明，角色肤色在 Dark 模式下微调亮度）
- 表情过渡：使用 Lottie 的状态机实现表情之间的平滑过渡动画
- 表情触发：由后端情绪分析结果驱动前端表情切换
- 头像边框：使用性格主题色的渐变圆环，带微妙的呼吸动画

**Lottie 资源组织：**
```
assets/lottie/
├── partner/
│   ├── light/
│   │   ├── smile.json
│   │   ├── happy.json
│   │   ├── shy.json
│   │   ├── think.json
│   │   ├── sad.json
│   │   ├── surprise.json
│   │   ├── sleepy.json
│   │   └── angry.json
│   └── dark/
│       ├── smile.json
│       └── ...（同上，角色亮度降低 10%）
├── ui/
│   ├── empty_chat.json       # 空状态-对话列表
│   ├── empty_memory.json     # 空状态-记忆相册
│   ├── celebration.json      # 创建成功/订阅成功庆祝
│   ├── loading_dots.json     # AI正在输入
│   └── onboarding_1.json     # 引导页动画
```

```dart
// Lottie 动画播放 — 自动适配主题
class PartnerLottie extends StatelessWidget {
  final String expression; // 'smile', 'happy', 'shy', ...
  final double width;
  final double height;

  const PartnerLottie({
    required this.expression,
    this.width = 200,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final path = 'assets/lottie/partner/${isLight ? "light" : "dark"}/$expression.json';

    return Lottie.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      repeat: true,
      animate: true,
    );
  }
}
```

#### 插画资源规范

所有页面插画（空状态、引导页、错误页等）均需提供 Light / Dark 两套：

| 资源类型 | Light 文件 | Dark 文件 | 说明 |
|----------|-----------|-----------|------|
| 引导页插画 ×3 | `onboarding_{n}_light.png` | `onboarding_{n}_dark.png` | SVG 导出为 @1x/@2x/@3x PNG |
| 空状态插画 | `empty_{scene}_light.png` | `empty_{scene}_dark.png` | 对话空、记忆空、搜索空等 |
| 错误页插画 | `error_{type}_light.png` | `error_{type}_dark.png` | 网络错误、服务器错误等 |
| 品牌 Logo | `splash_logo_light.png` | `splash_logo_dark.png` | 启动页专用，@1x/@2x/@3x |

### 2.6 阴影与层级

阴影颜色同样需要适配 Dark 模式（Dark 模式下阴影更重，以保证层次感）：

```dart
// 统一阴影工具类
class AppShadows {
  static List<BoxShadow> level1(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isLight ? 0.05 : 0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> level2(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isLight ? 0.1 : 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> level3(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isLight ? 0.15 : 0.4),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

// 使用示例
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(16),
    boxShadow: AppShadows.level1(context),
  ),
)
```

### 2.7 统一主题系统

所有颜色、文字、组件样式通过 `ThemeData` 统一管理，页面代码中**禁止硬编码颜色值**，一律使用 `Theme.of(context).colorScheme` 或 `Theme.of(context).textTheme` 引用语义 Token。

#### 完整 ThemeData 定义

```dart
// ==================== Light Theme ====================
final lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  // 色彩体系
  colorScheme: ColorScheme.light(
    primary: Color(0xFFFF6B8A),           // 品牌主色
    onPrimary: Colors.white,              // 主色上的文字
    primaryContainer: Color(0xFFFFE4EC),  // 主色容器（浅粉）
    onPrimaryContainer: Color(0xFF3D0015),// 主色容器上的文字
    secondary: Color(0xFFA78BFA),         // 辅助色
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF3E5F5),
    onSecondaryContainer: Color(0xFF2E1F35),
    surface: Color(0xFFFAFAFA),           // 页面底色
    onSurface: Color(0xFF1A1A2E),         // 主文字色
    onSurfaceVariant: Color(0xFF6B7280),  // 辅助文字色
    surfaceContainerHighest: Colors.white,// 卡片背景
    surfaceContainerHigh: Color(0xFFF8F8F8),
    surfaceContainerLow: Color(0xFFF2F2F7),// 输入框背景
    surfaceContainer: Color(0xFFF5F5F5),
    outline: Color(0xFFE5E7EB),           // 分割线
    outlineVariant: Color(0xFFF3F4F6),
    error: Color(0xFFEF4444),
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
  ),

  // 背景色
  scaffoldBackgroundColor: Color(0xFFFAFAFA),

  // 字体
  textTheme: GoogleFonts.notoSansScTextTheme(
    ThemeData.light().textTheme,
  ),

  // AppBar
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFFFAFAFA),
    foregroundColor: Color(0xFF1A1A2E),
    elevation: 0,
    scrolledUnderElevation: 0.5,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A2E),
    ),
  ),

  // Card
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    shadowColor: Colors.transparent,
  ),

  // ElevatedButton
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFFF6B8A),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: StadiumBorder(),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),

  // OutlinedButton
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFFFF6B8A),
      side: BorderSide(color: Color(0xFFFF6B8A)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: StadiumBorder(),
    ),
  ),

  // TextButton
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Color(0xFFFF6B8A),
      textStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
  ),

  // InputDecoration (TextField)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFFF2F2F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Color(0xFFFF6B8A), width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
  ),

  // BottomNavigationBar
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFFFF6B8A),
    unselectedItemColor: Color(0xFF9CA3AF),
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),

  // Divider
  dividerTheme: DividerThemeData(
    color: Color(0xFFF3F4F6),
    thickness: 0.5,
    space: 0,
  ),

  // Chip
  chipTheme: ChipThemeData(
    backgroundColor: Color(0xFFF2F2F7),
    selectedColor: Color(0xFFFF6B8A),
    labelStyle: TextStyle(fontSize: 13),
    shape: StadiumBorder(),
    side: BorderSide.none,
  ),

  // Dialog
  dialogTheme: DialogTheme(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
    contentTextStyle: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
  ),

  // BottomSheet
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),

  // SnackBar
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Color(0xFF1A1A2E),
    contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),

  // ListTile
  listTileTheme: ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
    titleTextStyle: TextStyle(fontSize: 16, color: Color(0xFF1A1A2E)),
    subtitleTextStyle: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
  ),

  // Switch
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return Color(0xFF9CA3AF);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Color(0xFFFF6B8A);
      return Color(0xFFE5E7EB);
    }),
  ),

  // Slider
  sliderTheme: SliderThemeData(
    activeTrackColor: Color(0xFFFF6B8A),
    inactiveTrackColor: Color(0xFFE5E7EB),
    thumbColor: Color(0xFFFF6B8A),
    overlayColor: Color(0xFFFF6B8A).withOpacity(0.12),
  ),
);

// ==================== Dark Theme ====================
final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  colorScheme: ColorScheme.dark(
    primary: Color(0xFFFF8FA8),           // Dark 模式品牌色（降低饱和度）
    onPrimary: Color(0xFF1A0A10),
    primaryContainer: Color(0xFF3D2A30),
    onPrimaryContainer: Color(0xFFFFD6E0),
    secondary: Color(0xFFC4B5FD),
    onSecondary: Color(0xFF1A1025),
    secondaryContainer: Color(0xFF2E1F35),
    onSecondaryContainer: Color(0xFFE8DAFF),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF9CA3AF),
    surfaceContainerHighest: Color(0xFF1C1C1E),
    surfaceContainerHigh: Color(0xFF252527),
    surfaceContainerLow: Color(0xFF2C2C2E),
    surfaceContainer: Color(0xFF1E1E20),
    outline: Color(0xFF374151),
    outlineVariant: Color(0xFF2D2D30),
    error: Color(0xFFF87171),
    onError: Color(0xFF1A0A0A),
    errorContainer: Color(0xFF4A1C1C),
    onErrorContainer: Color(0xFFFCA5A5),
  ),

  scaffoldBackgroundColor: Color(0xFF000000),

  textTheme: GoogleFonts.notoSansScTextTheme(
    ThemeData.dark().textTheme,
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF000000),
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),

  cardTheme: CardTheme(
    color: Color(0xFF1C1C1E),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    shadowColor: Colors.transparent,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFFF8FA8),
      foregroundColor: Color(0xFF1A0A10),
      elevation: 0,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: StadiumBorder(),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFFFF8FA8),
      side: BorderSide(color: Color(0xFFFF8FA8)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: StadiumBorder(),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Color(0xFFFF8FA8),
      textStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF2C2C2E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Color(0xFFFF8FA8), width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(color: Color(0xFF6B7280)),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1C1C1E),
    selectedItemColor: Color(0xFFFF8FA8),
    unselectedItemColor: Color(0xFF6B7280),
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),

  dividerTheme: DividerThemeData(
    color: Color(0xFF2D2D30),
    thickness: 0.5,
    space: 0,
  ),

  chipTheme: ChipThemeData(
    backgroundColor: Color(0xFF2C2C2E),
    selectedColor: Color(0xFFFF8FA8),
    labelStyle: TextStyle(fontSize: 13, color: Colors.white),
    shape: StadiumBorder(),
    side: BorderSide.none,
  ),

  dialogTheme: DialogTheme(
    backgroundColor: Color(0xFF1C1C1E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    contentTextStyle: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
  ),

  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: Color(0xFF1C1C1E),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),

  snackBarTheme: SnackBarThemeData(
    backgroundColor: Color(0xFF2C2C2E),
    contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),

  listTileTheme: ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
    titleTextStyle: TextStyle(fontSize: 16, color: Colors.white),
    subtitleTextStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
  ),

  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return Color(0xFF6B7280);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Color(0xFFFF8FA8);
      return Color(0xFF374151);
    }),
  ),

  sliderTheme: SliderThemeData(
    activeTrackColor: Color(0xFFFF8FA8),
    inactiveTrackColor: Color(0xFF374151),
    thumbColor: Color(0xFFFF8FA8),
    overlayColor: Color(0xFFFF8FA8).withOpacity(0.12),
  ),
);
```

#### 主题切换实现

```dart
// Riverpod 状态管理
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    // 从本地存储读取用户偏好，默认跟随系统
    final saved = ref.read(localStorageProvider).getString('theme_mode');
    return ThemeMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref.read(localStorageProvider).setString('theme_mode', mode.name);
  }
}

// MaterialApp 配置
MaterialApp.router(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: ref.watch(themeModeNotifierProvider), // system / light / dark
  routerConfig: router,
)
```

#### 页面代码中的正确用法

```dart
// ✅ 正确 — 使用语义 Token
Container(
  color: Theme.of(context).colorScheme.surface,              // 自动适配 Light/Dark
  child: Text(
    '标题',
    style: Theme.of(context).textTheme.titleLarge,            // 自动适配字体
  ),
)

Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest, // 卡片背景
    borderRadius: BorderRadius.circular(16),
    boxShadow: AppShadows.level1(context),                        // 阴影自动适配
  ),
)

// ❌ 错误 — 硬编码颜色
Container(color: Color(0xFFFAFAFA))       // 不会响应 Dark 模式
Container(color: Colors.white)             // Dark 模式下刺眼
Text('标题', style: TextStyle(color: Color(0xFF1A1A2E)))  // Dark 模式下不可见
```

---

## 3. 导航架构

### 3.1 整体导航结构

使用 **go_router** 实现声明式路由，配合 `StatefulNavigationShell` 管理底部 Tab 导航：

```dart
// 路由配置核心结构
GoRouter(
  routes: [
    // 启动页
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    // 引导页
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    // 登录页
    GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
    // 主界面（底部 Tab）
    StatefulNavigationShell(
      branches: [
        // Tab 0: 首页
        // Tab 1: 消息
        // Tab 2: 伴侣
        // Tab 3: 我的
      ],
      builder: (_, __, shell) => MainScaffold(navigationShell: shell),
    ),
  ],
)
```

| Tab | 索引  | 图标                       | 标题  | 根页面                         |
| --- | --- | ------------------------ | --- | --------------------------- |
| 首页  | 0   | house.fill / home_filled | 首页  | HomePage — 伴侣主页             |
| 消息  | 1   | chat_bubble / chat       | 消息  | ConversationListPage — 聊天列表 |
| 伴侣  | 2   | heart / favorite         | 伴侣  | PartnerManagePage — 伴侣管理    |
| 我的  | 3   | person / person          | 我的  | ProfilePage — 个人中心          |

### 3.2 页面导航层级

```
App 入口
├── SplashPage（启动页）
├── OnboardingPage（引导页，仅首次启动显示）
│   └── 使用 PageView + SmoothPageIndicator 实现 3 页滑动引导
├── AuthPage（登录/注册）
│   ├── 邮箱验证码登录
│   └── 游客体验入口
└── MainScaffold（主界面 StatefulShellRoute）
    ├── Tab 0: HomePage（首页 — 伴侣主页）
    │   ├── PartnerDetailPage（伴侣详情，push 导航）
    │   └── MemoryAlbumPage（记忆相册，bottom sheet）
    ├── Tab 1: ConversationListPage（对话列表）
    │   └── ChatPage（聊天详情，push 导航）
    │       ├── VoiceCallPage（语音通话，full-screen dialog）
    │       ├── ImagePreviewPage（图片查看，full-screen dialog）
    │       └── ChatSettingPage（聊天设置，bottom sheet）
    ├── Tab 2: PartnerManagePage（伴侣管理）
    │   ├── PartnerCreatePage（创建伴侣，bottom sheet）
    │   └── PartnerEditPage（编辑伴侣，push 导航）
    └── Tab 3: ProfilePage（个人中心）
        ├── SubscriptionPage（订阅会员，push 导航）
        ├── MemoryManagePage（记忆管理，push 导航）
        ├── MoodDiaryPage（情绪日记，push 导航）
        └── SettingPage（设置，push 导航）
            ├── AccountSecurityPage（账号安全）
            ├── ModelConfigPage（模型配置）
            └── NotificationSettingPage（通知设置）
```

### 3.3 导航模式

| 场景     | 导航方式        | Flutter / go_router 实现                                               |
| ------ | ----------- | -------------------------------------------------------------------- |
| Tab 切换 | 底部 Tab Bar  | `StatefulNavigationShell.goBranch(index)`                            |
| 页面前进   | 右滑推入        | `context.push('/path')` → `CupertinoPageRoute` / `MaterialPageRoute` |
| 弹出表单   | 底部弹出        | `showModalBottomSheet(context: context, ...)`                        |
| 全屏覆盖   | 全屏推入        | `context.push('/path')` + `fullscreenDialog: true`                   |
| 确认弹窗   | 居中弹窗        | `showCupertinoDialog()` (iOS) / `showDialog()` (Android)             |
| 返回     | 左滑返回 / 返回按钮 | `context.pop()` + `CupertinoNavigationBar` 自动支持                      |

---

## 4. 核心页面设计

### 4.1 启动页与引导页

> 启动页与引导页的完整视觉规范（Light/Dark 双模式配色、资源文件、代码实现）已在 **2.5 图标与图形 → 启动页（Splash Screen）资源** 和 **引导页（Onboarding）视觉规范** 中定义。本节仅描述页面行为与交互逻辑。

#### 启动页（SplashPage）— 行为规范

**启动流程：**

1. App 冷启动 → 系统原生启动屏（iOS LaunchScreen.storyboard / Android themes.xml）展示
2. Flutter 引擎初始化完成 → 原生启动屏消失 → Flutter 渲染 `SplashPage`
3. `SplashPage` 播放 Logo + 文字的淡入动画（1500ms）
4. 动画播放期间执行以下异步任务（并行）：
   - 检查登录状态（Keychain / SecureStorage 读取 JWT）
   - 检查是否首次启动（SharedPreferences 读取标记）
   - 预加载当前 AI 伴侣的基础数据（Drift 本地数据库）
5. 动画结束 + 异步任务完成 → 根据状态跳转：
   - 已登录 → 直接进入主界面 `MainScaffold`
   - 未登录 + 首次启动 → 进入引导页 `OnboardingPage`
   - 未登录 + 非首次 → 进入登录页 `AuthPage`

**异常处理：**
- 异步任务超过 3 秒未完成 → 显示品牌 Logo 下方的加载指示器（`CircularProgressIndicator`，白色，24dp）
- 网络异常 → 仍允许进入主界面（离线模式），顶部显示网络状态横幅

#### 引导页（OnboardingPage）— 交互规范

**页面结构：**

`PageView` + `SmoothPageIndicator` 实现全屏分页滑动，共 3 页，使用 `OnboardingPageContent` 统一组件（已在 2.5 节定义）。

**第 1 页 — "遇见你的专属伴侣"**
- 插画：AI 伴侣的全身形象微笑动画（Lottie）
- 副标题："一个懂你、陪你、永远在身边的AI伴侣"

**第 2 页 — "随时倾听，永远陪伴"**
- 插画：对话场景（气泡形态的对话框，展示用户与 AI 的互动）
- 副标题："24小时在线，理解你的每一句话"

**第 3 页 — "独一无二，为你而生"**
- 插画：多角色形象展示（不同性格的 AI 伴侣形象并排）
- 副标题："自由定义性格、外貌、关系"

**交互细节：**

- **背景渐变过渡：** 使用 `PageController` 的 `addListener` 获取当前页面偏移量（`page`），通过 `Color.lerp` 在相邻两页的渐变色之间插值，实现背景色平滑过渡
- **圆点指示器：** `SmoothPageIndicator` 配置 `WormEffect`（虫蠕动效果），`activeColor: brandPink`，`dotColor` 自动适配 Light/Dark（Light: `Color(0xFFE5E7EB)`，Dark: `Color(0xFF374151)`）
- **按钮文案：** 第 1-2 页显示"继续"，第 3 页显示"开始体验"
- **页面跳转：** 点击"开始体验"后，使用 `SharedPreferences` 写入 `onboarding_completed: true`，然后 `Navigator.pushReplacement` 跳转至 `AuthPage`
- **跳过功能：** 右上角显示"跳过"文字按钮（`TextButton`，`onSurfaceVariant` 色），点击直接跳转至 `AuthPage`
- **滑动阻尼：** `PageView.physics` 使用默认 `BouncingScrollPhysics`（iOS 弹性）或 `ClampingScrollPhysics`（Android 光晕），自动适配平台

### 4.2 登录/注册页（AuthPage）

**页面布局：**

采用 `SingleChildScrollView` + `Column` 布局，背景为系统 scaffold 背景色：

- **顶部区域：** 品牌 Logo（居中，80dp 大小）+ 应用名称（`headlineMedium`）+ "欢迎回来"副标题（`bodyMedium`，`onSurfaceVariant` 色），间距 16dp
- **表单区域：** `Column` 排列，间距 16dp
  - 邮箱输入框：`TextFormField`，配置 `keyboardType: TextInputType.emailAddress`、`autofillHints: [AutofillHints.email]`，圆角胶囊形 `OutlineInputBorder`
  - 验证码输入框：`TextFormField` + 右侧 `TextButton`（"获取验证码"），点击后 60 秒倒计时，倒计时期间 `.enabled = false` 且文字变为"重新获取(59s)"
  - 登录按钮：`ElevatedButton` + `StadiumBorder`，品牌色填充（`backgroundColor`），白色文字（`foregroundColor`），`headlineMedium` 字重。未填写完整时 `onPressed: null`（自动置灰）
- **分割区域：** 居中 "—— 或 ——" 文字（`onSurfaceVariant` 色，`labelMedium` 字号），使用 `Row` + `Expanded` + `Divider` 实现
- **游客入口：** `TextButton`（"游客体验"），`foregroundColor: onSurfaceVariant`
- **底部区域：** `CheckboxListTile` 用于勾选同意协议，配合 `Text.rich` + `GestureRecognizer` 实现可点击的协议链接

**交互细节：**

- 键盘弹出时页面自动上推，使用 `SingleChildScrollView` 的 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`
- 验证码发送按钮点击后进入倒计时状态，使用 `Timer.periodic` 驱动状态更新
- 登录成功后使用 `Navigator.pushReplacement` 过渡至主界面

### 4.3 首页（HomePage）— 伴侣主页

首页是用户打开应用后看到的第一个页面，承担"与 AI 伴侣建立情感连接"的核心任务。

**页面结构：**

采用 `CustomScrollView` + `Sliver` 系列组件构建高性能滚动布局：

**Sliver 1 — 氛围背景（SliverAppBar flexibleSpace）**

- 使用 `SliverAppBar` + `expandedHeight: 300`，`flexibleSpace` 内放置 `LinearGradient` 背景
- 颜色为当前 AI 伴侣性格主题色渐变
- 滚动时自动折叠，产生视差效果

**Sliver 2 — 顶部状态栏（SliverToBoxAdapter）**

- `Row` 布局：左侧当前时间（`labelMedium`，`onSurfaceVariant` 色）+ 右侧天气信息（图标 + 温度）
- `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)`

**Sliver 3 — AI 伴侣形象区（SliverToBoxAdapter）**

- 占页面约 40% 高度的中心区域
- `Lottie.asset()` 播放当前表情动画，`width: 200, height: 200`
- 形象下方：呼吸光晕效果，使用 `AnimatedContainer` + `BoxDecoration` 的 `boxShadow` 循环动画
- 点击形象触发互动：`GestureDetector` + `onTap`，伴侣播放打招呼动画 + 显示随机问候语气泡

**Sliver 4 — 问候语卡片（SliverToBoxAdapter）**

- `Container` + `BoxDecoration(color: surfaceContainerHighest, borderRadius: 16)`
- 内部 `Column` 排列：
  - 主问候语：根据时间段动态切换，`titleLarge` 字重
  - 副标题：AI 伴侣的当前情绪状态描述，`bodyMedium`，`onSurfaceVariant` 色

**Sliver 5 — 互动信息卡片区（SliverToBoxAdapter）**

- `GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics())`
- 卡片 1 — "在一起的时光"：日历图标 + "第 30 天" + "相识于 2026年5月6日"
- 卡片 2 — "上次聊天"：气泡图标 + 最后一次对话摘要（最多 2 行 `maxLines: 2, overflow: TextOverflow.ellipsis`）
- 卡片 3 — "今日情绪"：情绪图标 + 情绪状态文字 + 简易情绪曲线
- 卡片 4 — "记忆碎片"：脑图标 + 最近一条记忆摘要
- 每张卡片：`Container` + `BoxDecoration`（白色背景、16dp 圆角、层级 1 阴影）

**Sliver 6 — 快捷入口区（SliverToBoxAdapter）**

- `SingleChildScrollView(scrollDirection: Axis.horizontal)` 水平滚动
- 内部 `Row` 排列，间距 12dp
- 入口胶囊按钮：`Chip` 或自定义 `Container` + `StadiumBorder`
  - "💬 聊天" — 跳转至该伴侣的聊天页
  - "🎵 一起听歌" — 触发音乐共享功能
  - "📖 讲故事" — 触发故事共创模式
  - "🎮 玩游戏" — 触发互动游戏模式
  - "🧘 一起冥想" — 触发冥想引导模式

**交互细节：**

- 下拉刷新：`RefreshIndicator` + `onRefresh` 回调
- 页面滚动时 `SliverAppBar` 自动折叠产生视差效果（Flutter 原生支持）
- AI 伴侣形象区域支持点击互动

### 4.4 对话列表页（ConversationListPage）

**页面布局：**

采用 `ListView.separated` 构建聊天列表：

- **顶部导航栏：** `AppBar` / `CupertinoNavigationBar`，标题"消息" + 右侧搜索图标
- **搜索栏：** 点击搜索图标后展开 `SearchDelegate`，支持模糊搜索聊天记录

**列表项结构（ConversationTile）：**

`ListTile` 或自定义 `Row` 布局：

- **左侧：** AI 伴侣头像（`CircleAvatar`，半径 28dp，使用 `CachedNetworkImage` 缓存），右下角叠加在线状态指示点（`Container`，8dp 圆形，`Colors.green`）
- **中间（Expanded）：** `Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4)`
  - 第 1 行：`Row` — 伴侣名称（`titleMedium`）+ 关系标签（小 `Chip`，性格主题色背景，`labelSmall` 字号）
  - 第 2 行：最后一条消息预览（`bodyMedium`，`onSurfaceVariant` 色，`maxLines: 1`）
- **右侧：** `Column(crossAxisAlignment: CrossAxisAlignment.end, spacing: 4)`
  - 第 1 行：最后消息时间（`labelSmall`，`onSurfaceVariant` 色）
  - 第 2 行：未读消息红点（`Container`，20dp 圆形，`Colors.red`，白色数字，`labelSmall`），无未读时不显示

**列表项交互：**

- 左滑操作：使用 `flutter_slidable` 包的 `Slidable` 组件，配置"置顶"（`SlidableAction`，黄色）和"删除"（`SlidableAction`，红色）
- 点击：`Navigator.push` 跳转至 `ChatPage`

**空状态：**

- 居中 `Column`：Lottie 空状态动画 + "还没有聊天记录"标题 + "去和伴侣打个招呼吧"副标题 + "去聊天" `ElevatedButton`

### 4.5 聊天详情页（ChatPage）— 核心页面

这是应用最核心的页面，承担用户与 AI 伴侣的全部对话交互。

**页面结构：**

`Scaffold` + `Column` 布局：

**区域 1 — 导航栏**

- `AppBar` / `CupertinoNavigationBar`
- 中间：`Column` — 伴侣名称（`titleMedium`）+ 在线状态（`labelSmall`，`green`/`onSurfaceVariant` 色）
- 右侧：更多按钮，点击弹出 `showModalBottomSheet`，选项：清空聊天、伴侣设置、伴侣详情

**区域 2 — 聊天消息列表（Expanded）**

- `ListView.builder` + `reverse: true`（从底部开始渲染，新消息在最下方）
- 使用 `CustomScrollView` + `SliverList` 以支持头部加载更多历史消息
- 消息列表控制器：`ScrollController` 监听滚动位置，滚动至顶部时触发加载更多

**消息气泡组件（MessageBubble）：**

根据消息发送方分为两种样式：

**AI 消息（左对齐）：**

- `Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8)`
- 左侧：`CircleAvatar`（半径 16dp）
- 中间（`Flexible`）：`Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4)`
  - 气泡：`Container` + `BoxDecoration`（性格主题色背景、`ClipPath` 实现左上尖角）
  - 气泡内文字：`Text`，`bodyLarge` 字重，`onSurface` 色
  - 支持混合内容：纯文字、语音消息（`AudioPlayer` 控件）、图片消息（`CachedNetworkImage` 缩略图 + 点击全屏查看）
- 右侧：消息时间（`labelSmall`，`onSurfaceVariant` 色）

**用户消息（右对齐）：**

- `Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, spacing: 8)`
- 左侧：消息状态图标（发送中 `Icons.schedule`、已发送 `Icons.done`、已送达 `Icons.done_all`、已读 `Icons.done_all` 蓝色）+ 消息时间
- 右侧：气泡，品牌色背景 + 白色文字 + 右上尖角

**正在输入指示器：**

- `Row`：AI 头像 + 3 个动态圆点
- 使用 `AnimatedBuilder` + `AnimationController` 实现 3 个圆点依次弹跳动画
- 触发条件：用户发送消息后立即显示，AI 回复第一条消息后消失

**区域 3 — 底部输入栏**

- `Container` + `BoxDecoration`（顶部 1dp 分割线）
- 快捷功能栏：`Row` 水平排列
  - 表情按钮（`Icons.emoji_emotions`）
  - 图片按钮（`Icons.image`），点击调用 `ImagePicker` 选择图片
  - 语音按钮（`Icons.mic`），长按录音（`GestureDetector` + `onLongPressStart` / `onLongPressEnd`）
- 输入区域：`Row(spacing: 8)`
  - 输入框：`TextField` + `InputDecoration`（圆角 20dp、无边框、hintText "输入消息..."），`maxLines: 5`，超过 5 行后内部滚动
  - 发送按钮：`IconButton`（`Icons.arrow_upward_rounded`），品牌色，输入框为空时 `onPressed: null`

**交互细节：**

- 键盘弹出时聊天列表自动滚动至最新消息
- 长按气泡弹出 `showModalBottomSheet`，选项：复制、转发、删除、回复
- 双击气泡触发表情回应（浮动心形动画，`AnimatedPositioned` + `FadeTransition`）
- AI 回复使用打字机效果：逐字显示，通过 `Stream<String>` 控制字符流，`setState` 驱动 UI 更新

### 4.6 伴侣创建页（PartnerCreatePage）

以 `showModalBottomSheet` 形式弹出，使用 `SingleChildScrollView` + `Column` 构建表单：

**表单结构：**

**Section 1 — 伴侣形象**

- 居中 `CircleAvatar`（半径 60dp），使用 `Lottie.asset()` 展示默认微笑表情
- 头像外围：`Container` + `BoxDecoration`（性格主题色渐变圆环，4dp 宽）
- 底部"更换形象" `TextButton`，点击弹出形象选择器（`showModalBottomSheet`），`GridView` 展示预设头像 + AI 生成入口

**Section 2 — 基础信息**

- 伴侣名字：`TextFormField`（hintText "给TA取个名字吧"），`maxLength: 12`
- 性别选择：`SegmentedButton`（Material 3）或 `CupertinoSegmentedControl`（iOS），选项"男 / 女 / 非二元"
- 关系类型：`GridView` 4 列，每张卡片包含图标 + 关系名称 + 简短描述，选中后边框高亮为品牌色

**Section 3 — 性格特征**

- 标签式多选，使用 `Wrap` 组件展示性格标签
- 每个标签：`FilterChip`，未选中为 `surfaceContainerLow` + `onSurfaceVariant` 文字，选中为品牌色背景 + 白色文字 + `Icons.check` 图标
- 最多选择 3 个，超出时最早选中的自动取消

**Section 4 — 高级设置**

- 声音选择：`ListTile` + `DropdownButton`，支持试听按钮
- 说话风格：`ListTile` + `DropdownButton`

**底部操作栏：**

- "创建伴侣" `ElevatedButton` + `StadiumBorder`，品牌色填充
- 按钮状态：所有必填项填写完成后 `onPressed` 非 null，否则 `onPressed: null`
- 创建成功后：Lottie 庆祝动画（心形 + 星星粒子），2 秒后自动跳转至新伴侣的聊天页

### 4.7 记忆相册页（MemoryAlbumPage）

**页面布局：**

`CustomScrollView` + `SliverList` 构建时间线布局：

- **顶部导航：** 标题"我们的回忆" + 右上角筛选按钮
- **时间轴区域：** 按月份分组，每组包含：
  - 月份标题：`Text("2026年6月")`，`titleLarge` 字重，左侧带 4dp 宽的品牌色竖线（`Container(width: 4, decoration: BoxDecoration(color: brandPink, borderRadius: 2))`）
  - 记忆卡片网格：`SliverGrid` 2 列布局

**记忆卡片组件（MemoryCard）：**

- `Container` + `BoxDecoration`（白色背景、16dp 圆角、层级 1 阴影）
- 内部 `Column` 排列：
  - 顶部：情绪图标 + 事件标题（`titleMedium` 字重）
  - 中间：事件描述（`bodyMedium`，`onSurfaceVariant` 色，`maxLines: 3`）
  - 底部：日期文字（`labelSmall`，`onSurfaceVariant` 色）
- 点击：展开详情弹窗（`showModalBottomSheet`），展示完整对话片段 + AI 的"内心独白"

### 4.8 个人中心页（ProfilePage）

**页面布局：**

`ListView` 构建分组列表：

**Section 1 — 用户信息卡片**

- `Row(spacing: 16)` 排列
- 左侧：`CircleAvatar`（半径 32dp，`CachedNetworkImage`）
- 右侧：`Column` — 用户昵称（`titleLarge`）+ 用户 ID（`labelSmall`，`onSurfaceVariant` 色）+ 会员状态标签（`Chip`）

**Section 2 — 数据概览**

- `Row` 等分 3 列，`MainAxisAlignment.spaceEvenly`
  - "已陪伴"：数字 + "天"（`headlineMedium`，品牌色数字）
  - "共对话"：数字 + "条"
  - "记忆"：数字 + "条"

**Section 3 — 会员升级**

- 当用户为免费版时显示
- `Container` + `BoxDecoration`（品牌渐变背景 `LinearGradient`）
- 内容：`Row` — 左侧"✨ 升级会员，解锁无限对话" + 右侧"立即升级" `ElevatedButton`（白色背景，品牌色文字）

**Section 4 — 功能菜单**

- `Column` + `ListTile` 组件：
  - 🧠 记忆管理 → `Navigator.push` → MemoryManagePage
  - 📊 情绪日记 → `Navigator.push` → MoodDiaryPage
  - ⚙️ 设置 → `Navigator.push` → SettingPage
  - 📋 关于我们 → `Navigator.push` → AboutPage
- 每行：左侧图标 + 菜单名称 + 右侧 `Icons.chevron_right`

### 4.9 订阅会员页（SubscriptionPage）

**页面布局：**

`SingleChildScrollView` + `Column`：

**区域 1 — 当前状态**

- `Column` — 当前套餐名称 + 到期时间 + 今日剩余对话数（`LinearProgressIndicator` 可视化已用/总量）

**区域 2 — 套餐选择**

- `Column(spacing: 16)` 垂直排列 3 个套餐卡片
- 每个套餐卡片（`SubscriptionCard`）：
  - `Container` + `BoxDecoration`（白色背景、16dp 圆角、推荐套餐带品牌色边框）
  - `Column` 排列：套餐名称 + 价格（`titleLarge`）+ 权益列表（每行 `Row` — `Icons.check_circle` 绿色 + 权益描述）+ 订阅按钮
  - 推荐套餐右上角带"推荐"标签（品牌渐变背景 + 白色文字，`Positioned` 定位）

**区域 3 — 底部说明**

- 自动续费说明文字（`labelSmall`，`onSurfaceVariant` 色）
- `GestureDetector` + `launchUrl` 跳转《订阅服务协议》

### 4.10 设置页（SettingPage）

`ListView` 构建分组列表：

**Section 1 — 账号与安全**

- `ListTile`：修改密码、绑定邮箱、注销账号（红色文字，点击弹出 `showDialog` 确认）

**Section 2 — 模型配置**

- `ListTile`：当前模型名称（`subtitle`）
- `ListTile`：切换模型（`trailing: Icons.chevron_right`）
- `ListTile`：本地模型地址 `TextField`（`keyboardType: TextInputType.url`）

**Section 3 — 通知设置**

- `SwitchListTile`：消息通知
- `SwitchListTile`：主动关心（下方附说明文字）

**Section 4 — 通用**

- `ListTile`：深色模式（`DropdownButton` 或 `showModalBottomSheet` 选择"跟随系统 / 浅色 / 深色"）
- `ListTile`：语言
- `ListTile`：字体大小（`Slider`）

**Section 5 — 退出登录**

- 居中红色文字 `TextButton`（"退出登录"），点击弹出 `showDialog` 确认

---

## 5. 组件规范

### 5.1 按钮系统

| 按钮类型              | 样式描述           | Flutter 实现                                                                                                                                   |
| ----------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Primary（主按钮）      | 品牌色填充胶囊形，白色文字  | `ElevatedButton` + `style: ElevatedButton.styleFrom(backgroundColor: brandPink, foregroundColor: white, shape: StadiumBorder())`             |
| Secondary（次按钮）    | 品牌色描边胶囊形，品牌色文字 | `OutlinedButton` + `style: OutlinedButton.styleFrom(foregroundColor: brandPink, side: BorderSide(color: brandPink), shape: StadiumBorder())` |
| Text（文字按钮）        | 无边框，品牌色文字      | `TextButton` + `style: TextButton.styleFrom(foregroundColor: brandPink)`                                                                     |
| Icon（图标按钮）        | 圆形背景 + 图标      | `IconButton` + `style: IconButton.styleFrom(backgroundColor: surfaceContainerLow)`                                                           |
| Destructive（危险按钮） | 红色填充或描边        | `ElevatedButton.styleFrom(backgroundColor: Colors.red)`                                                                                      |
| Disabled（禁用态）     | 灰色填充，60% 不透明度  | `onPressed: null`（自动应用 disabled 样式）                                                                                                          |

### 5.2 输入框系统

| 输入框类型 | 样式描述             | Flutter 实现                                                                                                                 |
| ----- | ---------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 文本输入  | 胶囊形背景，内边距 12dp   | `TextField` + `InputDecoration(fill: true, fillColor: surfaceContainerLow, border: OutlineInputBorder(borderRadius: 999))` |
| 搜索框   | 系统搜索栏            | `SearchBar` (Material 3) 或 `CupertinoSearchTextField` (iOS)                                                                |
| 聊天输入  | 圆角矩形，自适应高度（1-5行） | `TextField(maxLines: 5)` + `OutlineInputBorder(borderRadius: 20)`                                                          |
| 安全输入  | 带显示/隐藏切换的密码框     | `TextField(obscureText: true)` + 右侧 `IconButton` 切换                                                                        |

### 5.3 卡片系统

| 卡片类型     | 样式描述                   | Flutter 实现                                                                          |
| -------- | ---------------------- | ----------------------------------------------------------------------------------- |
| 内容卡片     | 白色背景，16dp 圆角，层级 1 阴影   | `Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: 16))` + `BoxShadow` |
| 对话气泡（AI） | 性格主题色背景，18dp 圆角 + 左上尖角 | `ClipPath` + 自定义 `CustomClipper<Path>`                                              |
| 对话气泡（用户） | 品牌色背景，18dp 圆角 + 右上尖角   | `ClipPath` + 自定义 `CustomClipper<Path>`                                              |
| 功能入口     | 白色背景 + 图标 + 文字         | `Card` + `Column(icon, text)`                                                       |
| 渐变卡片     | 品牌渐变背景，白色文字            | `Container` + `BoxDecoration(gradient: LinearGradient(...))`                        |

### 5.4 弹窗与提示

| 弹窗类型     | 用途        | Flutter 实现                                                           |
| -------- | --------- | -------------------------------------------------------------------- |
| 确认弹窗     | 删除确认、退出确认 | `showCupertinoDialog` (iOS) / `showDialog` (Android) + `AlertDialog` |
| 操作菜单     | 更多操作选项    | `showModalBottomSheet` + `ListView` of `ListTile`                    |
| 底部弹窗     | 选择器、详情展示  | `showModalBottomSheet` + `SafeArea`                                  |
| 全屏覆盖     | 语音通话、图片查看 | `Navigator.push` + `fullscreenDialog: true`                          |
| Toast 提示 | 操作反馈、状态提示 | 自定义 `OverlayEntry`，使用 `AnimatedPositioned` 实现滑入/滑出                   |
| Snackbar | 带操作的提示条   | `ScaffoldMessenger.showSnackBar` + `SnackBar`                        |

### 5.5 加载状态

| 状态     | 样式描述                                   | Flutter 实现                                                                           |
| ------ | -------------------------------------- | ------------------------------------------------------------------------------------ |
| 全屏加载   | 居中 `CircularProgressIndicator` + 半透明遮罩 | `Stack` + `Container(color: black38)` + `Center(child: CircularProgressIndicator())` |
| 下拉刷新   | 系统原生刷新控件                               | `RefreshIndicator` + `onRefresh: () async`                                           |
| 列表加载更多 | 底部 `CircularProgressIndicator`         | `ListView` 末尾 `SizedBox` + `CircularProgressIndicator` + `onEndReached`              |
| 骨架屏    | 灰色占位块，带波纹动画                            | `Shimmer` 包 + `Shimmer.fromColors` 实现渐变波纹                                            |

---

## 6. 交互与动效规范

### 6.1 动画系统

使用 **flutter_animate** 包 + Flutter 原生动画 API：

| 交互场景        | 动画效果                | 实现方式                                                         | 时长        |
| ----------- | ------------------- | ------------------------------------------------------------ | --------- |
| 页面切换        | iOS：右滑推入；Android：淡入 | `CupertinoPageRoute` / `MaterialPageRoute`                   | 系统默认      |
| Tab 切换      | 系统默认                | `BottomNavigationBar` / `CupertinoTabBar`                    | 系统默认      |
| 弹窗弹出        | 底部滑入 + 背景渐暗         | `showModalBottomSheet` 原生                                    | 系统默认      |
| 按钮点击        | 缩放 0.95 → 1.0 回弹    | `flutter_animate` + `ScaleEffect(curve: Curves.easeOutBack)` | 200ms     |
| 消息气泡出现      | 从底部淡入 + 缩放          | `flutter_animate` + `SlideEffect` + `FadeEffect`             | 300ms     |
| AI 正在输入     | 3 个圆点依次弹跳           | `AnimatedBuilder` + 3 个 `AnimationController` 错开             | 600ms 循环  |
| 表情切换        | 淡入淡出交叉溶解            | `AnimatedSwitcher` + `FadeTransition`                        | 400ms     |
| 未读红点出现      | 缩放 0 → 1.2 → 1.0    | `ScaleTransition` + `CurvedAnimation`                        | 300ms     |
| Toast 出现/消失 | 顶部滑入/滑出             | `AnimatedPositioned` + `Opacity`                             | 250ms     |
| 骨架屏波纹       | 渐变从左到右移动            | `Shimmer` 包                                                  | 1500ms 循环 |
| 表情回应（双击）    | 心形弹出上浮消失            | `AnimatedPositioned` + `FadeTransition`                      | 800ms     |

### 6.2 手势系统

| 手势  | 触发场景   | 行为        | Flutter 实现                                                 |
| --- | ------ | --------- | ---------------------------------------------------------- |
| 左滑  | 聊天列表项  | 显示置顶/删除操作 | `flutter_slidable` 包的 `Slidable`                           |
| 右滑  | 聊天详情页  | 返回上一页     | `CupertinoPageRoute` 原生支持                                  |
| 下拉  | 首页     | 刷新伴侣状态    | `RefreshIndicator`                                         |
| 长按  | 聊天气泡   | 弹出上下文菜单   | `GestureDetector` + `onLongPress` → `showModalBottomSheet` |
| 双击  | 聊天气泡   | 快捷表情回应    | `GestureDetector` + `onDoubleTap`                          |
| 拖拽  | 语音录制按钮 | 上滑取消录制    | `GestureDetector` + `onPanUpdate`                          |

### 6.3 反馈机制

| 用户操作   | 反馈方式                | Flutter 实现                       |
| ------ | ------------------- | -------------------------------- |
| 发送消息   | 气泡弹入动画 + 已发送对勾      | `AnimatedList` + 图标切换            |
| AI 回复中 | "正在输入..."指示器        | 3 个 `AnimatedBuilder` 圆点         |
| 语音录制中  | 音波动画                | `AnimatedContainer` + 脉冲动画       |
| 购买成功   | Lottie 庆祝动画 + Toast | `Lottie.asset()` + 自定义 Toast     |
| 操作失败   | 红色 Toast + 重试按钮     | 自定义 Toast + `SnackBar`           |
| 网络断开   | 顶部红色横幅              | `AnimatedContainer` + `SafeArea` |
| 复制成功   | Toast "已复制"         | 自动 2 秒后消失的 Toast                 |
| 删除确认   | 弹窗 + 红色确认按钮         | `showDialog` + `TextButton` 红色   |

---

## 7. 适配与无障碍规范

### 7.1 屏幕适配

| 设备类型        | 适配策略    | Flutter 实现                              |
| ----------- | ------- | --------------------------------------- |
| 标准手机（≤6.7寸） | 基准设计    | `MediaQuery.of(context).size` 自适应       |
| 大屏手机（>6.7寸） | 等比适配    | `LayoutBuilder` + `BoxConstraints`      |
| 平板          | 左右分栏    | `LayoutBuilder` 判断宽度 > 600dp 时使用双栏布局    |
| 折叠屏         | 类平板分栏   | `MediaQuery` + `displayFeatures` 检测折叠状态 |
| 横屏          | 聊天页支持横屏 | `OrientationBuilder` + 布局切换             |

### 7.2 安全区域适配

```dart
// 顶部 + 底部安全区域
SafeArea(
  child: Scaffold(
    body: ...
  ),
)

// 仅底部安全区域（沉浸式状态栏）
SafeArea(
  top: false,
  child: ...
)

// 键盘适配
Scaffold(
  resizeToAvoidBottomInset: true,  // 默认 true
  body: ...
)
```

### 7.3 无障碍支持

| 无障碍功能 | Flutter 实现                                         |
| ----- | -------------------------------------------------- |
| 屏幕阅读器 | `Semantics` widget + `label` / `hint` 属性           |
| 大字体模式 | 使用 `Theme.of(context).textTheme` 自动适配系统字体大小        |
| 增强对比度 | `MediaQuery.of(context).highContrast` 检测，切换高对比度主题  |
| 减少动效  | `MediaQuery.of(context).disableAnimations` 检测，跳过动画 |
| 色盲友好  | 不仅依赖颜色传达信息，始终配合图标/文字辅助                             |

---

## 8. 第三方库清单（UI 相关）

通过 **pub** 集成：

| 库名                        | 用途                   | 说明                                |
| ------------------------- | -------------------- | --------------------------------- |
| **lottie**                | AI 伴侣表情动画、空状态动画、庆祝动画 | Lottie 官方 Flutter 实现              |
| **cached_network_image**  | 图片异步加载与缓存            | 头像、图片消息                           |
| **flutter_animate**       | 声明式动画库               | 链式动画 API，fade/slide/scale/blur 组合 |
| **flutter_slidable**      | 列表滑动操作               | 聊天列表左滑置顶/删除                       |
| **shimmer**               | 骨架屏加载效果              | 列表加载占位                            |
| **photo_view**            | 图片查看器                | 全屏查看，支持双指缩放                       |
| **smooth_page_indicator** | 页面指示器                | 引导页圆点指示器                          |
| **flutter_markdown**      | Markdown 渲染          | AI 回复中的富文本内容                      |
| **google_fonts**          | 字体管理                 | Noto Sans SC 等字体                  |
| **image_picker**          | 图片/相机选择              | 从相册选择或拍照                          |
| **emoji_picker_flutter**  | 表情选择器                | 聊天输入框的表情键盘                        |

> **不引入的库及原因：**
> 
> - **GetX：** 隐式依赖注入，不利于测试和维护
> - **shared_preferences 的替代品如 get_storage：** shared_preferences 已足够，且官方维护
> - **url_launcher 的替代品：** url_launcher 是 Flutter 官方推荐

---

## 9. 设计资源交付清单

| 资源类型        | 格式                   | 说明                           |
| ----------- | -------------------- | ---------------------------- |
| AI 伴侣形象插画   | SVG + Lottie JSON    | 8 种基础表情 × 5 种性格主题 = 40 个动画文件 |
| 空状态插画       | SVG                  | 各页面空状态插画                     |
| 引导页插画       | SVG                  | 3 张引导页全屏插画                   |
| 品牌 Logo     | SVG + PNG (1x/2x/3x) | 多分辨率适配                       |
| 色板文件        | Dart 常量文件            | `colors.dart` 定义所有品牌色和语义色    |
| Lottie 动画规范 | JSON + 文档            | 帧率 30fps，文件大小控制在 200KB 以内    |

---


