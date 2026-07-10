import Cocoa
import UserNotifications
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var menuBarView: MenuBarView!
    var config = Config()
    var cache = CacheData()
    var timer: Timer?
    var settingsWC: SettingsWindowController?
    var isFirstUpdate = true
    var prevBalanceOk = false

    var todayDate = ""
    var todayUsed = 0.0
    var prevTotal = 0.0

    // MARK: - 启动

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !acquireLock() {
            let alert = NSAlert()
            alert.messageText = "DeepSeek Balance"
            alert.informativeText = "已在运行中\n\n请查看菜单栏右上角。"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        config = loadConfig()
        loadLocale(config.lang)
        cache = loadCache()

        todayDate = cache.today_date
        todayUsed = cache.today_used
        prevTotal = cache.prev_total
        let curDate = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        if todayDate != curDate { todayDate = ""; todayUsed = 0; prevTotal = 0 }

        setupStatusBar()
        startTimer()
        refresh()
        appLog("应用启动")
    }

    func applicationWillTerminate(_ notification: Notification) {
        appLog("应用退出")
        timer?.invalidate()
        releaseLock()
        archiveYesterdayIfNeeded()
    }

    // MARK: - 状态栏

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = ""
        menuBarView = MenuBarView(frame: NSRect(x: 0, y: 0, width: 60, height: 22))
        menuBarView.config = config
        statusItem.button?.addSubview(menuBarView)
        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()
        let totalItem = NSMenuItem(title: "\(t("余额显示")): ---", action: nil, keyEquivalent: "")
        let usedItem = NSMenuItem(title: "\(t("今日使用")): ---", action: nil, keyEquivalent: "")
        [totalItem, usedItem].forEach { $0.isEnabled = false; menu.addItem($0) }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("立即刷新"), action: #selector(refresh), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: t("打开_DeepSeek_开放平台"), action: #selector(openPlatform), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: t("打开_DeepSeek_开始对话"), action: #selector(openChat), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("设置"), action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("使用统计"), action: #selector(showUsage), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "\(t("版本")): v\(APP_VERSION)", action: #selector(openRelease), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("关于"), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("退出"), action: #selector(terminate), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func toggleAutoStart() {
        if FileManager.default.fileExists(atPath: LAUNCHD_PLIST.path) {
            _ = try? Process.run(URL(fileURLWithPath: "/bin/launchctl"), arguments: ["unload", LAUNCHD_PLIST.path])
            try? FileManager.default.removeItem(at: LAUNCHD_PLIST)
        } else {
            let appPath = Bundle.main.bundlePath
            let content = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
            <key>Label</key><string>com.deepseek.balance</string>
            <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>\(appPath)</string></array>
            <key>RunAtLoad</key><true/><key>KeepAlive</key><false/>
            </dict></plist>
            """
            try? FileManager.default.createDirectory(at: LAUNCHD_PLIST.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? content.write(to: LAUNCHD_PLIST, atomically: true, encoding: .utf8)
            _ = try? Process.run(URL(fileURLWithPath: "/bin/launchctl"), arguments: ["load", LAUNCHD_PLIST.path])
        }
        buildMenu()
    }

    // MARK: - 定时刷新

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.refresh_interval), repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc func refresh() {
        guard !config.api_key.isEmpty else {
            let w = menuBarView.update(top: "⚙", bottom: config.display_prefix)
            statusItem.length = w + 4
            updateMenuBalance(nil)
            return
        }

        Task {
            do {
                let balance = try await queryBalance(apiKey: config.api_key)
                await MainActor.run { self.handleBalance(balance) }
            } catch {
                await MainActor.run {
                    if let cached = self.cache.balance {
                        self.updateDisplay(balance: cached, isCached: true)
                    } else {
                        self.menuBarView.update(top: "✗", bottom: self.config.display_prefix)
                        self.statusItem.length = self.menuBarView.frame.width + 4
                        self.updateMenuBalance(nil, error: error.localizedDescription)
                    }
                }
            }
        }
    }

    func handleBalance(_ balance: BalanceInfo) {
        updateTodayUsage(balance.total_balance)
        let c = CacheData(balance: balance, ts: Date().timeIntervalSince1970, today_date: todayDate, prev_total: prevTotal, today_used: todayUsed)
        saveCache(c)
        cache = c
        appLog("余额更新: ¥\(balance.total_balance)")

        if !isFirstUpdate && prevBalanceOk && balance.total_balance < config.warn_threshold {
            sendNotification(title: t("余额不足警告"), body: t("余额不足内容", ["balance": String(format: "%.2f", balance.total_balance)]))
        }
        prevBalanceOk = balance.total_balance >= config.warn_threshold
        isFirstUpdate = false
        updateDisplay(balance: balance, isCached: false)
    }

    func updateDisplay(balance: BalanceInfo, isCached: Bool) {
        let top = "¥\(String(format: "%.2f", balance.total_balance))"
        let bottom = config.display_prefix
        var color: NSColor?
        if !isCached && balance.total_balance < config.warn_threshold {
            color = .systemRed
        } else if !isCached && balance.total_balance < config.critical_threshold {
            color = .systemOrange
        }
        menuBarView.config = config
        let w = menuBarView.update(top: top, bottom: bottom, topColor: color)
        statusItem.length = w + 4
        updateMenuBalance(balance)
    }

    func updateMenuBalance(_ balance: BalanceInfo?, error: String? = nil) {
        guard let menu = statusItem.menu else { return }
        if let b = balance {
            menu.item(at: 0)?.title = "\(t("余额显示")): ¥\(String(format: "%.2f", b.total_balance))"
            menu.item(at: 1)?.title = "\(t("今日使用")): ¥\(String(format: "%.2f", todayUsed))"
        } else if let err = error {
            menu.item(at: 0)?.title = t("查询失败")
            menu.item(at: 1)?.title = "\(t("错误_网络")): \(err)"
        } else {
            menu.item(at: 0)?.title = "\(t("余额显示")): ---"
            menu.item(at: 1)?.title = "\(t("今日使用")): ---"
        }
    }

    // MARK: - 每日统计

    func updateTodayUsage(_ total: Double) {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        if todayDate != today {
            if !todayDate.isEmpty {
                var history = loadDailyUsage()
                history.append(DailyEntry(date: todayDate, used: round(todayUsed * 10000) / 10000))
                saveDailyUsage(history)
            }
            todayDate = today
            todayUsed = 0.0
            prevTotal = total
        } else {
            let decrease = prevTotal - total
            if decrease > 0 { todayUsed += decrease }
            prevTotal = total
        }
    }

    func archiveYesterdayIfNeeded() {
        if !todayDate.isEmpty {
            var history = loadDailyUsage()
            history.append(DailyEntry(date: todayDate, used: round(todayUsed * 10000) / 10000))
            saveDailyUsage(history)
        }
    }

    // MARK: - 通知

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - 设置

    @objc func showSettings() {
        if let wc = settingsWC, wc.window?.isVisible == true {
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }

        let binding = Binding<Config>(
            get: { self.config },
            set: { self.config = $0 }
        )

        let autoStartOn = FileManager.default.fileExists(atPath: LAUNCHD_PLIST.path)

        let balanceStr: String = {
            if let b = cache.balance { return "¥\(String(format: "%.2f", b.total_balance))" }
            return "---"
        }()
        let todayStr: String = {
            if cache.balance != nil { return "¥\(String(format: "%.2f", todayUsed))" }
            return "---"
        }()

        settingsWC = SettingsWindowController(
            config: binding,
            balanceText: balanceStr,
            todayUsedText: todayStr,
            autoStartEnabled: autoStartOn,
            onToggleAutoStart: { [weak self] in
                self?.toggleAutoStart()
            },
            onSave: { [weak self] in
                guard let self = self else { return }
                saveConfig(self.config)
                loadLocale(self.config.lang)
                self.startTimer()
                self.refresh()
                self.buildMenu()
            },
            onCheckUpdate: { [weak self] in
                self?.checkForUpdate()
            },
            onShowUsage: { [weak self] in
                self?.showUsage()
            }
        )

        settingsWC?.window?.center()
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 使用统计

    @objc func showUsage() {
        let history = loadDailyUsage()
        if history.isEmpty {
            let a = NSAlert(); a.messageText = t("暂无使用记录"); a.runModal(); return
        }
        var lines = [String]()
        for e in history.sorted(by: { $0.date > $1.date }) {
            lines.append("\(e.date)  ¥\(String(format: "%.4f", e.used))")
        }
        let total = history.reduce(0) { $0 + $1.used }
        lines.append("")
        lines.append("合计  ¥\(String(format: "%.4f", total))")
        let a = NSAlert()
        a.messageText = Array(lines.prefix(35)).joined(separator: "\n")
        a.addButton(withTitle: "关闭")
        a.addButton(withTitle: "重置统计")
        if a.runModal() == .alertSecondButtonReturn {
            saveDailyUsage([])
            todayUsed = 0
            prevTotal = 0
            todayDate = ""
        }
    }

    // MARK: - 关于

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DeepSeek Balance v\(APP_VERSION)"
        alert.informativeText = t("关于内容", ["version": APP_VERSION, "config": CONFIG_FILE.path, "log": LOG_FILE.path, "cache": CACHE_FILE.path])
        alert.runModal()
    }

    // MARK: - 外部链接

    @objc func openPlatform() { NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/")!) }
    @objc func openChat() { NSWorkspace.shared.open(URL(string: "https://chat.deepseek.com/")!) }
    @objc func openRelease() { checkForUpdate() }

    func checkForUpdate() {
        let url = URL(string: "https://api.github.com/repos/MoYuRan1992/deepseek-balance/releases/latest")!
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let assets = json["assets"] as? [[String: Any]],
                      let dmgAsset = assets.first(where: { ($0["name"] as? String ?? "").hasSuffix(".dmg") }),
                      let downloadURL = dmgAsset["browser_download_url"] as? String else {
                    let errAlert = NSAlert()
                    errAlert.messageText = "检查更新失败"
                    errAlert.informativeText = error?.localizedDescription ?? "无法连接 GitHub，请检查网络。"
                    errAlert.addButton(withTitle: "手动查看")
                    errAlert.addButton(withTitle: "取消")
                    if errAlert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "https://github.com/MoYuRan1992/deepseek-balance/releases/latest")!)
                    }
                    return
                }

                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let notes = json["body"] as? String

                if latestVersion == APP_VERSION {
                    let a = NSAlert()
                    a.messageText = "已是最新版本"
                    a.informativeText = "当前版本 v\(APP_VERSION) 已是最新。"
                    a.alertStyle = .informational
                    a.addButton(withTitle: "确定")
                    a.runModal()
                } else {
                    let wc = UpdateWindowController(
                        newVersion: tagName,
                        currentVersion: "v\(APP_VERSION)",
                        releaseNotes: notes,
                        onDownload: { [weak self] in
                            self?.downloadUpdate(from: downloadURL, version: tagName)
                        },
                        onManualCheck: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/MoYuRan1992/deepseek-balance/releases/latest")!)
                        },
                        onDismiss: {}
                    )
                    wc.showWindow(nil)
                    wc.window?.center()
                    wc.window?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }.resume()
    }

    func downloadUpdate(from urlString: String, version: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.downloadTask(with: url) { localURL, _, error in
            DispatchQueue.main.async {
                guard let localURL = localURL, error == nil else {
                    let errAlert = NSAlert()
                    errAlert.messageText = "下载失败"
                    errAlert.informativeText = error?.localizedDescription ?? "请检查网络后重试。"
                    errAlert.addButton(withTitle: "手动查看")
                    errAlert.addButton(withTitle: "取消")
                    if errAlert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "https://github.com/MoYuRan1992/deepseek-balance/releases/latest")!)
                    }
                    return
                }

                let downloadsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
                let destURL = downloadsDir.appendingPathComponent("DeepSeek Balance \(version).dmg")
                try? FileManager.default.removeItem(at: destURL)
                try? FileManager.default.moveItem(at: localURL, to: destURL)

                let doneAlert = NSAlert()
                doneAlert.messageText = "下载完成"
                doneAlert.informativeText = "已保存到「下载」文件夹。"
                doneAlert.alertStyle = .informational
                doneAlert.addButton(withTitle: "打开安装")
                doneAlert.addButton(withTitle: "稍后")
                if doneAlert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(destURL)
                }
            }
        }.resume()
    }

    @objc func terminate() { NSApp.terminate(nil) }
}
