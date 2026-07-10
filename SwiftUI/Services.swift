import Foundation

// MARK: - 日志

func appLog(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    try? FileManager.default.createDirectory(at: LOG_FILE.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let handle = try? FileHandle(forWritingTo: LOG_FILE) {
        handle.seekToEndOfFile()
        handle.write(("[\(ts)] \(msg)\n").data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? "[\(ts)] \(msg)\n".write(to: LOG_FILE, atomically: true, encoding: .utf8)
    }
}

// MARK: - 翻译

var localeData: [String: String] = [:]

func loadLocale(_ lang: String) {
    guard let path = Bundle.main.path(forResource: lang, ofType: "json", inDirectory: "locales"),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
        localeData = [:]
        return
    }
    localeData = dict
}

func t(_ key: String, _ args: [String: String] = [:]) -> String {
    var text = localeData[key] ?? key
    for (k, v) in args { text = text.replacingOccurrences(of: "{\(k)}", with: v) }
    return text
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
    readJSON(CONFIG_FILE, or: Config())
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

func acquireLock() -> Bool {
    ensureDir(CONFIG_DIR)
    if FileManager.default.fileExists(atPath: LOCK_FILE.path) {
        if let pidStr = try? String(contentsOf: LOCK_FILE, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)),
           kill(pid, 0) == 0 {
            return false
        }
    }
    try? "\(ProcessInfo.processInfo.processIdentifier)".write(to: LOCK_FILE, atomically: true, encoding: .utf8)
    return true
}

func releaseLock() {
    try? FileManager.default.removeItem(at: LOCK_FILE)
}

// MARK: - API 请求

func queryBalance(apiKey: String) async throws -> BalanceInfo {
    var req = URLRequest(url: URL(string: BALANCE_API)!, timeoutInterval: 10)
    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, _) = try await URLSession.shared.data(for: req)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let available = json["is_available"] as? Bool, available,
          let infos = json["balance_infos"] as? [[String: Any]],
          let info = infos.first else {
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: t("错误_响应格式")])
    }
    return BalanceInfo(
        currency: info["currency"] as? String ?? "CNY",
        total_balance: Double(info["total_balance"] as? String ?? "0") ?? 0,
        topped_up_balance: Double(info["topped_up_balance"] as? String ?? "0") ?? 0,
        granted_balance: Double(info["granted_balance"] as? String ?? "0") ?? 0
    )
}
