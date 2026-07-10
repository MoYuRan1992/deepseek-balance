import Foundation

let APP_VERSION = "1.0"
let BALANCE_API = "https://api.deepseek.com/user/balance"

let HOME = FileManager.default.homeDirectoryForCurrentUser
let CONFIG_DIR = HOME.appendingPathComponent(".config/deepseek-balance")
let CONFIG_FILE = CONFIG_DIR.appendingPathComponent("config.json")
let CACHE_FILE = CONFIG_DIR.appendingPathComponent("cache.json")
let DAILY_FILE = CONFIG_DIR.appendingPathComponent("daily_usage.json")
let LOG_FILE = HOME.appendingPathComponent("Library/Logs/deepseek-balance.log")
let LAUNCHD_PLIST = HOME.appendingPathComponent("Library/LaunchAgents/com.deepseek.balance.plist")
let LOCK_FILE = CONFIG_DIR.appendingPathComponent(".lock")
