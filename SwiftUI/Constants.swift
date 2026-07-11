import Foundation

let APP_VERSION = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
let BALANCE_API = "https://api.deepseek.com/user/balance"

let URL_PLATFORM = URL(string: "https://platform.deepseek.com/")!
let URL_CHAT = URL(string: "https://chat.deepseek.com/")!
let URL_GITHUB_LATEST = URL(string: "https://api.github.com/repos/MoYuRan1992/deepseek-balance/releases/latest")!
let URL_GITHUB_RELEASE = URL(string: "https://github.com/MoYuRan1992/deepseek-balance/releases/latest")!
let URL_GITHUB_AUTHOR = URL(string: "https://github.com/MoYuRan1992")!
let URL_TOPUP = URL(string: "https://platform.deepseek.com/top_up")!
let URL_USAGE_DETAIL = URL(string: "https://platform.deepseek.com/usage_details")!

let HOME = FileManager.default.homeDirectoryForCurrentUser
let CONFIG_DIR = HOME.appendingPathComponent(".config/deepseek-balance")
let CONFIG_FILE = CONFIG_DIR.appendingPathComponent("config.json")
let CACHE_FILE = CONFIG_DIR.appendingPathComponent("cache.json")
let DAILY_FILE = CONFIG_DIR.appendingPathComponent("daily_usage.json")
let LOG_FILE = HOME.appendingPathComponent("Library/Logs/deepseek-balance.log")
let LAUNCHD_PLIST = HOME.appendingPathComponent("Library/LaunchAgents/com.deepseek.balance.plist")
let LOCK_FILE = CONFIG_DIR.appendingPathComponent(".lock")
