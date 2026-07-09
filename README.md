# DeepSeek Balance

macOS 菜单栏实时显示 DeepSeek API 余额，仿 State 应用风格。

## 功能

- 菜单栏两行显示余额（仿 State）
- 每日使用统计，00:00 自动归档
- 余额不足系统通知
- 独立设置面板
- 开机自启（launchd）
- 多端同步（iCloud 符号链接）

## 安装

下载 [最新 DMG](https://github.com/MoYuRan1992/deepseek-balance/releases/latest) → 双击挂载 → 拖入 Applications。

首次打开若提示无法验证，右键 → 打开即可。

## 系统要求

- macOS 10.14+
- Intel & Apple Silicon

## 开发

```bash
pip3 install rumps certifi py2app
python3 setup.py py2app
```
