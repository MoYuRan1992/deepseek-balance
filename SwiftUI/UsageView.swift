import SwiftUI

struct UsageView: View {
    let balance: BalanceInfo?
    let todayUsed: Double
    let history: [DailyEntry]
    var onReset: () -> Void

    var body: some View {
        let sorted = history.sorted { $0.date > $1.date }
        let recent30 = Array(sorted.prefix(30))
        let last30Total = recent30.reduce(0) { $0 + $1.used }
        let totalUsed = history.reduce(0) { $0 + $1.used }
        let avgDaily = history.count > 0 ? totalUsed / Double(history.count) : 0

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // 充值余额
                    topUpCard
                        .padding(.horizontal, 20)

                    // 消费统计
                    HStack(spacing: 10) {
                        statCard(title: t("近30天消费"), value: "¥\(String(format: "%.2f", last30Total))", color: .orange)
                        statCard(title: t("今日消费"), value: "¥\(String(format: "%.2f", todayUsed))", color: .red)
                        statCard(title: t("日均消费"), value: "¥\(String(format: "%.2f", avgDaily))", color: .gray)
                    }
                    .padding(.horizontal, 20)

                    // 消费明细
                    detailTable(recent30: recent30)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 8)
                }
                .padding(.top, 16)
            }

            Divider()
            HStack {
                Button(action: onReset) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash").font(.caption)
                        Text(t("btn_重置统计"))
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain).foregroundColor(.secondary)

                Spacer()

                Button(action: { NSWorkspace.shared.open(URL_USAGE_DETAIL) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "safari").font(.caption)
                        Text(t("查看完整用量"))
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain).foregroundColor(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        .frame(width: 380)
        .frame(minHeight: 400)
        .background(.ultraThinMaterial)
    }

    // MARK: - 充值余额卡片

    var topUpCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("充值余额"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(formatBalance(balance?.topped_up_balance))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "creditcard.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(red: 0.25, green: 0.75, blue: 0.45).opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - 统计卡片

    func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - 明细表

    func detailTable(recent30: [DailyEntry]) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.caption).foregroundColor(.secondary)
                Text(t("消费明细"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            VStack(spacing: 0) {
                HStack {
                    Text(t("日期"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Spacer()
                    Text(t("消费金额"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                Divider()

                if recent30.isEmpty {
                    Text(t("暂无使用记录"))
                        .font(.subheadline).foregroundColor(.secondary)
                        .padding(.vertical, 24).frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(recent30.enumerated()), id: \.offset) { i, entry in
                        HStack {
                            Text(entry.date)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 120, alignment: .leading)
                            Spacer()
                            Text("¥\(String(format: "%.4f", entry.used))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(entry.used > 0 ? .primary : .secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        if i < recent30.count - 1 { Divider() }
                    }
                }
            }
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        }
    }

    func formatBalance(_ val: Double?) -> String {
        guard let v = val else { return "---" }
        return "¥\(String(format: "%.2f", v))"
    }
}
