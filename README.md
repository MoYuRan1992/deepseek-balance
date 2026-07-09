# DeepSeek Balance

macOS 菜单栏实时显示 DeepSeek API 余额。

## 功能

- 菜单栏两行显示余额
- 每日使用统计，00:00 自动归档
- 余额不足系统通知
- 独立设置面板
- 开机自启（launchd）
- 多端同步（iCloud 符号链接）

## 安装

下载 [最新 DMG](https://github.com/MoYuRan1992/deepseek-balance/releases/latest) → 双击挂载 → 拖入 Applications。

首次打开若提示无法验证，右键 → 打开即可。

## 配置

首次运行后点击菜单栏图标 →「设置...」，在**前缀**输入框中粘贴你的 [DeepSeek API Key](https://platform.deepseek.com/api_keys)，修改即时生效。

也可直接编辑配置文件 `~/.config/deepseek-balance/config.json`：

```json
{
  "api_key": "sk-你的API-Key",
  "lang": "zh-CN"
}
```

> 请勿将含真实 Key 的 config.json 提交到公开仓库。仓库中 `config.example.json` 仅为模板。

## 系统要求

- macOS 10.14+
- Intel & Apple Silicon

## 开发

```bash
pip3 install rumps certifi py2app
python3 setup.py py2app
```
