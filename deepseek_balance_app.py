#!/Library/Frameworks/Python.framework/Versions/3.11/bin/python3
"""
DeepSeek API 余额 - macOS 菜单栏应用
双击 .app 即可运行，无需终端窗口。

依赖: pip3 install rumps certifi
"""

import json
import os
import ssl
import subprocess
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

import AppKit
import rumps

CONFIG_DIR = Path.home() / '.config' / 'deepseek-balance'
CONFIG_FILE = CONFIG_DIR / 'config.json'
CACHE_FILE = CONFIG_DIR / 'cache.json'
LAUNCHD_PLIST = Path.home() / 'Library' / 'LaunchAgents' / 'com.deepseek.balance.plist'
LOG_FILE = Path.home() / 'Library' / 'Logs' / 'deepseek-balance.log'
LOCK_FILE = CONFIG_DIR / '.lock'
DAILY_FILE = CONFIG_DIR / 'daily_usage.json'

BALANCE_API = 'https://api.deepseek.com/user/balance'
APP_VERSION = '1.0'

INTERVAL_PRESETS = {
    '1 分钟': 60,
    '5 分钟': 300,
    '10 分钟': 600,
    '30 分钟': 1800,
    '1 小时': 3600,
    '自定义...': -1,
}

_ssl_context_cache = None
_locale_data = {}
LOCALE_DIR = Path(__file__).resolve().parent / 'locales'


def load_locale(lang='zh-CN'):
    """加载语言文件，回退到中文"""
    global _locale_data
    path = LOCALE_DIR / f'{lang}.json'
    try:
        with open(path, 'r', encoding='utf-8') as f:
            _locale_data = json.load(f)
    except Exception:
        _locale_data = {}
        log(f'语言文件加载失败: {path}')


def log(msg):
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(f'[{timestamp}] {msg}\n')
    except Exception:
        pass


def acquire_lock():
    """防多开：获取文件锁"""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if LOCK_FILE.exists():
        try:
            old_pid = int(LOCK_FILE.read_text().strip())
            os.kill(old_pid, 0)
            return False
        except (ValueError, OSError, ProcessLookupError):
            pass
    LOCK_FILE.write_text(str(os.getpid()))
    return True


def release_lock():
    try:
        LOCK_FILE.unlink()
    except Exception:
        pass


def load_daily_usage():
    """加载每日使用历史"""
    try:
        with open(DAILY_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return []


def save_daily_usage(data):
    """保存每日使用历史（保留最近 90 天）"""
    try:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        data = data[-90:]
        with open(DAILY_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass


def load_config():
    try:
        with open(CONFIG_FILE.resolve(), 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def save_cache(data):
    try:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False)
    except Exception:
        pass


def load_cache():
    try:
        with open(CACHE_FILE.resolve(), 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return None


def _get_ssl_context():
    global _ssl_context_cache
    if _ssl_context_cache is None:
        try:
            import certifi
            _ssl_context_cache = ssl.create_default_context(cafile=certifi.where())
        except ImportError:
            _ssl_context_cache = ssl.create_default_context()
    return _ssl_context_cache


def query_balance(api_key):
    req = urllib.request.Request(
        BALANCE_API,
        headers={
            'Authorization': f'Bearer {api_key}',
            'Accept': 'application/json',
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=10, context=_get_ssl_context()) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        raise Exception(f'服务器返回错误 {e.code}')
    except urllib.error.URLError as e:
        reason = str(e.reason)
        if 'SSL' in reason or 'certificate' in reason.lower():
            raise Exception('SSL 证书验证失败，请检查网络代理')
        raise Exception(f'网络连接失败: {reason}')
    except json.JSONDecodeError:
        raise Exception('响应格式异常')


def parse_balance(data):
    if not data.get('is_available'):
        raise Exception('账户不可用')
    balance_infos = data.get('balance_infos', [])
    if not balance_infos:
        raise Exception('无余额信息')
    info = balance_infos[0]
    return {
        'currency': info.get('currency', 'CNY'),
        'total': float(info.get('total_balance', 0)),
        'topped_up': float(info.get('topped_up_balance', 0)),
        'granted': float(info.get('granted_balance', 0)),
    }


class DeepSeekBalanceApp(rumps.App):
    def __init__(self):
        super(DeepSeekBalanceApp, self).__init__(
            name='API',
            title='...',
            quit_button=self._t('退出'),
        )
        self.config = load_config()
        self.api_key = os.environ.get('DEEPSEEK_API_KEY', '').strip()
        if not self.api_key:
            self.api_key = self.config.get('api_key', '').strip()

        self.display_prefix = self.config.get('display_prefix', 'API')
        self.top_font_size = int(self.config.get('top_font_size', 10))
        self.bottom_font_size = int(self.config.get('bottom_font_size', 7))
        self.warn_threshold = float(self.config.get('warn_threshold', 5))
        self.critical_threshold = float(self.config.get('critical_threshold', 20))
        self.refresh_interval = int(self.config.get('refresh_interval', 300))
        self.lang = self.config.get('lang', 'zh-CN')
        load_locale(self.lang)
        self.current_balance = None
        self.is_cached = False
        self.trend = ''
        self._prev_balance_ok = False
        self._first_update = True
        self.today_date = ''
        self.today_used = 0.0
        self._prev_total = 0.0
        # 从缓存恢复今日状态
        cached = load_cache()
        if cached:
            self.today_date = cached.get('today_date', '')
            self.today_used = cached.get('today_used', 0)
            self._prev_total = cached.get('prev_total', 0)
            if self.today_date != datetime.now().strftime('%Y-%m-%d'):
                self.today_date = ''
                self.today_used = 0.0
                self._prev_total = 0.0

        # 余额显示
        self.menu_item_total = rumps.MenuItem(title=self._t('余额显示') + ': ---')
        self.menu_item_used = rumps.MenuItem(title=self._t('今日使用') + ': ---')

        self.menu = [
            self.menu_item_total,
            self.menu_item_used,
            None,
            rumps.MenuItem(title=self._t('立即刷新'), callback=self.refresh_balance),
            rumps.MenuItem(title=self._t('打开_DeepSeek_开放平台'), callback=self.open_platform),
            rumps.MenuItem(title=self._t('打开_DeepSeek_开始对话'), callback=self.open_chat),
            None,
            rumps.MenuItem(title=self._t('设置'), callback=self.show_settings),
            None,
            rumps.MenuItem(title=self._t('使用统计'), callback=self.show_usage),
            rumps.MenuItem(title=self._t('版本') + ': v' + APP_VERSION, callback=None),
            None,
            rumps.MenuItem(title=self._t('关于'), callback=self.show_about),
        ]

        self.timer = rumps.Timer(self.update_balance, self.refresh_interval)
        self.timer.start()
        # 延迟重试：等 nsstatusitem 创建后立即设置双行标题
        self._init_timer = rumps.Timer(self._initial_update, 1.0)
        self._init_timer.start()

        log('应用启动')

    def _initial_update(self, _=None):
        """run 循环就绪后执行首次更新；若 statusbar 未就绪则重试"""
        if not self._statusbar_ready():
            self._init_timer = rumps.Timer(self._initial_update, 1.0)
            self._init_timer.start()
            return
        self._init_timer.stop()
        self.update_balance()

    def cleanup_before_quit(self):
        log('应用退出')
        release_lock()
        super().cleanup_before_quit()

    # ---------- 工具 ----------

    def _format_interval(self):
        seconds = self.refresh_interval
        if seconds < 60:
            return f'{seconds} 秒'
        elif seconds < 3600:
            return f'{seconds // 60} 分钟'
        else:
            return f'{seconds // 3600} 小时'

    def _t(self, key, **kwargs):
        """获取翻译文字"""
        text = _locale_data.get(key, key)
        if kwargs:
            try:
                return text.format(**kwargs)
            except Exception:
                return text
        return text

    def _set_custom_title(self, top_text, bottom_text, top_color=None):
        """用自定义 NSView 实现上下两行显示（参照 State 应用方案）"""
        if not self._statusbar_ready():
            self.title = f'{top_text}  {bottom_text}'
            return

        button = self._nsapp.nsstatusitem.button()
        max_w = 120

        def _make_label(bold=False):
            label = AppKit.NSTextField.alloc().init()
            label.setBezeled_(False)
            label.setDrawsBackground_(False)
            label.setEditable_(False)
            label.setSelectable_(False)
            label.setAlignment_(AppKit.NSTextAlignmentCenter)
            label.setLineBreakMode_(AppKit.NSLineBreakByClipping)
            if bold:
                label.setFont_(AppKit.NSFont.systemFontOfSize_weight_(self.top_font_size, AppKit.NSFontWeightMedium))
            else:
                label.setFont_(AppKit.NSFont.systemFontOfSize_weight_(self.bottom_font_size, AppKit.NSFontWeightRegular))
            return label

        def _size_label(label, text, max_width):
            label.setStringValue_(text)
            # 用系统方法计算实际宽度，限制最大值
            size = label.sizeThatFits_((max_width, 30))
            w = min(size.width, max_width)
            h = size.height
            label.setFrame_(((0, 0), (w, h)))
            return w, h

        if not hasattr(self, '_custom_view'):
            self._top_label = _make_label(bold=True)
            self._bottom_label = _make_label(bold=False)
            self._custom_view = AppKit.NSView.alloc().initWithFrame_(((0, 0), (80, 22)))
            self._custom_view.addSubview_(self._top_label)
            self._custom_view.addSubview_(self._bottom_label)
            button.addSubview_(self._custom_view)
            button.setTitle_('')

        # 更新颜色
        if top_color:
            self._top_label.setTextColor_(top_color)
        else:
            self._top_label.setTextColor_(AppKit.NSColor.labelColor())

        # 计算尺寸并布局
        self._top_label.setFont_(AppKit.NSFont.systemFontOfSize_weight_(self.top_font_size, AppKit.NSFontWeightMedium))
        self._bottom_label.setFont_(AppKit.NSFont.systemFontOfSize_weight_(self.bottom_font_size, AppKit.NSFontWeightRegular))

        tw, top_h = _size_label(self._top_label, top_text, max_w)
        bw, bottom_h = _size_label(self._bottom_label, bottom_text, max_w)

        total_w = max(tw, bw) + 2
        total_h = top_h + bottom_h
        self._custom_view.setFrame_(((0, 0), (total_w, total_h)))

        # 上行居中靠上，下行居中靠下，自然宽度不强制等宽
        self._top_label.setFrame_(((total_w / 2 - tw / 2, bottom_h), (tw, top_h)))
        self._bottom_label.setFrame_(((total_w / 2 - bw / 2, 0), (bw, bottom_h)))

        self._nsapp.nsstatusitem.setLength_(total_w + 4)

    def _statusbar_ready(self):
        """检查菜单栏控件是否已就绪"""
        return (hasattr(self, '_nsapp')
                and self._nsapp is not None
                and hasattr(self._nsapp, 'nsstatusitem')
                and self._nsapp.nsstatusitem is not None)

    def _save_settings(self):
        self.config['api_key'] = self.api_key
        self.config['display_prefix'] = self.display_prefix
        self.config['top_font_size'] = self.top_font_size
        self.config['bottom_font_size'] = self.bottom_font_size
        self.config['warn_threshold'] = self.warn_threshold
        self.config['critical_threshold'] = self.critical_threshold
        self.config['refresh_interval'] = self.refresh_interval
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
        os.chmod(CONFIG_FILE, 0o600)

    def _restart_timer(self):
        if hasattr(self, 'timer') and self.timer:
            self.timer.stop()
        self.timer = rumps.Timer(self.update_balance, self.refresh_interval)
        self.timer.start()

    def _prompt_input(self, title, message, default=''):
        window = rumps.Window(
            message=message,
            title=title,
            default_text=str(default),
            ok='保存',
            cancel='取消',
            dimensions=(320, 80),
        )
        response = window.run()
        if response.clicked:
            return window.text.strip()
        return None

    # ---------- 开机自启 ----------

    def _get_app_path(self):
        return Path(__file__).resolve().parent.parent.parent

    def _autostart_status(self):
        return '开机自启: ✓' if LAUNCHD_PLIST.exists() else '开机自启: ✗'

    def toggle_autostart(self, _):
        if LAUNCHD_PLIST.exists():
            try:
                uid = os.getuid()
                subprocess.run(
                    ['launchctl', 'bootout', f'gui/{uid}', str(LAUNCHD_PLIST)],
                    capture_output=True
                )
            except Exception:
                pass
            try:
                LAUNCHD_PLIST.unlink()
            except Exception:
                pass
            log('已关闭开机自启')
        else:
            app_path = str(self._get_app_path())
            plist_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.deepseek.balance</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>{app_path}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>'''
            LAUNCHD_PLIST.parent.mkdir(parents=True, exist_ok=True)
            LAUNCHD_PLIST.write_text(plist_content)
            uid = os.getuid()
            subprocess.run(
                ['launchctl', 'bootstrap', f'gui/{uid}', str(LAUNCHD_PLIST)],
                capture_output=True
            )
            log('已开启开机自启')

    # ---------- 设置窗口 ----------

    def show_sync_help(self, _):
        config_path = str(CONFIG_FILE.resolve()) if CONFIG_FILE.exists() else str(CONFIG_FILE)
        is_symlink = CONFIG_FILE.is_symlink() if CONFIG_FILE.exists() else False
        sync_status = self._t('当前已同步') if is_symlink else self._t('当前本地配置')
        msg = self._t('多端同步内容', status=sync_status, icloud=icloud, config_path=config_path)
        rumps.alert(msg)

    # ---------- 关于 ----------

    @rumps.clicked('关于 DeepSeek Balance')
    def show_about(self, _):
        msg = self._t('关于内容', version=APP_VERSION, config=CONFIG_FILE, log=LOG_FILE, cache=CACHE_FILE)
        rumps.alert(msg)

    # ---------- 刷新间隔 ----------

    def _set_interval(self, seconds):
        self.refresh_interval = seconds
        self._save_settings()
        self._restart_timer()
        self.update_balance()
        log(f'刷新间隔设为 {seconds} 秒')

    def _custom_interval(self, _):
        val = self._prompt_input(
            '自定义刷新间隔',
            '输入秒数（10 ~ 86400）：',
            self.refresh_interval
        )
        if val:
            try:
                seconds = int(val)
                if seconds < 10:
                    rumps.alert('间隔不能小于 10 秒')
                    return
                if seconds > 86400:
                    rumps.alert('间隔不能超过 24 小时（86400 秒）')
                    return
                self._set_interval(seconds)
            except ValueError:
                rumps.alert('请输入有效的数字')

    # ---------- 前缀 ----------

    def change_prefix(self, _):
        val = self._prompt_input('设置前缀', '菜单栏显示的前缀文字（最多 8 个字符）：', self.display_prefix)
        if val:
            if len(val) > 8:
                rumps.alert('前缀最多 8 个字符')
                return
            self.display_prefix = val
            self._save_settings()
            self.update_balance()
            log(f'前缀改为: {val}')

    # ---------- 警告线 ----------

    def _set_warn_threshold(self, value):
        if value >= self.critical_threshold:
            rumps.alert(f'警告线必须小于严重线（当前严重线: ¥{self.critical_threshold:.0f}）')
            return
        self.warn_threshold = float(value)
        self._save_settings()
        self.update_balance()
        log(f'警告线设为 ¥{value}')

    def _custom_warn(self, _):
        val = self._prompt_input('自定义警告线', '余额低于此值显示红色（元）：', self.warn_threshold)
        if val:
            try:
                threshold = float(val)
                if threshold <= 0:
                    rumps.alert('阈值必须大于 0')
                    return
                self._set_warn_threshold(threshold)
            except ValueError:
                rumps.alert('请输入有效的数字')

    # ---------- 严重线 ----------

    def _set_critical_threshold(self, value):
        if value <= self.warn_threshold:
            rumps.alert(f'严重线必须大于警告线（当前警告线: ¥{self.warn_threshold:.0f}）')
            return
        self.critical_threshold = float(value)
        self._save_settings()
        self.update_balance()
        log(f'严重线设为 ¥{value}')

    def _custom_critical(self, _):
        val = self._prompt_input('自定义严重线', '余额低于此值显示黄色（元）：', self.critical_threshold)
        if val:
            try:
                threshold = float(val)
                if threshold <= 0:
                    rumps.alert('阈值必须大于 0')
                    return
                self._set_critical_threshold(threshold)
            except ValueError:
                rumps.alert('请输入有效的数字')

    # ---------- 字体大小 ----------

    def _set_top_font(self, size):
        self.top_font_size = size
        self._save_settings()
        self.update_balance()
        log(f'上行字号设为 {size}pt')

    def _set_bottom_font(self, size):
        self.bottom_font_size = size
        self._save_settings()
        self.update_balance()
        log(f'下行字号设为 {size}pt')

    # ---------- 核心 ----------

    def update_balance(self, _=None):
        if not self.api_key:
            self._set_custom_title('⚙', self.display_prefix)
            self.menu_item_total.title = self._t('余额显示') + ': ---'
            self.menu_item_used.title = self._t('今日使用') + ': ---'
            return

        try:
            data = query_balance(self.api_key)
            balance = parse_balance(data)
            self.is_cached = False

            if self.current_balance and not self._first_update:
                prev_total = self.current_balance['total']
                diff = balance['total'] - prev_total
                if diff > 0.005:
                    self.trend = f' ↑+{diff:.2f}'
                elif diff < -0.005:
                    self.trend = f' ↓{diff:.2f}'
                else:
                    self.trend = ''
            else:
                self.trend = ''

            self.current_balance = balance
            self._first_update = False

            today_str = datetime.now().strftime('%Y-%m-%d')
            if self.today_date != today_str:
                if self.today_date:
                    history = load_daily_usage()
                    history.append({'date': self.today_date, 'used': round(self.today_used, 4)})
                    save_daily_usage(history)
                self.today_date = today_str
                self.today_used = 0.0
                self._prev_total = balance['total']
            else:
                decrease = self._prev_total - balance['total']
                if decrease > 0:
                    self.today_used += decrease
                self._prev_total = balance['total']

            save_cache({
                'balance': balance, 'ts': time.time(),
                'today_date': self.today_date,
                'prev_total': self._prev_total,
                'today_used': self.today_used,
            })
            log(f'{self._t("日志_余额更新")}: ¥{balance["total"]:.2f}{self.trend}')
        except Exception as e:
            log(f'{self._t("日志_查询失败")}: {e}')
            cached = load_cache()
            if cached and cached.get('balance'):
                self.current_balance = cached['balance']
                self.is_cached = True
                self.cache_ts = cached.get('ts', 0)
                self.trend = ''
            else:
                self.current_balance = None
                self._set_custom_title('✗', self.display_prefix)
                self.menu_item_total.title = self._t('查询失败')
                self.menu_item_used.title = f'{self._t("错误_网络")}: {e}'
                return

        total = self.current_balance['total']
        prefix = self.display_prefix
        is_cached = self.is_cached

        if not self._first_update and not is_cached:
            if total < self.warn_threshold and self._prev_balance_ok:
                rumps.notification(
                    title=self._t('余额不足警告'),
                    subtitle=self._t('余额不足内容', balance=f'{total:.2f}'),
                    message=self._t('请及时充值'),
                    sound=True,
                )
            self._prev_balance_ok = total >= self.warn_threshold

        top = f'¥{total:.2f}'
        bottom = prefix

        if total < self.warn_threshold and not is_cached:
            top_color = AppKit.NSColor.systemRedColor()
        elif total < self.critical_threshold and not is_cached:
            top_color = AppKit.NSColor.systemOrangeColor()
        else:
            top_color = None

        self._set_custom_title(top, bottom, top_color)

        self.menu_item_total.title = self._t('余额显示') + f': ¥{total:.2f}'
        self.menu_item_used.title = self._t('今日使用') + f': ¥{self.today_used:.2f}'

    @rumps.clicked('立即刷新')
    def refresh_balance(self, _):
        self.config = load_config()
        self.lang = self.config.get('lang', 'zh-CN')
        load_locale(self.lang)
        new_key = self.config.get('api_key', '').strip()
        if new_key and new_key != self.api_key:
            self.api_key = new_key
            log(self._t('日志_检测到API_Key变更'))
        self._set_custom_title('...', self.display_prefix)
        self.update_balance()

    @rumps.clicked('打开 DeepSeek 开放平台')
    def open_platform(self, _):
        import webbrowser
        webbrowser.open('https://platform.deepseek.com/')

    @rumps.clicked('打开 DeepSeek 开始对话')
    def open_chat(self, _):
        import webbrowser
        webbrowser.open('https://chat.deepseek.com/')

    @rumps.clicked('使用统计')
    def show_usage(self, _):
        """显示每日使用统计"""
        history = load_daily_usage()
        if not history:
            rumps.alert('暂无使用记录\n\n每天 00:00 自动归档昨日数据。')
            return
        # 按年月分组汇总
        lines = []
        grouped = {}
        for entry in history:
            ym = entry['date'][:7]  # 2026-07
            grouped.setdefault(ym, []).append(entry)

        for ym in sorted(grouped.keys(), reverse=True):
            entries = grouped[ym]
            month_total = sum(e['used'] for e in entries)
            lines.append(f'{ym}  合计 ¥{month_total:.4f}')
            for e in sorted(entries, key=lambda x: x['date'], reverse=True):
                lines.append(f'  {e["date"]}  ¥{e["used"]:.4f}')

        msg = '\n'.join(lines[:30])  # 最多显示 30 行
        if len(lines) > 30:
            msg += f'\n\n... 共 {len(history)} 条记录\n完整数据: {DAILY_FILE}'
        rumps.alert(msg)

    # ---------- 设置窗口 ----------

    @rumps.clicked('设置...')
    def show_settings(self, _):
        """弹出设置面板，修改即时生效"""
        W, row_h, pad = 360, 26, 12
        left = 14
        label_w = 54
        ctrl_x = left + label_w + 10
        rows = 9
        win_h = rows * (row_h + pad) + pad * 2

        panel = AppKit.NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
            ((0, 0), (W, win_h)),
            AppKit.NSWindowStyleMaskTitled | AppKit.NSWindowStyleMaskClosable,
            AppKit.NSBackingStoreBuffered, False
        )
        panel.setTitle_('DeepSeek Balance 设置')
        panel.center()
        panel.setStyleMask_(panel.styleMask() | AppKit.NSWindowStyleMaskUtilityWindow)
        panel.setHidesOnDeactivate_(False)

        content = panel.contentView()
        y = win_h - pad - row_h
        font14 = AppKit.NSFont.systemFontOfSize_(14)

        def lbl(text):
            t = AppKit.NSTextField.labelWithString_(text)
            t.setFont_(font14)
            t.setFrame_(((left, y + 5), (label_w, 18)))
            t.setAlignment_(AppKit.NSTextAlignmentRight)
            content.addSubview_(t)

        def inp(val, action=None):
            t = AppKit.NSTextField.alloc().initWithFrame_(((ctrl_x, y + 5), (140, row_h - 10)))
            t.setStringValue_(val)
            t.setFont_(font14)
            t.setBordered_(False)
            t.setBezeled_(False)
            t.setAlignment_(AppKit.NSTextAlignmentCenter)
            t.setDrawsBackground_(True)
            t.setBackgroundColor_(AppKit.NSColor.controlBackgroundColor())
            if action:
                t.setTarget_(self)
                t.setAction_(action)
            content.addSubview_(t)
            return t

        def sel(items, current, cb):
            btn = AppKit.NSPopUpButton.alloc().initWithFrame_pullsDown_(((ctrl_x, y + 4), (140, row_h - 8)), False)
            for item in items:
                btn.addItemWithTitle_(str(item))
            btn.setTitle_(str(current))
            btn.setTarget_(self)
            btn.setAction_(cb)
            content.addSubview_(btn)
            return btn

        def chk(title, checked):
            cb = AppKit.NSButton.alloc().initWithFrame_(((ctrl_x, y + 5), (180, row_h - 10)))
            cb.setButtonType_(AppKit.NSSwitchButton)
            cb.setTitle_(title)
            cb.setFont_(font14)
            cb.setState_(1 if checked else 0)
            cb.setTarget_(self)
            content.addSubview_(cb)
            return cb

        lbl('前 缀\u3000')
        inp(self.display_prefix, 'onPrefixChange:')
        y -= row_h + pad

        lbl('刷 新\u3000')
        intervals = ['1分钟', '5分钟', '10分钟', '30分钟', '1小时']
        self._settings_int_vals = [60, 300, 600, 1800, 3600]
        sel(intervals, self._format_interval(), 'onIntervalChange:')
        y -= row_h + pad

        lbl('上字号')
        self._settings_top_fonts = [7, 8, 9, 10, 11, 12, 13, 14]
        sel([str(f) + 'pt' for f in self._settings_top_fonts], str(self.top_font_size) + 'pt', 'onTopFontChange:')
        y -= row_h + pad

        lbl('下字号')
        self._settings_bot_fonts = [5, 6, 7, 8, 9, 10]
        sel([str(f) + 'pt' for f in self._settings_bot_fonts], str(self.bottom_font_size) + 'pt', 'onBottomFontChange:')
        y -= row_h + pad

        lbl('警告线')
        inp(str(self.warn_threshold), 'onWarnChange:')
        y -= row_h + pad

        lbl('严重线')
        inp(str(self.critical_threshold), 'onCriticalChange:')
        y -= row_h + pad

        lbl('开 机\u3000')
        chk('开机自启', LAUNCHD_PLIST.exists())
        y -= row_h + pad

        btn_h = row_h - 2
        b1 = AppKit.NSButton.alloc().initWithFrame_(((ctrl_x, y + 1), (120, btn_h)))
        b1.setTitle_('多端同步说明')
        b1.setBezelStyle_(AppKit.NSRoundedBezelStyle)
        b1.setTarget_(self)
        b1.setAction_('showSyncHelp:')
        content.addSubview_(b1)
        b2 = AppKit.NSButton.alloc().initWithFrame_(((ctrl_x + 130, y + 1), (80, btn_h)))
        b2.setTitle_('关于')
        b2.setBezelStyle_(AppKit.NSRoundedBezelStyle)
        b2.setTarget_(self)
        b2.setAction_('showAbout:')
        content.addSubview_(b2)
        y -= row_h + pad

        # 作者（右下角贴边）
        author = AppKit.NSTextField.labelWithString_('by MoYuRan')
        author.setFont_(AppKit.NSFont.systemFontOfSize_(10))
        author.setTextColor_(AppKit.NSColor.secondaryLabelColor())
        author.setFrame_(((W - 110, 4), (100, 14)))
        author.setAlignment_(AppKit.NSTextAlignmentRight)
        content.addSubview_(author)

        lbl('多 端\u3000')
        t = AppKit.NSTextField.labelWithString_('终端 ln -sf 链接 iCloud')
        t.setFont_(font14)
        t.setTextColor_(AppKit.NSColor.secondaryLabelColor())
        t.setFrame_(((ctrl_x, y + 6), (200, 17)))
        content.addSubview_(t)

        self._settings_panel = panel
        AppKit.NSApp().activateIgnoringOtherApps_(True)
        panel.makeKeyAndOrderFront_(None)

    # ---------- 设置窗口回调 ----------

    def onPrefixChange_(self, sender):
        val = sender.stringValue().strip()
        if val and len(val) <= 8:
            self.display_prefix = val
            self._save_settings()
            self.update_balance()

    def onIntervalChange_(self, sender):
        idx = sender.indexOfSelectedItem()
        if 0 <= idx < len(self._settings_int_vals):
            self._set_interval(self._settings_int_vals[idx])

    def onTopFontChange_(self, sender):
        idx = sender.indexOfSelectedItem()
        if 0 <= idx < len(self._settings_top_fonts):
            self._set_top_font(self._settings_top_fonts[idx])

    def onBottomFontChange_(self, sender):
        idx = sender.indexOfSelectedItem()
        if 0 <= idx < len(self._settings_bot_fonts):
            self._set_bottom_font(self._settings_bot_fonts[idx])

    def onWarnChange_(self, sender):
        try:
            v = float(sender.stringValue())
            if v > 0:
                self._set_warn_threshold(v)
        except ValueError:
            pass

    def onCriticalChange_(self, sender):
        try:
            v = float(sender.stringValue())
            if v > 0:
                self._set_critical_threshold(v)
        except ValueError:
            pass

    def onAutostartChange_(self, sender):
        if sender.state() == 1:
            if not LAUNCHD_PLIST.exists():
                self.toggle_autostart(None)
        else:
            if LAUNCHD_PLIST.exists():
                self.toggle_autostart(None)

    def showSyncHelp_(self, _):
        self.show_sync_help(None)

    def openConfig_(self, _):
        pass

    def showAbout_(self, _):
        self.show_about(None)


def main():
    # 强制隐藏 Dock 图标，阻止 Python.app 闪现
    AppKit.NSApplication.sharedApplication().setActivationPolicy_(
        AppKit.NSApplicationActivationPolicyAccessory
    )
    if not acquire_lock():
        rumps.alert('DeepSeek Balance 已在运行中\n\n请查看菜单栏右上角。')
        return
    DeepSeekBalanceApp().run()


if __name__ == '__main__':
    main()
