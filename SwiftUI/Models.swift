import Foundation

struct Config: Codable {
    var api_key: String = ""
    var display_prefix: String = "API"
    var top_font_size: Int = 10
    var bottom_font_size: Int = 7
    var warn_threshold: Double = 5
    var critical_threshold: Double = 20
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

let INTERVAL_PRESETS: [(label: String, seconds: Int)] = [
    ("1分钟", 60), ("5分钟", 300), ("10分钟", 600), ("30分钟", 1800), ("1小时", 3600)
]

let TOP_FONT_OPTS = [7, 8, 9, 10, 11, 12, 13, 14]
let BOT_FONT_OPTS = [5, 6, 7, 8, 9, 10]

let LANG_OPTS = [
    ("zh-CN", "简体中文"),
    ("en", "English"),
    ("ru", "Русский")
]
