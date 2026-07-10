import SwiftUI

struct SettingsView: View {
    @Binding var config: Config
    var balanceText: String
    var todayUsedText: String
    var autoStartEnabled: Bool
    var onToggleAutoStart: () -> Void
    var onSave: () -> Void
    var onCheckUpdate: () -> Void
    var onShowUsage: () -> Void

    @State private var displayPrefix: String
    @State private var apiKey: String
    @State private var showKey: Bool = false
    @State private var refreshIntervalIdx: Int
    @State private var topFontSize: Double
    @State private var botFontSize: Double
    @State private var warnThresholdStr: String
    @State private var criticalThresholdStr: String
    @State private var langIdx: Int
    @State private var autoStart: Bool

    init(config: Binding<Config>, balanceText: String, todayUsedText: String, autoStartEnabled: Bool, onToggleAutoStart: @escaping () -> Void, onSave: @escaping () -> Void, onCheckUpdate: @escaping () -> Void, onShowUsage: @escaping () -> Void) {
        self._config = config
        self.balanceText = balanceText
        self.todayUsedText = todayUsedText
        self.autoStartEnabled = autoStartEnabled
        self.onToggleAutoStart = onToggleAutoStart
        self.onSave = onSave
        self.onCheckUpdate = onCheckUpdate
        self.onShowUsage = onShowUsage

        let c = config.wrappedValue
        _displayPrefix = State(initialValue: c.display_prefix)
        _apiKey = State(initialValue: c.api_key)
        _refreshIntervalIdx = State(initialValue: INTERVAL_PRESETS.firstIndex(where: { $0.seconds == c.refresh_interval }) ?? 1)
        _topFontSize = State(initialValue: Double(c.top_font_size))
        _botFontSize = State(initialValue: Double(c.bottom_font_size))
        _warnThresholdStr = State(initialValue: String(c.warn_threshold))
        _criticalThresholdStr = State(initialValue: String(c.critical_threshold))
        _langIdx = State(initialValue: LANG_OPTS.firstIndex(where: { $0.0 == c.lang }) ?? 0)
        _autoStart = State(initialValue: autoStartEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题区
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                Text("DeepSeek Balance")
                    .font(.system(size: 20, weight: .semibold))
                Text("v\(APP_VERSION)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 22)

            // 数据卡片
            HStack(spacing: 12) {
                DashboardCard(
                    title: t("余额显示"),
                    value: config.api_key.isEmpty ? "---" : balanceText,
                    icon: "wallet.pass.fill",
                    color: .blue,
                    action: { NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/top_up?_gl=1")!) }
                )
                DashboardCard(
                    title: t("今日使用"),
                    value: config.api_key.isEmpty ? "---" : todayUsedText,
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    action: { onShowUsage() }
                )
            }
            .padding(.bottom, 22)


            // 设置卡片
            VStack(spacing: 10) {
                // API 连接
                SettingsCard {
                    HStack(spacing: 6) {
                        Text(t("前缀"))
                            .frame(width: 50, alignment: .leading)
                            .font(.subheadline)
                        TextField("API", text: $displayPrefix)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Spacer()
                        Text(t("刷新"))
                            .font(.subheadline)
                        Picker("", selection: $refreshIntervalIdx) {
                            ForEach(Array(INTERVAL_PRESETS.enumerated()), id: \.offset) { i, p in
                                Text(p.label).tag(i)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }
                    Divider()
                    HStack(spacing: 6) {
                        Text("Key")
                            .frame(width: 50, alignment: .leading)
                            .font(.subheadline)
                        if showKey {
                            TextField("sk-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye" : "eye.slash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 界面偏好
                SettingsCard {
                    HStack(spacing: 8) {
                        Text(t("上字号"))
                            .frame(width: 50, alignment: .leading)
                            .font(.subheadline)
                        Slider(value: $topFontSize, in: 7...14, step: 1)
                        Text("\(Int(topFontSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    }
                    Divider()
                    HStack(spacing: 8) {
                        Text(t("下字号"))
                            .frame(width: 50, alignment: .leading)
                            .font(.subheadline)
                        Slider(value: $botFontSize, in: 5...10, step: 1)
                        Text("\(Int(botFontSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    }
                    Divider()
                    HStack(spacing: 8) {
                        Text(t("语言"))
                            .frame(width: 50, alignment: .leading)
                            .font(.subheadline)
                        Picker("", selection: $langIdx) {
                            ForEach(Array(LANG_OPTS.enumerated()), id: \.offset) { i, v in
                                Text(v.1).tag(i)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 90)
                        Spacer()
                    }
                }

                // 预警 + 系统
                SettingsCard {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.orange)
                            .frame(width: 50, alignment: .leading)
                        Text(t("警告线"))
                            .font(.subheadline)
                        TextField("", text: $warnThresholdStr)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Text("¥")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Divider()
                    HStack(spacing: 6) {
                        Spacer().frame(width: 50)
                        Text(t("严重线"))
                            .font(.subheadline)
                        TextField("", text: $criticalThresholdStr)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Text("¥")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Divider()
                    Toggle(isOn: $autoStart) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.subheadline)
                            Text(t("开机自启"))
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: autoStart) { newValue in
                        if newValue != autoStartEnabled { onToggleAutoStart() }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(t("多端同步说明文字"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 10)

            Spacer(minLength: 12)

            // 底栏
            Divider()
            HStack {
                Button(action: { onCheckUpdate() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text(t("检查更新"))
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: { NSWorkspace.shared.open(URL(string: "https://github.com/MoYuRan1992")!) }) {
                    Text("by MoYuRan")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(t("保存设置")) { saveAndClose() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(width: 380)
        .background(.ultraThinMaterial)
    }

    func saveAndClose() {
        if let v = Double(warnThresholdStr), v > 0 { config.warn_threshold = v }
        if let v = Double(criticalThresholdStr), v > 0 { config.critical_threshold = v }
        if !displayPrefix.isEmpty, displayPrefix.count <= 8 { config.display_prefix = displayPrefix }
        let kv = apiKey.trimmingCharacters(in: .whitespaces)
        if !kv.isEmpty { config.api_key = kv }
        if refreshIntervalIdx >= 0, refreshIntervalIdx < INTERVAL_PRESETS.count {
            config.refresh_interval = INTERVAL_PRESETS[refreshIntervalIdx].seconds
        }
        config.top_font_size = Int(topFontSize)
        config.bottom_font_size = Int(botFontSize)
        if langIdx >= 0, langIdx < LANG_OPTS.count {
            config.lang = LANG_OPTS[langIdx].0
        }
        onSave()
    }

    func resetToDefaults() {
        displayPrefix = "API"
        apiKey = ""
        refreshIntervalIdx = 1
        topFontSize = 10
        botFontSize = 7
        warnThresholdStr = "5"
        criticalThresholdStr = "20"
        langIdx = 0
        autoStart = false
    }
}

// MARK: - 毛玻璃卡片（Dashboard 风格）

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .onTapGesture { action?() }
    }
}

// MARK: - 设置卡片

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 5) {
            content
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

// MARK: - 窗口控制器

class SettingsWindowController: NSWindowController {
    convenience init(config: Binding<Config>, balanceText: String, todayUsedText: String, autoStartEnabled: Bool, onToggleAutoStart: @escaping () -> Void, onSave: @escaping () -> Void, onCheckUpdate: @escaping () -> Void, onShowUsage: @escaping () -> Void) {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = t("设置标题")
        win.center()
        win.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: SettingsView(
            config: config,
            balanceText: balanceText,
            todayUsedText: todayUsedText,
            autoStartEnabled: autoStartEnabled,
            onToggleAutoStart: onToggleAutoStart,
            onSave: { onSave(); win.close() },
            onCheckUpdate: onCheckUpdate,
            onShowUsage: onShowUsage
        ))
        hostingView.autoresizingMask = [.width, .height]
        win.contentView = hostingView

        self.init(window: win)
    }
}
