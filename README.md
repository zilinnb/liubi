<p align="center">
  <a href="README_EN.md">English</a> | <strong>中文</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Node.js-18+-339933?style=flat-square&logo=node.js" alt="Node.js">
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white" alt="MySQL">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Version-Beta%200.0.8-red?style=flat-square" alt="Version">
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

### 💰 留币系统
- **签到领币**：每日签到获取留币，连续签到奖励递增
- **红包系统**：发帖时可附带红包，其他用户抢红包获取留币
- **赞赏功能**：对帖子进行留币赞赏，支持自定义金额
- **交易记录**：完整的收支明细，余额/总赚/总花统计
- **留币配置**：管理员可配置签到基础奖励、最大奖励、经验奖励等

### 🏆 等级系统
- **12级等级**：从"初来乍到"到"返璞归真"，葫芦侠风格等级体系
- **经验获取**：签到/发帖/评论/被赞/被收藏等行为获取经验值
- **等级徽章**：全场景展示等级徽章（帖子卡片/评论/聊天/个人主页/发现页）
- **等级颜色**：1-3级灰色/4-6级蓝色/7-9级紫色/10-12级金色
- **经验进度条**：个人主页展示升级进度，显示当前/下一级所需经验
- **分类等级限制**：分类可设置最低发帖等级要求，低等级用户无法发布

### 💬 社交互动
- **点赞/收藏**：弹跳动画特效，实时计数更新
- **评论系统**：楼中楼嵌套回复，评论点赞动画，图片评论
- **@提及**：评论中 `@用户名` 自动补全，发送通知
- **关注体系**：关注/粉丝双向关系，互关/回关/已关注状态，隐私控制
- **分类社区**：贴吧风格分类，关注/发帖/置顶/热门
- **密码找回**：通过邮箱验证码重置密码，5分钟有效期

### 📡 实时通讯
- **私聊**：WebSocket 实时消息，文字/图片消息
- **群聊**：群号加入，群成员管理
- **语音录制**：微信风格声波动画，上滑取消发送
- **会话管理**：置顶/标为已读/删除，即时生效
- **系统通知**：后台运行时弹出系统通知栏消息，点击跳转对应页面
- **心跳保活**：30秒心跳，自动重连（递增延迟，最多10次）

### 🤖 AI助手
- **DeepSeek集成**：流式输出，实时对话
- **Markdown渲染**：Mac风格代码块（Catppuccin Mocha暗色主题），复制按钮
- **聊天历史**：本地持久化

### 🔧 管理后台（独立SPA）
- **技术栈**：Vue 3 + Vite + Element Plus + ECharts + Pinia
- **独立部署**：`/admin`路径访问，Vite开发代理到后端3000端口
- **10大模块**：
  - **仪表盘**：总用户/总帖子/总评论/今日新增统计卡片（数字滚动动画），注册趋势折线图（ECharts，30秒自动刷新），系统信息面板（Node版本/数据库状态/在线人数/运行时长）
  - **用户管理**：搜索/角色筛选/状态筛选，编辑资料，禁用/启用，禁言（快捷时间：1h/6h/1d/7d/30d），留币/等级展示
  - **帖子管理**：Tab筛选（全部/正常/待审核/已下架），审核通过/下架/恢复/删除，帖子详情抽屉
  - **评论管理**：评论列表，帖子标题关联，删除操作
  - **分类管理**：CRUD，图标/封面/颜色/排序/状态/发帖等级限制
  - **会话管理**：私聊/群聊筛选，编辑群聊号，删除会话
  - **留币管理**：用户留币/等级/经验搜索，调整留币（正增负减+说明），调整经验值，等级配置表，签到配置（在线修改奖励参数）
  - **AI配置**：AI对话配置（API地址/Key/模型/提示词/启用开关），AI绘画配置（API地址/Key/模型/启用开关）
  - **版本管理**：发布/编辑/删除版本，平台选择（Android/iOS/全平台），更新类型（功能/Bug/安全），强制更新开关
  - **系统设置**：邮件SMTP配置（数据库存储，在线修改），测试发送邮件
- **安全**：JWT认证，路由守卫，401自动跳转登录
- **UI**：侧边栏可折叠，主题色`#FF2442`，圆角卡片，响应式布局

---

## 界面一览

### 主要界面（27个）

| 界面 | 文件 | 功能说明 |
|------|------|----------|
| 主框架 | `main_screen.dart` | 底部4Tab导航（首页/发现/消息/我的），WebSocket生命周期管理 |
| 首页 | `home_screen.dart` | 分类Tab切换 + 瀑布流帖子列表，下拉刷新/上拉加载/回到顶部 |
| 发现页 | `discover_screen.dart` | 热门帖子、推荐用户、在线人数、分类入口、数据统计 |
| 消息页 | `message_screen.dart` | 聊天会话列表，长按浮动菜单（置顶/已读/删除），未读角标 |
| 我的 | `mine_screen.dart` | 小红书风格个人信息页，折叠顶栏，帖子/收藏/赞过/动态四Tab，等级徽章/经验进度条/留币入口 |
| 发布页 | `publish_screen.dart` | 块编辑器，文字/图片/语音/链接块，录音、话题标签、红包、分类等级限制提示 |
| 详情页 | `detail_screen.dart` | 帖子内容、图片预览(保存/分享)、语音播放、评论列表(楼中楼/等级徽章)、赞赏列表、点赞/收藏/分享、互关/回关状态 |
| 聊天页 | `chat_screen.dart` | 私聊/群聊，消息撤回，微信风格语音录制动画，本地缓存(200条/会话) |
| 登录页 | `login_screen.dart` | 密码登录、验证码登录、邮箱注册，原生加载指示器 |
| 搜索页 | `search_screen.dart` | 搜索帖子/用户，热门关键词，搜索历史 |
| AI聊天 | `ai_chat_screen.dart` | DeepSeek对话，流式输出，Mac风格代码块 |
| 分类详情 | `category_screen.dart` | 贴吧风格，分类信息/关注/最新/热门/赞过/置顶帖 |
| 他人主页 | `user_profile_screen.dart` | 小红书风格用户主页，折叠顶栏，互关/回关/已关注状态，隐私保护，动态Tab，等级徽章/经验进度条/留币 |
| 编辑资料 | `edit_profile_screen.dart` | 头像/背景图/昵称/简介/性别/生日(中式)/地区 |
| 通知列表 | `notification_list_screen.dart` | 赞/评论/关注/系统 分Tab展示 |
| 设置页 | `settings_screen.dart` | 缓存清理、版本更新、关于、退出登录、邮箱验证码找回密码 |
| 隐私设置 | `privacy_settings_screen.dart` | 关注/粉丝/获赞与收藏/动态列表隐私，修改用户名/邮箱(验证码)/密码，发送验证码加载状态 |
| 通知设置 | `notification_settings_screen.dart` | 推送/赞/评论/关注/收藏/聊天 通知开关 |
| 内置浏览器 | `in_app_browser_screen.dart` | WebView，顶栏导航，更多菜单(复制链接/浏览器打开/刷新) |
| 图片查看器 | `image_viewer_screen.dart` | 全屏查看，左右滑动，保存/分享(小红书风格弹窗) |
| 留币中心 | `coin_center_screen.dart` | 留币余额、签到领币、交易记录、红包/赞赏入口 |
| 管理后台 | `liubi-admin/` | 独立SPA管理面板（Vue3+Vite+ElementPlus），`/admin`路径访问，10大模块 |
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
│  │           Models (7个)              │              │
│  └────────────────────────────────────┘              │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Dio) / WebSocket
┌──────────────────────┴──────────────────────────────┐
│                   Node.js 后端                        │
│  ┌──────────────────────────────────────────────┐    │
│  │  Express + WebSocket (ws)                    │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │    │
│  │  │ Routes │ │Middleware│ │ Utils │           │    │
│  │  │ (15个) │ │  (JWT)  │ │(邮件等)│           │    │
│  │  └───┬────┘ └────────┘ └────────┘           │    │
│  └──────┼───────────────────────────────────────┘    │
│         │                                            │
│  ┌──────┴───────────────────────────────────────┐    │
│  │            MySQL 数据库 (24张表)              │    │
│  └──────────────────────────────────────────────┘    │
│         │                                            │
│  ┌──────┴───────────────────────────────────────┐    │
│  │      /admin → 管理后台 SPA (静态资源)         │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              管理后台 (Vue3 SPA)                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │  Views   │ │  Router  │ │   API    │ │ Layout  │ │
│  │  (11个)  │ │ (JWT守卫) │ │ (30+接口)│ │(侧边栏) │ │
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │
│  Vue3 + Vite + Element Plus + ECharts + Pinia       │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Axios + JWT)
                       │ → /api/admin/*
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

### 管理后台技术栈

| 技术 | 用途 |
|------|------|
| **Vue 3** | 前端框架，Composition API |
| **Vite 6** | 构建工具，HMR热更新 |
| **Element Plus** | UI组件库（表格/表单/弹窗/标签/分页等） |
| **ECharts 5** | 图表库（注册趋势折线图） |
| **Pinia** | 状态管理 |
| **Axios** | HTTP客户端，JWT自动注入 |
| **Vue Router 4** | 路由管理，JWT导航守卫 |

---

## 项目结构

```
liubi/
├── liubi_app/                        # Flutter 前端
│   ├── lib/
│   │   ├── main.dart                 # 入口：路由、主题、Provider注册
│   │   ├── screens/                  # 界面层 (27个)
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
│   │   │   ├── coin_center_screen.dart # 留币中心
│   │   │   └── ...                   # 其他界面
│   │   ├── providers/                # 状态管理
│   │   │   ├── post_provider.dart    # 帖子状态
│   │   │   └── user_provider.dart    # 用户状态
│   │   ├── models/                   # 数据模型 (7个，含LevelInfo)
│   │   ├── services/                 # 服务层 (5个)
│   │   │   ├── api_service.dart      # HTTP客户端(Dio)
│   │   │   ├── chat_service.dart     # WebSocket服务
│   │   │   ├── storage_service.dart  # 本地存储
│   │   │   ├── notification_service.dart # 系统通知
│   │   │   └── update_service.dart   # 版本更新
│   │   ├── widgets/                  # 通用组件 (含level_badge等)
│   │   └── utils/                    # 工具类
│   ├── android/                      # Android原生配置
│   └── pubspec.yaml                  # 依赖配置
│
├── server/                           # Node.js 后端
│   ├── server.js                     # 入口：Express+WebSocket+自动建表
│   ├── routes/                       # API路由 (15个)
│   │   ├── auth.js                   # 认证(注册/登录/验证码/留币/等级)
│   │   ├── posts.js                  # 帖子(CRUD/点赞/收藏/等级信息/经验奖励)
│   │   ├── comments.js               # 评论(楼中楼/点赞/等级信息/经验奖励)
│   │   ├── users.js                  # 用户(资料/关注/隐私/留币/等级/密码找回)
│   │   ├── categories.js             # 分类(社区/关注/等级限制)
│   │   ├── chat.js                   # 聊天(私聊/群聊/撤回/等级信息)
│   │   ├── messages.js               # 消息通知
│   │   ├── notifications.js          # 通知(未读统计)
│   │   ├── upload.js                 # 文件上传
│   │   ├── ai.js                     # AI对话(DeepSeek)
│   │   ├── version.js                # 版本管理
│   │   ├── admin.js                  # 管理后台(邮箱配置数据库化/测试发送)
│   │   ├── stats.js                  # 统计(在线/总览/数据库状态/运行时间)
│   │   ├── coins.js                  # 留币(签到/红包/赞赏/交易/配置)
│   │   └── level-config.js           # 等级配置(12级经验值表/经验规则)
│   ├── config/                       # 数据库/环境配置
│   ├── middleware/                    # JWT认证中间件
│   ├── utils/                        # 工具(邮件/IP/WS)
│   └── package.json                  # 依赖配置
│
├── liubi-admin/                      # 管理后台（Vue3 SPA）
│   ├── src/
│   │   ├── views/                    # 页面 (11个)
│   │   │   ├── Login.vue             # 登录页（管理员邮箱+密码）
│   │   │   ├── Dashboard.vue         # 仪表盘（统计卡片+注册趋势图+系统信息）
│   │   │   ├── Users.vue             # 用户管理（搜索/筛选/编辑/禁用/禁言）
│   │   │   ├── Posts.vue             # 帖子管理（Tab筛选/审核/下架/详情抽屉）
│   │   │   ├── Comments.vue          # 评论管理（列表/删除）
│   │   │   ├── Categories.vue        # 分类管理（CRUD/颜色/等级限制）
│   │   │   ├── Conversations.vue     # 会话管理（私聊/群聊/群号编辑）
│   │   │   ├── Coins.vue             # 留币管理（调整留币/经验/等级配置/签到配置）
│   │   │   ├── AiConfig.vue          # AI配置（对话+绘画双配置）
│   │   │   ├── Version.vue           # 版本管理（发布/编辑/删除/强制更新）
│   │   │   └── System.vue            # 系统设置（SMTP配置+测试发送）
│   │   ├── api/admin.js              # API接口（30+接口）
│   │   ├── layout/index.vue          # 布局（可折叠侧边栏+顶栏）
│   │   ├── router/index.js           # 路由（JWT守卫）
│   │   ├── utils/request.js          # Axios封装（JWT注入/401拦截）
│   │   ├── App.vue                   # 根组件
│   │   ├── main.js                   # 入口（ElementPlus注册）
│   │   └── style.css                 # 全局样式
│   ├── dist/                         # 构建产物（/admin/路径部署）
│   ├── vite.config.js                # Vite配置（base:/admin/，代理/api）
│   └── package.json                  # 依赖（Vue3/Vite/ElementPlus/ECharts/Pinia）
│
└── liubi-release.jks                 # Android签名证书(已排除)
```

---

## 数据库设计

共 **24张表**，分为8大体系：

### 用户体系
| 表名 | 说明 |
|------|------|
| `users` | 用户表（昵称/头像/简介/性别/生日/地区/角色/隐私设置） |
| `follows` | 关注关系表（follower_id + following_id 联合唯一） |
| `verify_codes` | 验证码表（邮箱/验证码/类型/过期时间5分钟） |
| `reset_codes` | 密码重置验证码表（邮箱/验证码/过期时间5分钟） |

### 内容体系
| 表名 | 说明 |
|------|------|
| `posts` | 帖子表（标题/内容/分类/类型/语音/链接/内容块JSON/私密标记） |
| `post_images` | 帖子图片表（URL/媒体类型/宽高比/排序） |
| `comments` | 评论表（楼中楼parent_id/图片/点赞数/置顶） |
| `categories` | 分类表（名称/图标/描述/热度/关注数/发帖限制/最低等级要求） |
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

### 留币体系
| 表名 | 说明 |
|------|------|
| `user_coins` | 用户留币表（余额/总赚/总花/签到天数/上次签到） |
| `coin_transactions` | 留币交易记录表（类型/金额/关联ID/备注） |
| `coin_config` | 留币配置表（签到基础奖励/最大奖励/经验奖励等） |
| `redpackets` | 红包表（总金额/个数/剩余/消息/关联帖子） |
| `redpacket_records` | 红包领取记录表（用户/金额/时间） |
| `appreciations` | 赞赏表（帖子/金额/赞赏者） |

### 等级体系
| 表名 | 说明 |
|------|------|
| `user_levels` | 用户等级表（经验值/等级自动计算） |

### 配置体系
| 表名 | 说明 |
|------|------|
| `email_config` | 邮箱配置表（SMTP地址/端口/账号/密码/发件人，数据库存储替代.env） |

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

### 管理后台启动

```bash
cd liubi-admin
npm install
npm run dev     # 开发模式，端口3001，自动代理/api到3000
npm run build   # 构建到dist/，部署到server的/admin/路径
```

管理后台访问地址：`http://localhost:3001/admin/`（开发模式）或 `http://your-server/admin/`（生产模式）

> 管理员账号需在数据库中设置 `users.role = 1`（管理员）或 `2`（超级管理员）

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
| 认证 | `/api/auth` | 10 | 注册/登录/验证码/修改资料/密码/邮箱/留币/等级数据 |
| 帖子 | `/api/posts` | 11 | CRUD/点赞/收藏/搜索/热门/置顶/私密/等级信息/发帖经验奖励 |
| 评论 | `/api/comments` | 5 | 发表/删除/点赞/置顶/评论者等级信息/评论经验奖励 |
| 用户 | `/api/users` | 14 | 资料/关注/帖子/粉丝/动态/隐私/留币/等级/密码找回 |
| 分类 | `/api/categories` | 4 | 列表/详情/关注/帖子 |
| 聊天 | `/api/chat` | 14 | 会话/消息/撤回/已读/置顶/群管理 |
| 通知 | `/api/notifications` | 4 | 列表/未读/已读 |
| 上传 | `/api/upload` | 2 | 单文件/多文件 |
| AI | `/api/ai` | 3 | 对话/历史/清空 |
| 版本 | `/api/version` | 5 | 检查更新/CRUD |
| 管理 | `/api/admin` | 25+ | 统计/用户/帖子/分类/配置管理/邮箱测试发送/AI配置/版本管理 |
| 留币 | `/api/coins` | 10+ | 签到/余额/红包/赞赏/交易记录/配置/等级配置 |
| 统计 | `/api/stats` | 2 | 在线人数/总览/数据库状态/Node版本/运行时间 |
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
| Beta 0.0.8 | 107 | 留币系统（签到/红包/赞赏/交易记录）、等级系统（12级/经验值/等级徽章/分类等级限制）、管理后台独立SPA化、邮箱配置数据库化、密码找回、微信风格语音录制动画、图片分享、AI生成页重设计、纯文字卡片优化、等级徽章全场景展示 |
| Beta 0.0.6 | 105 | 表情消息支持、Live Photo支持、分类页优化、语音消息显示优化、AI聊天键盘遮挡修复 |

---

<p align="center">
  留笔 Liubi &copy; 2026 - 标记我的生活
</p>
