import SwiftUI

struct UpdatePromptView: View {
    let newVersion: String
    let currentVersion: String
    let releaseNotes: String?
    var onDownload: () -> Void
    var onManualCheck: () -> Void
    var onDismiss: () -> Void

    @State private var isDownloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                Text(t("发现新版本", ["version": newVersion]))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("\(t("当前版本:"))")
                            .foregroundColor(.secondary)
                        Text(currentVersion)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 8)

                    if let notes = releaseNotes, !notes.isEmpty {
                        Text(t("更新内容"))
                            .font(.headline)
                            .padding(.top, 4)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Text(t("更新说明文字"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Button(t("btn_稍后")) { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                Spacer()

                Button(t("手动查看")) { onManualCheck(); onDismiss() }

                Button(action: {
                    isDownloading = true
                    onDownload()
                }) {
                    HStack(spacing: 4) {
                        if isDownloading {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                        }
                        Text(t("立即更新"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isDownloading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: false)
        .background(.ultraThinMaterial)
    }
}

class UpdateWindowController: NSWindowController {
    convenience init(newVersion: String, currentVersion: String, releaseNotes: String?, onDownload: @escaping () -> Void, onManualCheck: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = t("软件更新")
        win.center()
        win.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: UpdatePromptView(
            newVersion: newVersion,
            currentVersion: currentVersion,
            releaseNotes: releaseNotes,
            onDownload: onDownload,
            onManualCheck: onManualCheck,
            onDismiss: { [weak win] in win?.close(); onDismiss() }
        ))
        hostingView.autoresizingMask = [.width, .height]
        win.contentView = hostingView

        self.init(window: win)
    }
}
