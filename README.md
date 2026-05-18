<p align="center">
  <a href="README_EN.md">English</a> | <strong>中文</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Node.js-18+-339933?style=flat-square&logo=node.js" alt="Node.js">
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white" alt="MySQL">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Version-Beta%200.0.6-red?style=flat-square" alt="Version">
</p>

<h1 align="center">留笔 Liubi</h1>

<p align="center"><strong>标记我的生活</strong></p>

<p align="center">一款类似小红书的社交社区应用，支持图文发布、实时聊天、AI助手、分类社区等功能。<br>采用 Flutter + Node.js + MySQL 前后端分离架构，WebSocket 实时通信。</p>

---

## 目录

- [核心功能](#核心功能)
- [界面一览](#界面一览)
- [技术架构](#技术架构)
- [项目结构](#项目结构)
- [数据库设计](#数据库设计)
- [UI设计风格](#ui设计风格)
- [快速开始](#快速开始)
- [API概览](#api概览)
- [部署](#部署)

---

## 核心功能

### 📝 内容创作
- **块编辑器**：支持文字、图片、语音、链接四种内容块自由组合
- **图文帖子**：瀑布流展示，支持多图上传、宽高比自适应、长图优化
- **纯文字帖**：卡片式文字模板，支持内嵌链接卡片
- **语音帖子**：内置录音功能，播放进度条
- **话题标签**：`#话题#` 自动识别与提取
- **链接识别**：文本中 URL 自动识别，红色下划线可点击，调用内置浏览器
- **私密发布**：帖子可设为私密，仅自己可见

### 💬 社交互动
- **点赞/收藏**：弹跳动画特效，实时计数更新
- **评论系统**：楼中楼嵌套回复，评论点赞动画，图片评论
- **@提及**：评论中 `@用户名` 自动补全，发送通知
- **关注体系**：关注/粉丝双向关系，互关/回关/已关注状态，隐私控制
- **分类社区**：贴吧风格分类，关注/发帖/置顶/热门

### 📡 实时通讯
- **私聊**：WebSocket 实时消息，文字/图片消息
- **群聊**：群号加入，群成员管理
- **消息撤回**：2分钟内可撤回
- **会话管理**：置顶/标为已读/删除，即时生效
- **系统通知**：后台运行时弹出系统通知栏消息，点击跳转对应页面
- **心跳保活**：30秒心跳，自动重连（递增延迟，最多10次）

### 🤖 AI助手
- **DeepSeek集成**：流式输出，实时对话
- **Markdown渲染**：Mac风格代码块（Catppuccin Mocha暗色主题），复制按钮
- **聊天历史**：本地持久化

### 🔧 管理后台
- **8大模块**：统计/用户/帖子/评论/分类/会话/邮箱配置/AI配置
- **用户管理**：禁用/禁言/角色切换
- **内容审核**：帖子下架/评论删除/分类管理
- **版本管理**：发布新版本，强制更新控制

---

## 界面一览

### 主要界面（26个）

| 界面 | 文件 | 功能说明 |
|------|------|----------|
| 主框架 | `main_screen.dart` | 底部4Tab导航（首页/发现/消息/我的），WebSocket生命周期管理 |
| 首页 | `home_screen.dart` | 分类Tab切换 + 瀑布流帖子列表，下拉刷新/上拉加载/回到顶部 |
| 发现页 | `discover_screen.dart` | 热门帖子、推荐用户、在线人数、分类入口、数据统计 |
| 消息页 | `message_screen.dart` | 聊天会话列表，长按浮动菜单（置顶/已读/删除），未读角标 |
| 我的 | `mine_screen.dart` | 小红书风格个人信息页，折叠顶栏，帖子/收藏/赞过/动态四Tab |
| 发布页 | `publish_screen.dart` | 块编辑器，文字/图片/语音/链接块，录音、话题标签 |
| 详情页 | `detail_screen.dart` | 帖子内容、图片预览(保存)、语音播放、评论列表(楼中楼)、点赞/收藏/分享、互关/回关状态 |
| 聊天页 | `chat_screen.dart` | 私聊/群聊，消息撤回，本地缓存(200条/会话) |
| 登录页 | `login_screen.dart` | 密码登录、验证码登录、邮箱注册，原生加载指示器 |
| 搜索页 | `search_screen.dart` | 搜索帖子/用户，热门关键词，搜索历史 |
| AI聊天 | `ai_chat_screen.dart` | DeepSeek对话，流式输出，Mac风格代码块 |
| 分类详情 | `category_screen.dart` | 贴吧风格，分类信息/关注/最新/热门/赞过/置顶帖 |
| 他人主页 | `user_profile_screen.dart` | 小红书风格用户主页，折叠顶栏，互关/回关/已关注状态，隐私保护，动态Tab |
| 编辑资料 | `edit_profile_screen.dart` | 头像/背景图/昵称/简介/性别/生日(中式)/地区 |
| 通知列表 | `notification_list_screen.dart` | 赞/评论/关注/系统 分Tab展示 |
| 设置页 | `settings_screen.dart` | 缓存清理、版本更新、关于、退出登录 |
| 隐私设置 | `privacy_settings_screen.dart` | 关注/粉丝/获赞与收藏/动态列表隐私，修改用户名/邮箱(验证码)/密码 |
| 通知设置 | `notification_settings_screen.dart` | 推送/赞/评论/关注/收藏/聊天 通知开关 |
| 内置浏览器 | `in_app_browser_screen.dart` | WebView，顶栏导航，更多菜单(复制链接/浏览器打开/刷新) |
| 图片查看器 | `image_viewer_screen.dart` | 全屏查看，左右滑动，长按保存(小红书风格弹窗) |
| 管理后台 | `admin_screen.dart` | 8Tab管理面板，仅管理员可用 |
| 热门榜单 | `trending_screen.dart` | 热门/最新两个Tab |
| 关于页 | `about_screen.dart` | 应用版本信息，用户协议/隐私政策(内置浏览器) |
| 关注/粉丝 | `follow_list_screen.dart` | 关注列表/粉丝列表 |
| 推荐用户 | `recommend_users_screen.dart` | 系统推荐用户 |
| 动态页 | `activity_feed_screen.dart` | 用户活动流 |

---

## 技术架构

```
┌─────────────────────────────────────────────────────┐
│                    Flutter 前端                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │ Screens  │ │Providers │ │ Services │ │ Widgets │ │
│  │  (26个)  │ │  (2个)   │ │  (5个)   │ │ (11个)  │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────────┘ │
│       │            │            │                     │
│  ┌────┴────────────┴────────────┴─────┐              │
│  │           Models (6个)              │              │
│  └────────────────────────────────────┘              │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Dio) / WebSocket
┌──────────────────────┴──────────────────────────────┐
│                   Node.js 后端                        │
│  ┌──────────────────────────────────────────────┐    │
│  │  Express + WebSocket (ws)                    │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │    │
│  │  │ Routes │ │Middleware│ │ Utils │           │    │
│  │  │ (13个) │ │  (JWT)  │ │(邮件等)│           │    │
│  │  └───┬────┘ └────────┘ └────────┘           │    │
│  └──────┼───────────────────────────────────────┘    │
│         │                                            │
│  ┌──────┴───────────────────────────────────────┐    │
│  │            MySQL 数据库 (20张表)              │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

### 前端技术栈

| 技术 | 用途 |
|------|------|
| **Flutter 3.11+** | 跨平台UI框架，Material 3 |
| **Provider** | 状态管理（PostProvider + UserProvider） |
| **Dio** | HTTP网络请求，JWT自动注入 |
| **web_socket_channel** | WebSocket实时通信 |
| **cached_network_image** | 图片缓存加载 |
| **flutter_staggered_grid_view** | 瀑布流布局 |
| **flutter_markdown** | Markdown渲染（AI对话） |
| **webview_flutter** | 内置浏览器 |
| **flutter_local_notifications** | 系统通知推送 |
| **record / audioplayers** | 录音/音频播放 |
| **photo_view** | 图片缩放查看 |
| **image_picker / file_picker** | 图片/文件选择 |
| **gal** | 保存图片到相册 |
| **shared_preferences** | 本地键值存储 |
| **permission_handler** | 权限管理 |
| **Impeller** | Android渲染引擎（已启用） |

### 后端技术栈

| 技术 | 用途 |
|------|------|
| **Express 4** | Web框架 |
| **MySQL2** | MySQL数据库驱动（Promise API） |
| **ws** | WebSocket服务 |
| **jsonwebtoken** | JWT认证 |
| **bcryptjs** | 密码加密 |
| **multer** | 文件上传 |
| **nodemailer** | 邮件发送（验证码） |
| **cors** | 跨域支持 |
| **dotenv** | 环境变量 |

---

## 项目结构

```
liubi/
├── liubi_app/                        # Flutter 前端
│   ├── lib/
│   │   ├── main.dart                 # 入口：路由、主题、Provider注册
│   │   ├── screens/                  # 界面层 (26个)
│   │   │   ├── main_screen.dart      # 主框架(4Tab)
│   │   │   ├── home_screen.dart      # 首页(瀑布流)
│   │   │   ├── discover_screen.dart  # 发现页
│   │   │   ├── message_screen.dart   # 消息页
│   │   │   ├── mine_screen.dart      # 我的
│   │   │   ├── publish_screen.dart   # 发布(块编辑器)
│   │   │   ├── detail_screen.dart    # 帖子详情
│   │   │   ├── chat_screen.dart      # 聊天
│   │   │   ├── login_screen.dart     # 登录/注册
│   │   │   ├── ai_chat_screen.dart   # AI助手
│   │   │   ├── admin_screen.dart     # 管理后台
│   │   │   └── ...                   # 其他界面
│   │   ├── providers/                # 状态管理
│   │   │   ├── post_provider.dart    # 帖子状态
│   │   │   └── user_provider.dart    # 用户状态
│   │   ├── models/                   # 数据模型 (6个)
│   │   ├── services/                 # 服务层 (5个)
│   │   │   ├── api_service.dart      # HTTP客户端(Dio)
│   │   │   ├── chat_service.dart     # WebSocket服务
│   │   │   ├── storage_service.dart  # 本地存储
│   │   │   ├── notification_service.dart # 系统通知
│   │   │   └── update_service.dart   # 版本更新
│   │   ├── widgets/                  # 通用组件 (11个)
│   │   └── utils/                    # 工具类
│   ├── android/                      # Android原生配置
│   └── pubspec.yaml                  # 依赖配置
│
├── server/                           # Node.js 后端
│   ├── server.js                     # 入口：Express+WebSocket+自动建表
│   ├── routes/                       # API路由 (13个)
│   │   ├── auth.js                   # 认证(注册/登录/验证码)
│   │   ├── posts.js                  # 帖子(CRUD/点赞/收藏/搜索)
│   │   ├── comments.js               # 评论(楼中楼/点赞)
│   │   ├── users.js                  # 用户(资料/关注/隐私)
│   │   ├── categories.js             # 分类(社区/关注)
│   │   ├── chat.js                   # 聊天(私聊/群聊/撤回)
│   │   ├── messages.js               # 消息通知
│   │   ├── notifications.js          # 通知(未读统计)
│   │   ├── upload.js                 # 文件上传
│   │   ├── ai.js                     # AI对话(DeepSeek)
│   │   ├── version.js                # 版本管理
│   │   ├── admin.js                  # 管理后台
│   │   └── stats.js                  # 统计(在线/总览)
│   ├── config/                       # 数据库/环境配置
│   ├── middleware/                    # JWT认证中间件
│   ├── utils/                        # 工具(邮件/IP/WS)
│   └── package.json                  # 依赖配置
│
└── liubi-release.jks                 # Android签名证书(已排除)
```

---

## 数据库设计

共 **20张表**，分为6大体系：

### 用户体系
| 表名 | 说明 |
|------|------|
| `users` | 用户表（昵称/头像/简介/性别/生日/地区/角色/隐私设置） |
| `follows` | 关注关系表（follower_id + following_id 联合唯一） |
| `verify_codes` | 验证码表（邮箱/验证码/类型/过期时间5分钟） |

### 内容体系
| 表名 | 说明 |
|------|------|
| `posts` | 帖子表（标题/内容/分类/类型/语音/链接/内容块JSON/私密标记） |
| `post_images` | 帖子图片表（URL/媒体类型/宽高比/排序） |
| `comments` | 评论表（楼中楼parent_id/图片/点赞数/置顶） |
| `categories` | 分类表（名称/图标/描述/热度/关注数/发帖限制） |
| `category_follows` | 分类关注表 |

### 互动体系
| 表名 | 说明 |
|------|------|
| `likes` | 点赞表（帖子/评论联合，user+target+type唯一） |
| `collects` | 收藏表 |
| `messages` | 消息通知表（赞/评论/关注/系统/@提及/收藏/聊天） |
| `activities` | 活动流表（发布/赞/评论/收藏/关注） |
| `mentions` | @提及表 |

### 聊天体系
| 表名 | 说明 |
|------|------|
| `chat_conversations` | 会话表（私聊/群聊/群号） |
| `chat_members` | 成员表（置顶/隐藏标记） |
| `chat_messages` | 消息表（文本/图片/系统消息/撤回标记） |

### 其他
| 表名 | 说明 |
|------|------|
| `search_logs` | 搜索日志 |
| `ai_config` | AI配置（API地址/密钥/模型/提示词） |
| `ai_chat_history` | AI聊天历史 |
| `app_versions` | 版本管理（版本号/下载地址/强制更新/更新内容） |

---

## UI设计风格

### 设计语言
- **主色调**：`#FF2442`（活力红），贯穿点赞、收藏、发布按钮、加载指示器
- **背景色**：`#FFFFFF` 白色为主，`#F5F7FA` 浅灰辅助
- **文字色**：`#222222` 标题 / `#333333` 正文 / `#999999` 辅助
- **圆角**：统一 `12px` 大圆角 / `8px` 小圆角
- **阴影**：柔和投影 `blurRadius: 16, offset: (0, 4), alpha: 0.12`

### 交互特色
| 特性 | 实现方式 |
|------|----------|
| 瀑布流 | `flutter_staggered_grid_view`，宽高比自适应 |
| 骨架屏 | Shimmer加载占位，分类切换时先显示骨架再加载内容 |
| 弹跳动画 | 点赞/收藏 `ScaleTransition`，overshoot弹跳曲线 |
| 页面转场 | `CupertinoPageTransitionsBuilder`，iOS风格滑动 |
| 下拉刷新 | `CupertinoSliverRefreshControl`，原生风格 |
| 长按菜单 | 自定义 `OverlayEntry` 浮动白色圆角菜单（微信风格） |
| 图片保存 | 小红书风格底部弹窗 + 系统Toast |
| 代码块 | Mac风格三色点 + Catppuccin Mocha暗色主题 + 复制按钮 |
| 加载指示 | `CupertinoActivityIndicator`，原生系统风格 |
| 文本选择 | `SelectableText` + 自定义复制回调（复制后Toast提示"已复制"） |
| 系统通知 | 双通道（社区通知 + 聊天消息），点击跳转对应页面 |

### 适配
- **OPPO字体**：`fontFamily: null` + `Typography.blackCupertino` + `letterSpacing: 0`
- **Impeller引擎**：Android端启用，提升渲染性能
- **弹性滚动**：全局 `BouncingScrollPhysics`，iOS风格回弹

---

## 快速开始

### 环境要求

- Flutter SDK 3.11+
- Node.js 18+
- MySQL 8.0+
- Android SDK (minSdk 24, targetSdk 36)

### 后端启动

```bash
cd server
npm install
cp .env.example .env    # 配置数据库和邮件
node server.js           # 自动建表+启动服务
```

`.env` 配置项：
```
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=liubi
JWT_SECRET=your_jwt_secret
MAIL_HOST=smtp.qq.com
MAIL_USER=your_email@qq.com
MAIL_PASS=your_smtp_password
```

### 前端启动

```bash
cd liubi_app
flutter pub get
flutter run
```

API地址配置在 `lib/services/api_service.dart` 中的 `baseUrl`。

### 编译签名APK

```bash
cd liubi_app
flutter build apk --release
```

输出路径：`build/app/outputs/flutter-apk/app-release.apk`

---

## API概览

| 模块 | 前缀 | 端点数 | 核心功能 |
|------|------|--------|----------|
| 认证 | `/api/auth` | 10 | 注册/登录/验证码/修改资料/密码/邮箱 |
| 帖子 | `/api/posts` | 11 | CRUD/点赞/收藏/搜索/热门/置顶/私密 |
| 评论 | `/api/comments` | 5 | 发表/删除/点赞/置顶 |
| 用户 | `/api/users` | 12 | 资料/关注/帖子/粉丝/动态/隐私 |
| 分类 | `/api/categories` | 4 | 列表/详情/关注/帖子 |
| 聊天 | `/api/chat` | 14 | 会话/消息/撤回/已读/置顶/群管理 |
| 通知 | `/api/notifications` | 4 | 列表/未读/已读 |
| 上传 | `/api/upload` | 2 | 单文件/多文件 |
| AI | `/api/ai` | 3 | 对话/历史/清空 |
| 版本 | `/api/version` | 5 | 检查更新/CRUD |
| 管理 | `/api/admin` | 20+ | 统计/用户/帖子/分类/配置管理 |
| 统计 | `/api/stats` | 2 | 在线人数/总览 |
| WebSocket | `/ws` | - | 实时聊天/通知推送/心跳/在线广播 |

---

## 部署

### 服务器部署

```bash
# 上传代码到服务器
scp -r server/ root@your_server:/www/wwwroot/liubi/server/

# 安装依赖并启动
cd /www/wwwroot/liubi/server
npm install
pm2 start server.js --name liubi
pm2 save
```

### 热度算法

```
帖子热度 = views×1 + likes×5 + collects×3 + comments×2
分类热度 = views×0.1 + likes×3 + comments×2 + collects×1.5
```

---

## 版本历史

| 版本 | 构建号 | 说明 |
|------|--------|------|
| Beta 0.0.6 | 105 | 表情消息支持、Live Photo支持、分类页优化、语音消息显示优化、AI聊天键盘遮挡修复 |

---

<p align="center">
  留笔 Liubi &copy; 2026 - 标记我的生活
</p>
