<p align="center">
  <strong>English</strong> | <a href="README.md">中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Node.js-18+-339933?style=flat-square&logo=node.js" alt="Node.js">
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white" alt="MySQL">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Version-Beta%200.0.10-red?style=flat-square" alt="Version">
</p>

<h1 align="center">Liubi 留笔</h1>

<p align="center"><strong>Mark Your Life</strong></p>

<p align="center">A Xiaohongshu-style social community app featuring rich media posts, real-time chat, AI assistant, category-based communities, and more.<br>Built with Flutter + Node.js + MySQL architecture, powered by WebSocket for real-time communication.</p>

---

## Table of Contents

- [Core Features](#core-features)
- [Screens](#screens)
- [Tech Architecture](#tech-architecture)
- [Project Structure](#project-structure)
- [Database Design](#database-design)
- [UI Design Language](#ui-design-language)
- [Getting Started](#getting-started)
- [API Overview](#api-overview)
- [Deployment](#deployment)
- [Version History](#version-history)

---

## Core Features

### 📝 Content Creation
- **Block Editor**: Free combination of text, image, voice, and link blocks
- **Rich Media Posts**: Waterfall grid layout, multi-image upload, aspect ratio adaptation, long image optimization
- **Text-Only Posts**: Card-style text templates with embedded link cards
- **Voice Posts**: Built-in recording with playback progress bar
- **Hashtags**: Auto-extraction of `#topic#` format tags
- **Link Detection**: Auto-detect URLs in text, red underline clickable, opens in built-in browser
- **Private Posts**: Set posts as private, visible only to the author

### � Coin System (留币)
- **Daily Check-in**: Earn coins daily with increasing rewards for consecutive days
- **Red Packets**: Attach red packets to posts, other users can grab coins
- **Appreciation**: Tip posts with coins, support custom amounts
- **Transaction Records**: Complete income/expense details, balance/total earned/total spent stats
- **Coin Configuration**: Admins can configure check-in base reward, max reward, exp reward, etc.

### 🏆 Level System
- **12 Levels**: From "Newcomer" to "Return to Simplicity", Huluxia-style level system
- **EXP Acquisition**: Earn EXP via check-in/posting/commenting/being liked/being collected
- **Level Badges**: Displayed across all scenes (post cards/comments/chat/profile/discover page)
- **Level Colors**: Lv.1-3 gray / Lv.4-6 blue / Lv.7-9 purple / Lv.10-12 gold
- **EXP Progress Bar**: Profile page shows upgrade progress with current/next level EXP
- **Category Level Restriction**: Categories can set minimum posting level requirements

### �💬 Social Interaction
- **Like / Collect**: Bounce animation effects, real-time count updates
- **Comment System**: Nested replies (threaded), comment like animations, image comments, live photo comments, coin gifting
- **@Mentions**: Auto-complete `@username` in comments, sends notification
- **Follow System**: Bidirectional follow/follower relationship, mutual follow/follow back/following states, privacy controls
- **Category Communities**: Tieba-style categories with follow/post/pin/trending
- **Password Recovery**: Reset password via email verification code, 5-minute validity

### 📡 Real-Time Communication
- **Private Chat**: WebSocket real-time messaging, text/image/live photo/red packet messages
- **Group Chat**: Join via group code, member management
- **Red Packet Messages**: WeChat-style red packet send/receive UI, gradient red background + gold buttons
- **Live Photos**: Chat supports sending live photos, bottom-left Live badge + tap to play
- **Voice Recording**: WeChat-style waveform animation, swipe up to cancel
- **Conversation Management**: Pin / Mark as read / Delete with instant UI updates
- **System Notifications**: Push notifications when app is in background, tap to navigate
- **Heartbeat Keep-Alive**: 30s heartbeat, auto-reconnect (incremental delay, max 10 attempts)

### 🤖 AI Assistant
- **DeepSeek Integration**: Streaming output, real-time conversation
- **Markdown Rendering**: Mac-style code blocks (Catppuccin Mocha dark theme), copy button
- **Chat History**: Local persistence

### 🔧 Admin Dashboard (Standalone SPA)
- **Tech Stack**: Vue 3 + Vite + Element Plus + ECharts + Pinia
- **Standalone Deployment**: Accessible at `/admin` path, Vite dev proxy to backend port 3000
- **10 Modules**:
  - **Dashboard**: Total users/posts/comments/today stats cards (number scroll animation), registration trend line chart (ECharts, 30s auto-refresh), system info panel (Node version/DB status/online count/uptime)
  - **User Management**: Search/role filter/status filter, edit profile, disable/enable, mute (quick times: 1h/6h/1d/7d/30d), coin/level display
  - **Post Management**: Tab filter (All/Normal/Pending/Off-shelf), approve/off-shelf/recover/delete, post detail drawer
  - **Comment Management**: Comment list, post title association, delete
  - **Category Management**: CRUD, icon/cover/color/sort/status/posting level restriction
  - **Conversation Management**: Private/group chat filter, edit group code, delete conversation
  - **Coin Management**: User coin/level/EXP search, adjust coins (positive add/negative subtract + description), adjust EXP, level config table, check-in config (online modify reward params)
  - **AI Config**: AI chat config (API URL/Key/model/prompt/enable switch), AI image config (API URL/Key/model/enable switch)
  - **Version Management**: Publish/edit/delete versions, platform select (Android/iOS/All), update type (Feature/Bug/Security), force update switch
  - **System Settings**: Email SMTP config (database stored, online modify), test email sending
- **Security**: JWT auth, route guard, 401 auto-redirect to login
- **UI**: Collapsible sidebar, theme color `#FF2442`, rounded cards, responsive layout

---

## Screens

### Main Screens (27+)

| Screen | File | Description |
|--------|------|-------------|
| Main Frame | `main_screen.dart` | Bottom 4-tab navigation (Home/Discover/Messages/Me), WebSocket lifecycle |
| Home | `home_screen.dart` | Category tabs + waterfall post grid, pull-to-refresh / load-more / back-to-top |
| Discover | `discover_screen.dart` | Trending posts, recommended users, online count, categories, stats |
| Messages | `message_screen.dart` | Chat conversation list, long-press floating menu (pin/read/delete), unread badges |
| Me | `mine_screen.dart` | Xiaohongshu-style profile, collapsible header, posts/collects/liked/activity tabs, level badge/EXP bar/coin entry |
| Publish | `publish_screen.dart` | Block editor, text/image/voice/link blocks, recording, hashtags, red packets, category level restriction |
| Detail | `detail_screen.dart` | Post content, image preview (save/share), voice playback, comments (threaded/level badges), appreciation list, like/collect/share, mutual follow status |
| Chat | `chat_screen.dart` | Private/group chat, message recall, WeChat-style voice recording, red packet send/receive, live photos, local cache (200 msgs/conversation) |
| Login | `login_screen.dart` | Password login, verification code login, email registration, native loading indicator |
| Search | `search_screen.dart` | Search posts/users, trending keywords, search history |
| AI Chat | `ai_chat_screen.dart` | DeepSeek conversation, streaming output, Mac-style code blocks |
| Category | `category_screen.dart` | Tieba-style, category info/follow/latest/trending/liked/pinned posts |
| User Profile | `user_profile_screen.dart` | Xiaohongshu-style user page, collapsible header, mutual follow/follow back status, privacy, activity tab, level badge/EXP bar |
| Edit Profile | `edit_profile_screen.dart` | Avatar/background/nickname/bio/gender/birthday(Chinese)/region |
| Notifications | `notification_list_screen.dart` | Like/comment/follow/system tabs |
| Settings | `settings_screen.dart` | Cache clear, version update, about, logout, email verification password recovery |
| Privacy | `privacy_settings_screen.dart` | Follow/fans/liked list privacy, change username/email(verification)/password, send code loading state |
| Notification Settings | `notification_settings_screen.dart` | Push/like/comment/follow/collect/chat notification toggles |
| In-App Browser | `in_app_browser_screen.dart` | WebView, top bar navigation, more menu (copy link/open in browser/refresh) |
| Image Viewer | `image_viewer_screen.dart` | Full-screen view, swipe, save/share (Xiaohongshu-style bottom sheet) |
| Coin Center | `coin_center_screen.dart` | Coin balance, daily check-in, transaction records, red packet/appreciation entry |
| Admin Dashboard | `liubi-admin/` | Standalone SPA admin panel (Vue3+Vite+ElementPlus), `/admin` path, 10 modules |
| Trending | `trending_screen.dart` | Trending / Latest tabs |
| About | `about_screen.dart` | App version info, user agreement/privacy policy (in-app browser) |
| Follow/Fans | `follow_list_screen.dart` | Following / Followers list |
| Recommend Users | `recommend_users_screen.dart` | System-recommended users |
| Activity Feed | `activity_feed_screen.dart` | User activity stream |

---

## Tech Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Frontend                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │ Screens  │ │Providers │ │ Services │ │ Widgets │ │
│  │   (27)   │ │   (2)    │ │   (5)    │ │  (11)   │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────────┘ │
│       │            │            │                     │
│  ┌────┴────────────┴────────────┴─────┐              │
│  │            Models (7)               │              │
│  └────────────────────────────────────┘              │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Dio) / WebSocket
┌──────────────────────┴──────────────────────────────┐
│                  Node.js Backend                      │
│  ┌──────────────────────────────────────────────┐    │
│  │  Express + WebSocket (ws)                    │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │    │
│  │  │ Routes │ │  Auth   │ │ Utils  │           │    │
│  │  │  (15)  │ │ (JWT)   │ │(mail)  │           │    │
│  │  └───┬────┘ └────────┘ └────────┘           │    │
│  └──────┼───────────────────────────────────────┘    │
│         │                                            │
│  ┌──────┴───────────────────────────────────────┐    │
│  │         MySQL Database (24 tables)            │    │
│  └──────────────────────────────────────────────┘    │
│         │                                            │
│  ┌──────┴───────────────────────────────────────┐    │
│  │      /admin → Admin SPA (static assets)       │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│             Admin Dashboard (Vue3 SPA)                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │  Views   │ │  Router  │ │   API    │ │ Layout  │ │
│  │   (11)   │ │(JWT Guard)│ │(30+ APIs)│ │(Sidebar)│ │
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │
│  Vue3 + Vite + Element Plus + ECharts + Pinia       │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Axios + JWT)
                       │ → /api/admin/*
```

### Frontend Stack

| Tech | Purpose |
|------|---------|
| **Flutter 3.11+** | Cross-platform UI framework, Material 3 |
| **Provider** | State management (PostProvider + UserProvider) |
| **Dio** | HTTP client with auto JWT injection |
| **web_socket_channel** | WebSocket real-time communication |
| **cached_network_image** | Cached image loading |
| **flutter_staggered_grid_view** | Waterfall grid layout |
| **flutter_markdown** | Markdown rendering (AI chat) |
| **webview_flutter** | In-app browser |
| **flutter_local_notifications** | System push notifications |
| **record / audioplayers** | Recording / audio playback |
| **photo_view** | Image zoom viewer |
| **image_picker / file_picker** | Image / file selection |
| **gal** | Save images to gallery |
| **shared_preferences** | Local key-value storage |
| **permission_handler** | Permission management |
| **Impeller** | Android rendering engine (enabled) |

### Backend Stack

| Tech | Purpose |
|------|---------|
| **Express 4** | Web framework |
| **MySQL2** | MySQL driver (Promise API) |
| **ws** | WebSocket server |
| **jsonwebtoken** | JWT authentication |
| **bcryptjs** | Password hashing |
| **multer** | File upload |
| **nodemailer** | Email sending (verification codes) |
| **cors** | Cross-origin support |
| **dotenv** | Environment variables |

### Admin Dashboard Stack

| Tech | Purpose |
|------|---------|
| **Vue 3** | Frontend framework, Composition API |
| **Vite 6** | Build tool, HMR hot reload |
| **Element Plus** | UI component library (table/form/dialog/tag/pagination etc.) |
| **ECharts 5** | Chart library (registration trend line chart) |
| **Pinia** | State management |
| **Axios** | HTTP client, auto JWT injection |
| **Vue Router 4** | Route management, JWT navigation guard |

---

## Project Structure

```
liubi/
├── liubi_app/                        # Flutter Frontend
│   ├── lib/
│   │   ├── main.dart                 # Entry: routing, theme, Provider setup
│   │   ├── screens/                  # UI Layer (27 screens)
│   │   │   ├── main_screen.dart      # Main frame (4 tabs)
│   │   │   ├── home_screen.dart      # Home (waterfall grid)
│   │   │   ├── discover_screen.dart  # Discover
│   │   │   ├── message_screen.dart   # Messages
│   │   │   ├── mine_screen.dart      # Me
│   │   │   ├── publish_screen.dart   # Publish (block editor)
│   │   │   ├── detail_screen.dart    # Post detail
│   │   │   ├── chat_screen.dart      # Chat
│   │   │   ├── login_screen.dart     # Login/Register
│   │   │   ├── ai_chat_screen.dart   # AI Assistant
│   │   │   ├── coin_center_screen.dart # Coin Center
│   │   │   └── ...                   # Other screens
│   │   ├── providers/                # State Management
│   │   │   ├── post_provider.dart    # Post state
│   │   │   └── user_provider.dart    # User state
│   │   ├── models/                   # Data Models (7, incl. LevelInfo)
│   │   ├── services/                 # Service Layer (5)
│   │   │   ├── api_service.dart      # HTTP Client (Dio)
│   │   │   ├── chat_service.dart     # WebSocket Service
│   │   │   ├── storage_service.dart  # Local Storage
│   │   │   ├── notification_service.dart # System Notifications
│   │   │   └── update_service.dart   # Version Update
│   │   ├── widgets/                  # Shared Components (incl. level_badge etc.)
│   │   └── utils/                    # Utilities
│   ├── android/                      # Android native config
│   └── pubspec.yaml                  # Dependencies
│
├── server/                           # Node.js Backend
│   ├── server.js                     # Entry: Express+WebSocket+Auto DB Init
│   ├── routes/                       # API Routes (15)
│   │   ├── auth.js                   # Auth (register/login/verification/coins/levels)
│   │   ├── posts.js                  # Posts (CRUD/like/collect/level info/EXP reward)
│   │   ├── comments.js               # Comments (threaded/like/level info/EXP reward)
│   │   ├── users.js                  # Users (profile/follow/privacy/coins/levels/password reset)
│   │   ├── categories.js             # Categories (community/follow/level restriction)
│   │   ├── chat.js                   # Chat (private/group/recall/level info)
│   │   ├── messages.js               # Message notifications
│   │   ├── notifications.js          # Notifications (unread stats)
│   │   ├── upload.js                 # File upload
│   │   ├── ai.js                     # AI chat (DeepSeek)
│   │   ├── version.js                # Version management
│   │   ├── admin.js                  # Admin dashboard (email config DB/test send)
│   │   ├── stats.js                  # Statistics (online/overview/DB status/uptime)
│   │   ├── coins.js                  # Coins (checkin/redpacket/appreciate/transactions/config)
│   │   └── level-config.js           # Level config (12-level EXP table/EXP rules)
│   ├── config/                       # Database / environment config
│   ├── middleware/                    # JWT auth middleware
│   ├── utils/                        # Utilities (mail/IP/WS)
│   └── package.json                  # Dependencies
│
├── liubi-admin/                      # Admin Dashboard (Vue3 SPA)
│   ├── src/
│   │   ├── views/                    # Pages (11)
│   │   │   ├── Login.vue             # Login (admin email + password)
│   │   │   ├── Dashboard.vue         # Dashboard (stats cards + registration trend + system info)
│   │   │   ├── Users.vue             # User management (search/filter/edit/disable/mute)
│   │   │   ├── Posts.vue             # Post management (tab filter/approve/off-shelf/detail drawer)
│   │   │   ├── Comments.vue          # Comment management (list/delete)
│   │   │   ├── Categories.vue        # Category management (CRUD/color/level restriction)
│   │   │   ├── Conversations.vue     # Conversation management (private/group/group code edit)
│   │   │   ├── Coins.vue             # Coin management (adjust coins/EXP/level config/check-in config)
│   │   │   ├── AiConfig.vue          # AI config (chat + image dual config)
│   │   │   ├── Version.vue           # Version management (publish/edit/delete/force update)
│   │   │   └── System.vue            # System settings (SMTP config + test send)
│   │   ├── api/admin.js              # API interface (30+ endpoints)
│   │   ├── layout/index.vue          # Layout (collapsible sidebar + top bar)
│   │   ├── router/index.js           # Router (JWT guard)
│   │   ├── utils/request.js          # Axios wrapper (JWT injection / 401 intercept)
│   │   ├── App.vue                   # Root component
│   │   ├── main.js                   # Entry (ElementPlus registration)
│   │   └── style.css                 # Global styles
│   ├── dist/                         # Build output (deploy to /admin/ path)
│   ├── vite.config.js                # Vite config (base:/admin/, proxy /api)
│   └── package.json                  # Dependencies (Vue3/Vite/ElementPlus/ECharts/Pinia)
│
└── liubi-release.jks                 # Android signing keystore (excluded)
```

---

## Database Design

**24 tables** in 8 domains:

### User Domain
| Table | Description |
|-------|-------------|
| `users` | User profiles (nickname/avatar/bio/gender/birthday/region/role/privacy) |
| `follows` | Follow relationships (follower_id + following_id unique) |
| `verify_codes` | Verification codes (email/code/type/expires in 5min) |
| `reset_codes` | Password reset codes (email/code/expires in 5min) |

### Content Domain
| Table | Description |
|-------|-------------|
| `posts` | Posts (title/content/category/type/voice/link/content_blocks JSON/private) |
| `post_images` | Post images (URL/media type/aspect ratio/sort order) |
| `comments` | Comments (nested parent_id/image/likes/pinned) |
| `categories` | Categories (name/icon/description/heat/follow count/post restriction/min level) |
| `category_follows` | Category follows |

### Interaction Domain
| Table | Description |
|-------|-------------|
| `likes` | Likes (post/comment, user+target+type unique) |
| `collects` | Collections |
| `messages` | Notifications (like/comment/follow/system/mention/collect/chat) |
| `activities` | Activity feed (post/like/comment/collect/follow) |
| `mentions` | @Mentions |

### Chat Domain
| Table | Description |
|-------|-------------|
| `chat_conversations` | Conversations (private/group/group code) |
| `chat_members` | Members (pinned/hidden flags) |
| `chat_messages` | Messages (text/image/system/recalled) |

### Coin Domain
| Table | Description |
|-------|-------------|
| `user_coins` | User coins (balance/total earned/total spent/checkin days/last checkin) |
| `coin_transactions` | Coin transaction records (type/amount/related ID/note) |
| `coin_config` | Coin configuration (checkin base reward/max reward/EXP reward etc.) |
| `redpackets` | Red packets (total amount/count/remaining/message/related post) |
| `redpacket_records` | Red packet claim records (user/amount/time) |
| `appreciations` | Appreciations (post/amount/appreciator) |

### Level Domain
| Table | Description |
|-------|-------------|
| `user_levels` | User levels (EXP/level auto-calculated) |

### Config Domain
| Table | Description |
|-------|-------------|
| `email_config` | Email config (SMTP host/port/account/password/sender, DB storage replacing .env) |

### Others
| Table | Description |
|-------|-------------|
| `search_logs` | Search history |
| `ai_config` | AI config (API URL/key/model/prompt) |
| `ai_chat_history` | AI chat history |
| `app_versions` | Version management (version code/download URL/force update/changelog) |

---

## UI Design Language

### Design Tokens
- **Primary Color**: `#FF2442` (Vibrant Red) — used for likes, collects, publish button, loading indicators
- **Background**: `#FFFFFF` white primary, `#F5F7FA` light gray secondary
- **Text Colors**: `#222222` headings / `#333333` body / `#999999` auxiliary
- **Border Radius**: Unified `12px` large / `8px` small
- **Shadows**: Soft projection `blurRadius: 16, offset: (0, 4), alpha: 0.12`

### Interaction Highlights
| Feature | Implementation |
|---------|---------------|
| Waterfall Grid | `flutter_staggered_grid_view`, adaptive aspect ratio |
| Skeleton Loading | Shimmer placeholders, show skeleton before content loads |
| Bounce Animation | Like/collect `ScaleTransition` with overshoot curve |
| Page Transitions | `CupertinoPageTransitionsBuilder`, iOS-style slide |
| Pull-to-Refresh | `CupertinoSliverRefreshControl`, native style |
| Long-Press Menu | Custom `OverlayEntry` floating white rounded menu (WeChat-style) |
| Image Save | Xiaohongshu-style bottom sheet + system toast |
| Code Blocks | Mac-style three-dot header + Catppuccin Mocha dark theme + copy button |
| Loading Indicator | `CupertinoActivityIndicator`, native system style |
| Text Selection | `SelectableText` + custom copy callback (toast "Copied") |
| System Notifications | Dual channels (community + chat), tap to navigate |
| Voice Recording | WeChat-style waveform animation, swipe up to cancel |

### Adaptations
- **OPPO Font**: `fontFamily: null` + `Typography.blackCupertino` + `letterSpacing: 0`
- **Impeller Engine**: Enabled on Android for better rendering performance
- **Bouncing Scroll**: Global `BouncingScrollPhysics`, iOS-style overscroll

---

## Getting Started

### Prerequisites

- Flutter SDK 3.11+
- Node.js 18+
- MySQL 8.0+
- Android SDK (minSdk 24, targetSdk 36)

### Backend Setup

```bash
cd server
npm install
cp .env.example .env    # Configure database and email
node server.js           # Auto-creates tables + starts server
```

`.env` configuration:
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

### Frontend Setup

```bash
cd liubi_app
flutter pub get
flutter run
```

API base URL is configured in `lib/services/api_service.dart`.

### Admin Dashboard Setup

```bash
cd liubi-admin
npm install
npm run dev     # Dev mode, port 3001, auto proxy /api to port 3000
npm run build   # Build to dist/, deploy to server's /admin/ path
```

Admin dashboard URL: `http://localhost:3001/admin/` (dev mode) or `http://your-server/admin/` (production)

> Admin accounts require `users.role = 1` (admin) or `2` (super admin) in the database

### Build Signed APK

```bash
cd liubi_app
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## API Overview

| Module | Prefix | Endpoints | Core Functions |
|--------|--------|-----------|----------------|
| Auth | `/api/auth` | 10 | Register/login/verification/profile/password/email |
| Posts | `/api/posts` | 11 | CRUD/like/collect/search/trending/pin/private |
| Comments | `/api/comments` | 5 | Post/delete/like/pin |
| Users | `/api/users` | 12 | Profile/follow/posts/fans/activity/privacy |
| Categories | `/api/categories` | 4 | List/detail/follow/posts |
| Chat | `/api/chat` | 14 | Conversations/messages/recall/read/pin/group |
| Notifications | `/api/notifications` | 4 | List/unread/read |
| Upload | `/api/upload` | 2 | Single/multi file |
| AI | `/api/ai` | 3 | Chat/history/clear |
| Version | `/api/version` | 5 | Check update/CRUD |
| Admin | `/api/admin` | 25+ | Stats/users/posts/categories/email-config/ai-config/version |
| Coins | `/api/coins` | 10+ | Checkin/balance/redpacket/appreciate/transactions/config/level-config |
| Stats | `/api/stats` | 2 | Online count/overview/DB status/Node version/uptime |
| WebSocket | `/ws` | - | Real-time chat/notifications/heartbeat/online broadcast |

---

## Deployment

### Server Deployment

```bash
# Upload to server
scp -r server/ root@your_server:/www/wwwroot/liubi/server/

# Install dependencies and start
cd /www/wwwroot/liubi/server
npm install
pm2 start server.js --name liubi
pm2 save
```

### Admin Dashboard Deployment

```bash
# Build admin dashboard
cd liubi-admin
npm install
npm run build

# Deploy dist/ to server's /admin/ path
scp -r dist/ root@your_server:/www/wwwroot/liubi/server/public/admin/
```

### Heat Algorithm

```
Post Heat = views×1 + likes×5 + collects×3 + comments×2
Category Heat = views×0.1 + likes×3 + comments×2 + collects×1.5
```

---

## Version History

| Version | Build | Notes |
|---------|-------|-------|
| Beta 0.0.10 | 109 | Fix chat red packet/live photo duplicate send bug, fix comment coin gifting logic bug (always showing "cannot gift yourself"), optimize red packet send UI (gradient red + gold buttons), optimize red packet receive UI (circular avatar + gold amount + open button), fix keyboard overlapping chat input, comment supports live photos and coin gifting, APK obfuscation + compression (ABI split + ProGuard) |
| Beta 0.0.9 | 108 | Fix remote update/check update, optimize version check API cache, publish button layout fix, red packet post association fix, text-media editor optimization, checkin timezone bug fix, profile page layout optimization, category/trending level display, in-app browser refactor (flutter_inappwebview), APK size optimization (ABI split + obfuscation + compression) |
| Beta 0.0.8 | 107 | Coin system (checkin/redpacket/appreciate/transactions), Level system (12 levels/EXP/badges/category restrictions), Admin dashboard standalone SPA, Email config DB migration, Password recovery, WeChat-style voice recording animation, Image sharing, AI generation page redesign, Text-only card optimization, Level badges across all scenes |
| Beta 0.0.6 | 105 | Emoji messages, Live Photo support, Category page optimization, Voice message display optimization, AI chat keyboard overlap fix |

---

<p align="center">
  Liubi 留笔 &copy; 2026 - Mark Your Life
</p>
