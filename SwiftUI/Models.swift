import Foundation

struct Config: Codable {
    var api_key: String = ""
    var display_prefix: String = "API"
    var top_font_size: Int = 10
    var bottom_font_size: Int = 7
    var danger_threshold: Double = 5
    var warn_threshold: Double = 20
    var refresh_interval: Int = 300
    var lang: String = "zh-CN"
}

struct BalanceInfo: Codable {
    var currency: String = "CNY"
    var total_balance: Double = 0
    var topped_up_balance: Double = 0
    var granted_balance: Double = 0
}

struct CacheData: Codable {
    var balance: BalanceInfo?
    var ts: TimeInterval = 0
    var today_date: String = ""
    var prev_total: Double = 0
    var today_used: Double = 0
}

struct DailyEntry: Codable {
    var date: String
    var used: Double
}

let INTERVAL_PRESETS: [(key: String, seconds: Int)] = [
    ("interval_1min", 60),
    ("interval_5min", 300),
    ("interval_10min", 600),
    ("interval_30min", 1800),
    ("interval_1hour", 3600)
]

let LANG_OPTS = [
    ("zh-CN", "简体中文"),
    ("en", "English"),
    ("ru", "Русский")
]
