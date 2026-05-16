<p align="center">
  <strong>English</strong> | <a href="README.md">中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat-square&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Node.js-18+-339933?style=flat-square&logo=node.js" alt="Node.js">
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white" alt="MySQL">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Version-Beta%200.0.5-red?style=flat-square" alt="Version">
</p>

<h1 align="center">Liubi 留笔</h1>

<p align="center"><strong>Mark Your Life</strong></p>

<p align="center">A Xiaohongshu-style social community app featuring rich media posts, real-time chat, AI assistant, and category-based communities.<br>Built with Flutter + Node.js + MySQL, powered by WebSocket for real-time communication.</p>

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

### 💬 Social Interaction
- **Like / Collect**: Bounce animation effects, real-time count updates
- **Comment System**: Nested replies (threaded), comment like animations, image comments
- **@Mentions**: Auto-complete `@username` in comments, sends notification
- **Follow System**: Bidirectional follow/follower relationship with privacy controls
- **Category Communities**: Tieba-style categories with follow/post/pin/trending

### 📡 Real-Time Communication
- **Private Chat**: WebSocket real-time messaging, text/image messages
- **Group Chat**: Join via group code, member management
- **Message Recall**: Recall within 2 minutes
- **Conversation Management**: Pin / Mark as read / Delete with instant UI updates
- **System Notifications**: Push notifications when app is in background, tap to navigate
- **Heartbeat Keep-Alive**: 30s heartbeat, auto-reconnect (incremental delay, max 10 attempts)

### 🤖 AI Assistant
- **DeepSeek Integration**: Streaming output, real-time conversation
- **Markdown Rendering**: Mac-style code blocks (Catppuccin Mocha dark theme), copy button
- **Chat History**: Local persistence

### 🔧 Admin Dashboard
- **8 Modules**: Statistics / Users / Posts / Comments / Categories / Conversations / Email Config / AI Config
- **User Management**: Disable / Mute / Role switching
- **Content Moderation**: Post takedown / Comment deletion / Category management
- **Version Management**: Publish new versions, force update control

---

## Screens

### Main Screens (26)

| Screen | File | Description |
|--------|------|-------------|
| Main Frame | `main_screen.dart` | Bottom 4-tab navigation (Home/Discover/Messages/Me), WebSocket lifecycle |
| Home | `home_screen.dart` | Category tabs + waterfall post grid, pull-to-refresh / load-more / back-to-top |
| Discover | `discover_screen.dart` | Trending posts, recommended users, online count, categories, stats |
| Messages | `message_screen.dart` | Chat conversation list, long-press floating menu (pin/read/delete), unread badges |
| Me | `mine_screen.dart` | Profile info, posts/collects/liked tabs, settings entry |
| Publish | `publish_screen.dart` | Block editor, text/image/voice/link blocks, recording, hashtags |
| Detail | `detail_screen.dart` | Post content, image preview (save), voice playback, comments (threaded), like/collect/share |
| Chat | `chat_screen.dart` | Private/group chat, message recall, local cache (200 msgs/conversation) |
| Login | `login_screen.dart` | Password login, verification code login, email registration, native loading indicator |
| Search | `search_screen.dart` | Search posts/users, trending keywords, search history |
| AI Chat | `ai_chat_screen.dart` | DeepSeek conversation, streaming output, Mac-style code blocks |
| Category | `category_screen.dart` | Tieba-style, category info/follow/latest/trending/liked/pinned posts |
| User Profile | `user_profile_screen.dart` | User info, follow status, DM entry, post list |
| Edit Profile | `edit_profile_screen.dart` | Avatar/background/nickname/bio/gender/birthday(Chinese)/region |
| Notifications | `notification_list_screen.dart` | Like/comment/follow/system tabs |
| Settings | `settings_screen.dart` | Cache clear, version update, about, logout |
| Privacy | `privacy_settings_screen.dart` | Follow/fans/liked list privacy, change username/email(verification)/password |
| Notification Settings | `notification_settings_screen.dart` | Push/like/comment/follow/collect/chat notification toggles |
| In-App Browser | `in_app_browser_screen.dart` | WebView, top bar navigation, more menu (copy link/open in browser/refresh) |
| Image Viewer | `image_viewer_screen.dart` | Full-screen view, swipe, long-press save (Xiaohongshu-style bottom sheet) |
| Admin | `admin_screen.dart` | 8-tab admin panel, admin-only |
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
│  │   (26)   │ │   (2)    │ │   (5)    │ │  (11)   │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────────┘ │
│       │            │            │                     │
│  ┌────┴────────────┴────────────┴─────┐              │
│  │            Models (6)               │              │
│  └────────────────────────────────────┘              │
└──────────────────────┬──────────────────────────────┘
                       │ HTTP (Dio) / WebSocket
┌──────────────────────┴──────────────────────────────┐
│                  Node.js Backend                      │
│  ┌──────────────────────────────────────────────┐    │
│  │  Express + WebSocket (ws)                    │    │
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │    │
│  │  │ Routes │ │  Auth  │ │ Utils  │           │    │
│  │  │  (13)  │ │ (JWT)  │ │(mail)  │           │    │
│  │  └───┬────┘ └────────┘ └────────┘           │    │
│  └──────┼───────────────────────────────────────┘    │
│         │                                            │
│  ┌──────┴───────────────────────────────────────┐    │
│  │         MySQL Database (20 tables)            │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
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

---

## Project Structure

```
liubi/
├── liubi_app/                        # Flutter Frontend
│   ├── lib/
│   │   ├── main.dart                 # Entry: routing, theme, Provider setup
│   │   ├── screens/                  # UI Layer (26 screens)
│   │   ├── providers/                # State Management (2)
│   │   ├── models/                   # Data Models (6)
│   │   ├── services/                 # Service Layer (5)
│   │   │   ├── api_service.dart      # HTTP Client (Dio)
│   │   │   ├── chat_service.dart     # WebSocket Service
│   │   │   ├── storage_service.dart  # Local Storage
│   │   │   ├── notification_service.dart # System Notifications
│   │   │   └── update_service.dart   # Version Update
│   │   ├── widgets/                  # Shared Components (11)
│   │   └── utils/                    # Utilities
│   ├── android/                      # Android native config
│   └── pubspec.yaml                  # Dependencies
│
├── server/                           # Node.js Backend
│   ├── server.js                     # Entry: Express+WebSocket+Auto DB Init
│   ├── routes/                       # API Routes (13)
│   │   ├── auth.js                   # Auth (register/login/verification)
│   │   ├── posts.js                  # Posts (CRUD/like/collect/search)
│   │   ├── comments.js               # Comments (threaded/like)
│   │   ├── users.js                  # Users (profile/follow/privacy)
│   │   ├── categories.js             # Categories (community/follow)
│   │   ├── chat.js                   # Chat (private/group/recall)
│   │   ├── messages.js               # Message notifications
│   │   ├── notifications.js          # Notifications (unread stats)
│   │   ├── upload.js                 # File upload
│   │   ├── ai.js                     # AI chat (DeepSeek)
│   │   ├── version.js                # Version management
│   │   ├── admin.js                  # Admin dashboard
│   │   └── stats.js                  # Statistics (online/overview)
│   ├── config/                       # Database / environment config
│   ├── middleware/                    # JWT auth middleware
│   ├── utils/                        # Utilities (mail/IP/WS)
│   └── package.json                  # Dependencies
│
└── liubi-release.jks                 # Android signing keystore (excluded)
```

---

## Database Design

**20 tables** in 6 domains:

### User Domain
| Table | Description |
|-------|-------------|
| `users` | User profiles (nickname/avatar/bio/gender/birthday/region/role/privacy) |
| `follows` | Follow relationships (follower_id + following_id unique) |
| `verify_codes` | Verification codes (email/code/type/expires in 5min) |

### Content Domain
| Table | Description |
|-------|-------------|
| `posts` | Posts (title/content/category/type/voice/link/content_blocks JSON/private) |
| `post_images` | Post images (URL/media type/aspect ratio/sort order) |
| `comments` | Comments (nested parent_id/image/likes/pinned) |
| `categories` | Categories (name/icon/description/heat/follow count/post restriction) |
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
cp .env.example ..env    # Configure database and email
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
| Admin | `/api/admin` | 20+ | Stats/users/posts/categories/config |
| Stats | `/api/stats` | 2 | Online count/overview |
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

### Heat Algorithm

```
Post Heat = views×1 + likes×5 + collects×3 + comments×2
Category Heat = views×0.1 + likes×3 + comments×2 + collects×1.5
```

---

## Version History

| Version | Build | Notes |
|---------|-------|-------|
| Beta 0.0.5 | 104 | Current release |

---

<p align="center">
  Liubi 留笔 &copy; 2026 - Mark Your Life
</p>
