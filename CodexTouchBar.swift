import Cocoa
import Darwin

// MARK: - Private API (DFRFoundation)

let dfrHandle = dlopen(
    "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)

typealias SetPresenceFn = @convention(c) (CFString, Bool) -> Void
let setPresence: SetPresenceFn? = dfrHandle.flatMap {
    dlsym($0, "DFRElementSetControlStripPresenceForIdentifier")
        .map { unsafeBitCast($0, to: SetPresenceFn.self) }
}

typealias PostEventFn1 = @convention(c) (CGEvent?) -> Void
let postActivity1: PostEventFn1? = dfrHandle.flatMap {
    dlsym($0, "DFRFoundationPostEventWithMouseActivity")
        .map { unsafeBitCast($0, to: PostEventFn1.self) }
}

let presentSel = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")

// MARK: - Status style

typealias StatusStyle = (color: NSColor, icon: String, label: String)

func statusStyle(_ raw: String) -> StatusStyle {
    let lower = raw.lowercased()
    if lower.contains("waiting") || lower.contains("approval") {
        return (.systemRed, "exclamationmark.triangle.fill", "🙋 求大佬放行")
    }
    if lower.contains("bash") || lower.contains("command") || lower.contains("shell") {
        return (.systemOrange, "terminal.fill", "💻 命令行渡劫")
    }
    if lower.contains("patch") || lower.contains("edit") || lower.contains("write") {
        return (.systemBlue, "pencil.and.outline", "✍️ 和 BUG 对线")
    }
    if lower.contains("tool") || lower.contains("run") {
        return (.systemPurple, "hammer.fill", "🔨 花式整活")
    }
    if lower.contains("think") || lower.contains("prompt") || lower.contains("working") {
        return (.systemPurple, "brain.head.profile", "🤯 脑细胞燃烧中")
    }
    return (.systemGreen, "sparkles", "🐟 原地摆烂")
}

// MARK: - Touch Bar

let statusID = NSTouchBarItem.Identifier("com.codex.status")

class TB: NSObject, NSTouchBarDelegate {
    var btn: NSButton?

    func makeTouchBar() -> NSTouchBar {
        let tb = NSTouchBar()
        tb.delegate = self
        tb.defaultItemIdentifiers = [statusID]
        tb.customizationIdentifier = .init("com.codex.touchbar")
        tb.customizationAllowedItemIdentifiers = [statusID]
        return tb
    }

    func touchBar(_ tb: NSTouchBar, makeItemForIdentifier id: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard id == statusID else { return nil }
        let item = NSCustomTouchBarItem(identifier: id)
        item.customizationLabel = "Codex Status"

        let b = NSButton(title: "", image: NSImage(), target: self, action: #selector(tap))
        b.imagePosition = .imageLeading
        b.bezelStyle = .rounded
        b.imageHugsTitle = true
        b.imageScaling = .scaleProportionallyDown
        item.view = b
        self.btn = b

        refreshButton()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshButton()
        }
        return item
    }

    func refreshButton() {
        let p = NSString(string: "~/.codex/touchbar_status.txt").expandingTildeInPath
        let raw = (try? String(contentsOfFile: p, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let style = statusStyle(raw)

        DispatchQueue.main.async { [weak self] in
            guard let b = self?.btn else { return }
            b.image = NSImage(systemSymbolName: style.icon, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
            b.attributedTitle = NSAttributedString(
                string: style.label,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.white
                ]
            )
            b.bezelColor = style.color
            b.sizeToFit()
            b.frame.size.width = min(max(b.frame.size.width, 130), 260)
        }
    }

    @objc func tap() {
        for b in ["com.googlecode.iterm2", "com.apple.Terminal", "dev.warp.Warp-Stable"] {
            if let a = NSRunningApplication.runningApplications(withBundleIdentifier: b).first {
                a.activate()
                return
            }
        }
    }
}

// MARK: - App

let tb = TB()
let touchBar = tb.makeTouchBar()

let displayReconfCallback: CGDisplayReconfigurationCallBack = { _, flags, _ in
    if flags.contains(.setModeFlag) || flags.contains(.addFlag) {
        DispatchQueue.main.async { (NSApp.delegate as? AD)?.presentTouchBar() }
    }
}

func isDisplayAwake() -> Bool {
    CGDisplayIsAsleep(CGMainDisplayID()) == 0
}

class AD: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        presentTouchBar()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            if isDisplayAwake() {
                self?.presentTouchBar()
            }
        }

        CGDisplayRegisterReconfigurationCallback(displayReconfCallback, nil)

        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if isDisplayAwake(), let fn = postActivity1 {
                fn(nil)
            }
        }
    }

    func presentTouchBar() {
        setPresence?("com.codex.status" as CFString, true)
        if let method = class_getClassMethod(NSTouchBar.self, presentSel) {
            typealias Fn = @convention(c) (AnyClass, Selector, NSTouchBar, Int, String) -> Void
            let fn = unsafeBitCast(method_getImplementation(method), to: Fn.self)
            fn(NSTouchBar.self, presentSel, touchBar, 0, "com.codex.status")
        }
    }
}

let delegate = AD()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
