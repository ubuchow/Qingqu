# 轻取 (Qingqu)

极简 macOS 视频下载工具。粘贴链接即可下载，支持清晰度 / 格式选择，可固定在 Dock。

基于 [yt-dlp](https://github.com/yt-dlp/yt-dlp)，可下载哔哩哔哩、YouTube 等上千个站点。小红书因站点接口变动，成功率不稳定，建议配合浏览器 Cookie。

## 功能

- 粘贴或拖入视频链接，自动识别站点；支持带说明文案、换行的分享文本，只将提取出的链接交给下载器，避免把文案拼进网址
- 视频 / 音频模式
- 清晰度：自动最佳 · 4K · 1080p · 720p · 480p · 360p
- 封装格式：MP4 · MKV · WebM · 原格式
- 音频导出：M4A · MP3 · Opus · FLAC
- 可选 Safari / Chrome / Edge Cookie（大会员、登录态内容）
- 窗口固定为打开时的尺寸（小屏幕自动适配可用空间），不提供缩放或全屏入口
- “最近下载”支持一键清空全部历史记录，重启后仍保持清空；不删除已下载的文件
- macOS 26+ 使用系统原生 Liquid Glass，macOS 27 启用交互玻璃效果；保留现有字体与排版
- 按钮内的中英文和数字按可见字形边界垂直居中，正文仍使用原有排版。
- ⌘W（关闭并退出）与 ⌘Q（退出）均完全结束应用进程；点击红色关闭按钮仍仅关闭窗口、保留在 Dock

## 环境要求

- macOS 14+
- [Homebrew](https://brew.sh) 安装依赖：

```bash
brew install yt-dlp ffmpeg
```

- 界面字体（构建时从本机复制，不入库）：
  - 正文：华文中宋
  - 大标题：方正公文小标宋（可从 WPS 字体目录读取；缺省时回退方正小标宋简体）
- 构建需要有效的 Apple Development 签名证书。脚本使用本机证书签名，不再退回临时签名；可用 `QINGQU_SIGNING_IDENTITY` 指定固定证书。

## 安装使用

1. 编译安装：

```bash
./scripts/build.sh
```

应用会安装到 `~/Applications/轻取.app`。

2. 打开「轻取」，粘贴视频链接，选择清晰度与格式后下载。  
   默认保存到 `~/下载/轻取`。

## 浏览器 Cookie 与系统授权

- 需要登录态的视频可选择已登录的 Safari / Chrome / Edge；无需登录时可选择“不使用”。
- macOS 可能要求允许“轻取”访问浏览器数据；只有授权后才能从对应浏览器读取 Cookie。未安装浏览器、未登录或访问被阻止时，界面会显示 Cookie 读取失败的原因，不会静默关闭 Cookie。
- 旧版采用临时签名，更新后系统可能无法匹配原有的数据访问授权。此版本改为稳定的开发者签名，首次切换仍可能需要重新允许；后续构建请保持签名身份一致。

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
  Views/        # AppKit 界面与半透明控件
  Resources/    # 图标与资源
scripts/
  build.sh
  make-app-icon.swift
project.yml     # XcodeGen 配置
```

## 许可

MIT
