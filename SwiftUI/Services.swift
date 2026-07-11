import Foundation

// MARK: - 日志

private let logQueue = DispatchQueue(label: "com.deepseek.balance.log")

private var logDirCreated = false

func appLog(_ msg: String) {
    logQueue.async {
        let ts = ISO8601DateFormatter().string(from: Date())
        if !logDirCreated {
            try? FileManager.default.createDirectory(at: LOG_FILE.deletingLastPathComponent(), withIntermediateDirectories: true)
            logDirCreated = true
        }
        if let handle = try? FileHandle(forWritingTo: LOG_FILE) {
            handle.seekToEndOfFile()
            handle.write(("[\(ts)] \(msg)\n").data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? "[\(ts)] \(msg)\n".write(to: LOG_FILE, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - 翻译

var localeData: [String: String] = [:]
private let localeLock = NSLock()

func loadLocale(_ lang: String) {
    guard let path = Bundle.main.path(forResource: lang, ofType: "json", inDirectory: "locales"),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
        return
    }
    localeLock.lock()
    localeData = dict
    localeLock.unlock()
}

func t(_ key: String, _ args: [String: String] = [:]) -> String {
    localeLock.lock()
    let text = localeData[key] ?? key
    localeLock.unlock()
    var result = text
    for (k, v) in args { result = result.replacingOccurrences(of: "{\(k)}", with: v) }
    return result
}

// MARK: - 文件 I/O

func ensureDir(_ url: URL) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func readJSON<T: Decodable>(_ url: URL, or fallback: T) -> T {
    guard let data = try? Data(contentsOf: url),
          let obj = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
    return obj
}

func writeJSON<T: Encodable>(_ obj: T, to url: URL) {
    ensureDir(url.deletingLastPathComponent())
    if let data = try? JSONEncoder().encode(obj) { try? data.write(to: url) }
}

// MARK: - 配置读写

func loadConfig() -> Config {
    migrateConfigIfNeeded()
    var config = readJSON(CONFIG_FILE, or: Config())
    if config.danger_threshold >= config.warn_threshold {
        config.danger_threshold = max(config.warn_threshold / 2, 0.01)
    }
    return config
}

func migrateConfigIfNeeded() {
    guard let data = try? Data(contentsOf: CONFIG_FILE),
          var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    var changed = false
    if let old = json.removeValue(forKey: "warn_threshold"), json["danger_threshold"] == nil {
        json["danger_threshold"] = old
        changed = true
    }
    if let old = json.removeValue(forKey: "critical_threshold"), json["warn_threshold"] == nil {
        json["warn_threshold"] = old
        changed = true
    }
    if changed, let newData = try? JSONSerialization.data(withJSONObject: json) {
        try? newData.write(to: CONFIG_FILE)
    }
}

func saveConfig(_ config: Config) {
    writeJSON(config, to: CONFIG_FILE)
}

// MARK: - 缓存读写

func loadCache() -> CacheData {
    readJSON(CACHE_FILE, or: CacheData())
}

func saveCache(_ cache: CacheData) {
    writeJSON(cache, to: CACHE_FILE)
}

// MARK: - 每日使用量

func loadDailyUsage() -> [DailyEntry] {
    readJSON(DAILY_FILE, or: [])
}

func saveDailyUsage(_ entries: [DailyEntry]) {
    writeJSON(Array(entries.suffix(90)), to: DAILY_FILE)
}

// MARK: - 防多开

private var lockFD: Int32 = -1

func acquireLock() -> Bool {
    ensureDir(CONFIG_DIR)
    let fd = open(LOCK_FILE.path, O_CREAT | O_RDWR, 0o644)
    guard fd >= 0 else { return false }
    if flock(fd, LOCK_EX | LOCK_NB) != 0 {
        close(fd)
        return false
    }
    lockFD = fd
    return true
}

func releaseLock() {
    if lockFD >= 0 { close(lockFD); lockFD = -1 }
    try? FileManager.default.removeItem(at: LOCK_FILE)
}

// MARK: - API 请求

func queryBalance(apiKey: String) async throws -> BalanceInfo {
    guard let url = URL(string: BALANCE_API) else {
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: t("错误_无效地址")])
    }
    var req = URLRequest(url: url, timeoutInterval: 10)
    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: req)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        throw NSError(domain: "", code: code, userInfo: [NSLocalizedDescriptionKey: "\(t("错误_服务器")) (\(code))"])
    }
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let available = json["is_available"] as? Bool, available,
          let infos = json["balance_infos"] as? [[String: Any]],
          let info = infos.first else {
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: t("错误_响应格式")])
    }
    return BalanceInfo(
        currency: info["currency"] as? String ?? "CNY",
        total_balance: parseBalance(info["total_balance"]),
        topped_up_balance: parseBalance(info["topped_up_balance"]),
        granted_balance: parseBalance(info["granted_balance"])
    )
}

private func parseBalance(_ value: Any?) -> Double {
    if let s = value as? String { return Double(s) ?? 0 }
    if let n = value as? NSNumber { return n.doubleValue }
    return 0
}
