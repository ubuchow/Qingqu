# 轻取 (Qingqu)

极简 macOS 视频下载工具。粘贴链接即可下载，支持清晰度 / 格式选择，可固定在 Dock，支持全屏。

基于 [yt-dlp](https://github.com/yt-dlp/yt-dlp)，可下载哔哩哔哩、YouTube 等上千个站点。小红书因站点接口变动，成功率不稳定，建议配合浏览器 Cookie。

## 功能

- 粘贴或拖入视频链接，自动识别站点
- 视频 / 音频模式
- 清晰度：自动最佳 · 4K · 1080p · 720p · 480p · 360p
- 封装格式：MP4 · MKV · WebM · 原格式
- 音频导出：M4A · MP3 · Opus · FLAC
- 可选 Safari / Chrome / Edge Cookie（大会员、登录态内容）
- 窗口可缩放、全屏（⌃⌘F）
- 关闭窗口不退出，保留在 Dock

## 环境要求

- macOS 14+
- [Homebrew](https://brew.sh) 安装依赖：

```bash
brew install yt-dlp ffmpeg
```

## 安装使用

1. 编译安装：

```bash
./scripts/build.sh
```

应用会安装到 `~/Applications/轻取.app`。

2. 打开「轻取」，粘贴视频链接，选择清晰度与格式后下载。  
   默认保存到 `~/下载/轻取`。

## 开发

```bash
# 生成 Xcode 工程
xcodegen generate

# 或用脚本一键 Release 构建
./scripts/build.sh
```

源码结构：

```
Qingqu/
  App/          # 应用入口与下载逻辑
  Views/        # SwiftUI 界面
  Resources/    # 图标与资源
scripts/
  build.sh
  make-app-icon.swift
project.yml     # XcodeGen 配置
```

## 许可

MIT
