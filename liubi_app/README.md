# 留笔 (Liubi)

一款记录生活的社交应用。

## 版本信息

- **版本名**: Beta 0.0.10
- **版本号**: 109

## 功能特性

- 📸 发布图文动态（块编辑器，文字/图片/语音/链接）
- 📷 实况图片支持（发布/评论/聊天）
- 💬 智能AI助手聊天
- 🎨 AI绘画生成
- 👥 关注与粉丝系统
- 🔍 发现与搜索
- 💌 消息通知
- 💰 留币系统（签到/红包/赞赏/交易记录）
- 🏆 等级系统（12级/经验值/等级徽章）
- 🧧 聊天红包（微信风格发送/领取UI）
- 🎁 评论赠送留币

## 技术栈

- **前端**: Flutter 3.11+
- **后端**: Node.js + Express
- **数据库**: MySQL
- **状态管理**: Provider

## 快速开始

```bash
# 克隆项目
git clone https://github.com/your-repo/liubi.git

# 进入项目目录
cd liubi_app

# 安装依赖
flutter pub get

# 运行项目
flutter run

# 打包发布版本
flutter build apk --release
```

## 项目结构

```
liubi_app/
├── android/          # Android配置
├── assets/           # 静态资源
├── lib/
│   ├── screens/      # 页面组件
│   ├── widgets/      # 通用组件
│   ├── services/     # 服务层
│   ├── providers/    # 状态管理
│   └── utils/        # 工具函数
└── pubspec.yaml      # 依赖配置
```

## License

MIT License