# DeepSeek Balance

macOS 菜单栏实时显示 DeepSeek API 余额。
> macOS menu bar real-time DeepSeek API balance monitor.

## 功能 / Features

- 菜单栏两行显示余额 / Two-line menu bar display
- 每日使用统计，00:00 自动归档 / Daily usage stats, auto-archived at 00:00
- 余额不足系统通知 / Low balance system notification
- 独立设置面板 / Standalone settings panel
- 开机自启 / Launch at login
- 多端同步（iCloud 符号链接） / Multi-device sync via iCloud symlink
- 多语言 / Multi-language（中文 / English / Русский）

## 安装 / Install

下载 [最新 DMG](https://github.com/MoYuRan1992/deepseek-balance/releases/latest) → 双击挂载 → 拖入 Applications。
> Download the [latest DMG](https://github.com/MoYuRan1992/deepseek-balance/releases/latest) → double-click to mount → drag to Applications.

首次打开若提示无法验证，右键 → 打开即可。
> If warned about an unidentified developer on first open, right-click → Open.

## 配置 / Setup

首次运行后点击菜单栏图标 →「设置...」，在 Key 输入框中粘贴你的 [DeepSeek API Key](https://platform.deepseek.com/api_keys)，修改即时生效。
> On first launch, click the menu bar icon → "Settings..." → paste your [DeepSeek API Key](https://platform.deepseek.com/api_keys) in the Key field. Changes take effect immediately.

也可直接编辑配置文件 `~/.config/deepseek-balance/config.json`：
> Or edit the config file directly:

```json
{
  "api_key": "sk-你的API-Key",
  "lang": "zh-CN"
}
```

> 请勿将含真实 Key 的 config.json 提交到公开仓库。
> Do NOT commit config.json with your real API key to public repositories.

## 系统要求 / Requirements

- macOS 10.14+
- Intel & Apple Silicon

## 开发 / Development

```bash
pip3 install rumps certifi py2app
python3 setup.py py2app
```
