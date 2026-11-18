# 酒馆 App · Flutter UI 设计稿

本地优先的 SillyTavern 客户端 UI 原型，iOS 26 液态玻璃风格，**不含群聊**。

## 预览

```bash
flutter pub get
flutter run -d chrome
```

直接打开某一屏（仅 Web 预览支持）：

```
http://localhost:8099/?screen=home
http://localhost:8099/?screen=chat
http://localhost:8099/?screen=character
http://localhost:8099/?screen=settings
```

可选参数：

| 参数 | 值 | 说明 |
|---|---|---|
| `screen` | `home` `chats` `chat` `chat&demo=1` `chatmenu` `character` `editor` `chatinfo` `persona` `regex` `quickreply` `promptedit` `authornote` `prompts` `presets` `generation` `connection` `memory` `media` `interaction` `automation` `appearance` `data` `stats` `about` `search` `lore` `loreentry` `connect` `import` `settings` | 直接进入某屏 |
| `theme` | `light` | 浅色主题 |
| `insets` | `0` | 关闭 iPhone 安全区与状态栏模拟 |

## 屏幕

- `home` 角色库：继续上次、搜索、筛选、角色网格
- `chats` 对话列表：置顶 / 最近、左滑管理
- `chat` 聊天：真实输入、流式生成、停止、滑动切换、长按菜单、继续/重写
- `persona` `regex` `quickreply` `promptedit` `authornote`：五个二级编辑页
- `character` 角色详情：立绘、统计、开始新对话
- `lore` 世界书列表；`loreentry` 条目编辑 Sheet
- `settings` 设置：模型 / 外观 / 数据
- `connect` 模型连接 Sheet；`import` 导入角色 Sheet

## 结构

```
lib/
├─ main.dart          # 入口、路由、Tab Shell、Web 预览壳
├─ data/demo.dart     # 演示数据
├─ design/
│  ├─ theme.dart      # 色板、字体、Aurora 背景
│  ├─ glass.dart      # 玻璃组件库
│  └─ scaffold.dart   # 页面骨架、Sheet、SettingRow
└─ screens/           # 各页面
```

## iOS

`ios/` 已由 `flutter create` 生成，需在 macOS + Xcode 上构建：

```bash
flutter build ios --release
```

设计说明、设计 Token、iOS 26 `UIGlassEffect` 接入建议见仓库根目录的
[酒馆-App-UI设计说明.md](../酒馆-App-UI设计说明.md)。
