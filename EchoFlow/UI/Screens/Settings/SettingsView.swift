//
//  SettingsView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import SwiftData
import AppKit
import Carbon

/// 设置标签页
enum SettingsTab: String, CaseIterable {
    case general = "通用"
    case rules = "规则"
    case shortcuts = "快捷键"
    case subscription = "订阅"
    case dataManagement = "数据管理"
    case about = "关于"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .rules: return "list.bullet.rectangle"
        case .shortcuts: return "keyboard"
        case .subscription: return "star.fill"
        case .dataManagement: return "externaldrive"
        case .about: return "info.circle"
        }
    }
}

/// 设置视图
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("displayMode") private var displayModeRaw: String = "panel"
    @AppStorage("dockPosition") private var dockPositionRaw: String = "bottom"
    @AppStorage("autoHide") private var autoHide: Bool = true
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = false
    @AppStorage("windowHeight") private var windowHeight: Double = 400.0
    @AppStorage("copyBehavior") private var copyBehaviorRaw: String = "copyToPasteboard"
    @AppStorage("historyRetentionPeriod") private var historyRetentionPeriodRaw: String = HistoryRetentionPeriod.oneWeek.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showStatusBarIcon") private var showStatusBarIcon: Bool = true
    @AppStorage("enableDeduplication") private var enableDeduplication: Bool = true
    @AppStorage("deduplicationWindow") private var deduplicationWindow: Double = 2.0
    @AppStorage("enableLinkPreview") private var enableLinkPreview: Bool = true
    @AppStorage("enableCoolMode") private var enableCoolMode: Bool = false
    @AppStorage("checkForUpdatesOnLaunch") private var checkForUpdatesOnLaunch: Bool = true
    @AppStorage("hotKeyKeyCode") private var hotKeyKeyCode: Int = 0x0B // B
    @AppStorage("hotKeyModifiersRaw") private var hotKeyModifiersRaw: Int = Int(cmdKey)
    @AppStorage("cardFontName") private var cardFontName: String = "SF Pro Text"
    @AppStorage("cardFontSize") private var cardFontSize: Double = 12.0
    
    var hotKeyModifiers: UInt32 {
        get { UInt32(hotKeyModifiersRaw) }
        set { hotKeyModifiersRaw = Int(newValue) }
    }
    
    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .panel }
        set { displayModeRaw = newValue.rawValue }
    }
    
    @State private var selectedTab: SettingsTab = .general
    @State private var showingHotKeyPicker = false
    
    init() {
        // 从 AppStorage 加载停靠位置
        if let savedPosition = UserDefaults.standard.string(forKey: "dockPosition"),
           let position = DockPosition(rawValue: savedPosition) {
            WindowManager.shared.dockPosition = position
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // 左侧导航栏
            sidebarView
        } detail: {
            // 右侧内容区
            detailView
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(.ultraThinMaterial)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .frame(width: 200)
        .navigationTitle("设置")
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(
                displayModeRaw: $displayModeRaw,
                dockPositionRaw: $dockPositionRaw,
                autoHide: $autoHide,
                alwaysOnTop: $alwaysOnTop,
                windowHeight: $windowHeight,
                copyBehaviorRaw: $copyBehaviorRaw,
                historyRetentionPeriodRaw: $historyRetentionPeriodRaw,
                launchAtLogin: $launchAtLogin,
                showStatusBarIcon: $showStatusBarIcon,
                enableCoolMode: $enableCoolMode,
                cardFontName: $cardFontName,
                cardFontSize: $cardFontSize
            )
        case .rules:
            RulesSettingsView(
                enableDeduplication: $enableDeduplication,
                deduplicationWindow: $deduplicationWindow,
                enableLinkPreview: $enableLinkPreview
            )
        case .shortcuts:
            ShortcutsSettingsView(
                hotKeyKeyCode: $hotKeyKeyCode,
                hotKeyModifiersRaw: $hotKeyModifiersRaw
            )
        case .subscription:
            SubscriptionSettingsView()
        case .dataManagement:
            DataManagementSettingsView()
        case .about:
            AboutSettingsView(checkForUpdatesOnLaunch: $checkForUpdatesOnLaunch)
        }
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @Binding var displayModeRaw: String
    @Binding var dockPositionRaw: String
    @Binding var autoHide: Bool
    @Binding var alwaysOnTop: Bool
    @Binding var windowHeight: Double
    @Binding var copyBehaviorRaw: String
    @Binding var historyRetentionPeriodRaw: String
    @Binding var launchAtLogin: Bool
    @Binding var showStatusBarIcon: Bool
    @Binding var enableCoolMode: Bool
    @Binding var cardFontName: String
    @Binding var cardFontSize: Double
    
    @State private var accessibilityPermissionGranted: Bool = false
    @State private var availableFonts: [String] = []
    
    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .panel }
        set { displayModeRaw = newValue.rawValue }
    }
    
    var dockPosition: DockPosition {
        get { DockPosition(rawValue: dockPositionRaw) ?? .bottom }
        set { dockPositionRaw = newValue.rawValue }
    }
    
    var historyRetentionPeriod: HistoryRetentionPeriod {
        get { HistoryRetentionPeriod(rawValue: historyRetentionPeriodRaw) ?? .oneWeek }
        set { historyRetentionPeriodRaw = newValue.rawValue }
    }
    
    var body: some View {
        Form {
            Section("显示模式") {
                Picker("模式", selection: Binding(
                    get: { displayMode },
                    set: { newMode in
                        displayModeRaw = newMode.rawValue
                        WindowManager.shared.displayMode = newMode
                        UserDefaults.standard.set(newMode.rawValue, forKey: "displayMode")
                    }
                )) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("选择窗口的显示方式")
            }
            
            Section("窗口设置") {
                // 面板模式下显示停靠位置
                if displayMode == .panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("停靠位置")
                        
                        DockPositionPicker(selectedPosition: Binding(
                            get: { dockPosition },
                            set: { dockPositionRaw = $0.rawValue }
                        ))
                    }
                    .onChange(of: dockPosition) { oldValue, newValue in
                        // 更新 WindowManager 的停靠位置
                        WindowManager.shared.dockPosition = newValue
                        // 保存到 UserDefaults
                        UserDefaults.standard.set(newValue.rawValue, forKey: "dockPosition")
                        print("✅ 停靠位置已更新为: \(newValue.rawValue)")
                        
                        // 重新创建面板以应用新的布局
                        Task { @MainActor in
                            let container = EchoFlowApp.sharedModelContainer
                            let rootView = RootView()
                                .modelContainer(container)
                            
                            WindowManager.shared.createPanel(with: rootView)
                            
                            // 如果面板可见，重新显示
                            if WindowManager.shared.isVisible {
                                WindowManager.shared.showPanel()
                            }
                        }
                    }
                    
                    Toggle("失去焦点时自动隐藏", isOn: $autoHide)
                        .help("面板失去焦点时自动隐藏")
                }
                
                // 窗口模式下显示窗口高度和置顶选项
                if displayMode == .window {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("窗口高度: \(Int(windowHeight)) px")
                            .font(.subheadline)
                        
                        Slider(value: $windowHeight, in: 300...900, step: 50)
                            .onChange(of: windowHeight) { _, _ in
                                WindowManager.shared.updateWindowSize()
                            }
                    }
                    
                    Toggle("窗口置顶", isOn: $alwaysOnTop)
                        .help("窗口始终显示在其他窗口上方")
                        .onChange(of: alwaysOnTop) { _, newValue in
                            WindowManager.shared.isAlwaysOnTop = newValue
                        }
                }
                
                Picker("复制行为", selection: $copyBehaviorRaw) {
                    Text("仅复制到粘贴板").tag("copyToPasteboard")
                    Text("复制并粘贴到当前应用").tag("copyToCurrentApp")
                }
                .pickerStyle(.menu)
            }
            
            Section("视觉效果") {
                Toggle(isOn: $enableCoolMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("炫酷模式")
                        Text("启用卡片 3D 悬停效果、动态光影和视差动画")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .help("开启后，鼠标悬停在卡片上时会显示 3D 倾斜和光影效果")
                .onChange(of: enableCoolMode) { _, newValue in
                    // 通知卡片列表更新以清理或应用特效
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CoolModeChanged"),
                        object: nil,
                        userInfo: ["enabled": newValue]
                    )
                }
            }
            
            Section("卡片字体设置") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("字体", selection: $cardFontName) {
                        ForEach(availableFonts, id: \.self) { fontName in
                            Text(fontName).tag(fontName)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        loadAvailableFonts()
                    }
                    .onChange(of: cardFontName) { _, _ in
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CardFontChanged"),
                            object: nil
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("字体大小: \(Int(cardFontSize))")
                            .font(.subheadline)
                        Slider(value: $cardFontSize, in: 8...20, step: 1)
                            .onChange(of: cardFontSize) { _, _ in
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("CardFontChanged"),
                                    object: nil
                                )
                            }
                    }
                }
            }
            
            Section("历史记录") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("历史记录保留时间")
                        Spacer()
                        if historyRetentionPeriod.isProFeature {
                            Text("Pro")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.3))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Picker("", selection: Binding(
                        get: { historyRetentionPeriod },
                        set: { historyRetentionPeriodRaw = $0.rawValue }
                    )) {
                        ForEach(HistoryRetentionPeriod.allCases, id: \.self) { period in
                            Text(period.displayName)
                                .tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: historyRetentionPeriod) { oldValue, newValue in
                        print("✅ 历史记录保留时间已更新为: \(newValue.displayName)")
                        // 触发清理任务
                        HistoryCleanupManager.shared.scheduleCleanup()
                    }
                    
                    Text("超过保留时间的记录将被自动删除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("启动设置") {
                Toggle("登录时自动启动", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        LaunchAtLoginManager.shared.isEnabled = newValue
                    }
                ))
                .help("系统登录时自动启动 EchoFlow")
                
                Toggle("显示状态栏图标", isOn: Binding(
                    get: { showStatusBarIcon },
                    set: { newValue in
                        showStatusBarIcon = newValue
                        // 通知 AppDelegate 更新状态栏图标
                        NotificationCenter.default.post(
                            name: NSNotification.Name("UpdateStatusBarIcon"),
                            object: nil,
                            userInfo: ["show": newValue]
                        )
                    }
                ))
                .help("在菜单栏显示 EchoFlow 图标")
            }
            
            Section("权限设置") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("辅助功能权限")
                            if accessibilityPermissionGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        Text(accessibilityPermissionGranted ? "已授权" : "未授权")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("用于自动粘贴功能（复制并粘贴到当前应用）")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(accessibilityPermissionGranted ? "重新检查" : "检查权限") {
                            checkAccessibilityPermission()
                        }
                        Button {
                            showPermissionHelp()
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .help("查看权限帮助")
                    }
                }
                .help("检查辅助功能权限状态，用于自动粘贴功能")
            }
            
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // 同步登录时自动启动状态
            launchAtLogin = LaunchAtLoginManager.shared.isEnabled
            // 检查辅助功能权限状态
            checkAccessibilityPermission()
            // 加载可用字体
            loadAvailableFonts()
        }
    }
    
    private func loadAvailableFonts() {
        let systemFonts = [
            "SF Pro Text",
            "SF Pro Display",
            "SF Mono",
            "Helvetica Neue",
            "Arial",
            "Times New Roman",
            "Courier New",
            "Menlo",
            "Monaco"
        ]
        
        // 获取系统所有可用字体
        let allFonts = NSFontManager.shared.availableFontFamilies
        let commonFonts = systemFonts.filter { allFonts.contains($0) }
        
        availableFonts = commonFonts + allFonts.filter { !systemFonts.contains($0) }.sorted()
    }
    
    private func positionDisplayName(_ position: DockPosition) -> String {
        switch position {
        case .bottom: return "底部"
        case .top: return "顶部"
        case .left: return "左侧"
        case .right: return "右侧"
        }
    }
    
    /// 检查辅助功能权限
    private func checkAccessibilityPermission() {
        let hasPermission = PasteSimulator.shared.checkAccessibilityPermission()
        accessibilityPermissionGranted = hasPermission
        
        if !hasPermission {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "EchoFlow 需要辅助功能权限来实现自动粘贴功能。\n\n请在系统设置中授予权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "查看帮助")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            case .alertSecondButtonReturn:
                showPermissionHelp()
            default:
                break
            }
        }
    }
    
    /// 显示权限帮助
    private func showPermissionHelp() {
        let helpText = """
        EchoFlow 权限帮助
        
        为什么需要权限？
        EchoFlow 使用 macOS 的 Accessibility API 来模拟键盘操作（⌘V），实现自动粘贴功能。这是 macOS 的安全机制，需要用户明确授权。
        
        如何授权？
        1. 点击"打开系统设置"按钮
        2. 在辅助功能列表中找到 EchoFlow
        3. 勾选授权
        4. 重新启动应用
        
        常见问题：
        • 授权后仍然提示需要权限？
          → 完全退出应用（⌘Q）后重新启动
        
        • 系统设置中找不到应用？
          → 点击列表下方的 ➕ 按钮手动添加
        
        • Debug 和 Release 版本权限混乱？
          → 两个版本使用不同的 Bundle ID，需要分别授权
        
        更多帮助：
        查看项目根目录的 PERMISSION_HELP.md 文件获取详细帮助。
        """
        
        let alert = NSAlert()
        alert.messageText = "权限帮助"
        alert.informativeText = helpText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "打开帮助文档")
        alert.addButton(withTitle: "关闭")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            // 尝试打开帮助文档
            if let projectDir = Bundle.main.bundlePath.components(separatedBy: "/Contents").first {
                let helpPath = (projectDir as NSString).deletingLastPathComponent + "/PERMISSION_HELP.md"
                let helpURL = URL(fileURLWithPath: helpPath)
                if FileManager.default.fileExists(atPath: helpPath) {
                    NSWorkspace.shared.open(helpURL)
                } else {
                    // 如果找不到文件，尝试在 Finder 中显示项目目录
                    let projectURL = URL(fileURLWithPath: (projectDir as NSString).deletingLastPathComponent)
                    NSWorkspace.shared.open(projectURL)
                }
            }
        default:
            break
        }
    }
}

// MARK: - Rules Settings

private struct RulesSettingsView: View {
    @Binding var enableDeduplication: Bool
    @Binding var deduplicationWindow: Double
    @Binding var enableLinkPreview: Bool
    
    var body: some View {
        Form {
            Section("去重设置") {
                Toggle("启用去重", isOn: $enableDeduplication)
                    .help("自动检测并过滤重复的剪贴板内容")
                
                if enableDeduplication {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("去重时间窗口: \(Int(deduplicationWindow)) 秒")
                        Slider(value: $deduplicationWindow, in: 0.5...10, step: 0.5)
                            .help("在指定时间窗口内，相同内容只保存一次")
                    }
                }
            }
            
            Section("链接设置") {
                Toggle("生成链接预览卡片", isOn: $enableLinkPreview)
                    .help("开启后，复制链接时会自动获取网站图标和网站名称；关闭后只显示默认图标和链接")
            }
            
            Section("颜色采样") {
                ColorSamplingAlgorithmPicker()
            }
            
            Section("过滤规则") {
                Text("密码管理器过滤（默认）")
                    .font(.headline)
                Text("自动过滤来自以下应用的剪贴板内容：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    FilterAppRow(name: "1Password", bundleID: "com.agilebits.onepassword7", isDefault: true)
                    FilterAppRow(name: "LastPass", bundleID: "com.lastpass.LastPass", isDefault: true)
                    FilterAppRow(name: "Keychain Access", bundleID: "com.apple.keychainaccess", isDefault: true)
                }
                .padding(.leading, 16)
                
                Divider()
                    .padding(.vertical, 8)
                
                // 用户添加的过滤应用
                UserFilteredAppsView()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct FilterAppRow: View {
    let name: String
    let bundleID: String
    let isDefault: Bool
    
    init(name: String, bundleID: String, isDefault: Bool = false) {
        self.name = name
        self.bundleID = bundleID
        self.isDefault = isDefault
    }
    
    var body: some View {
        HStack {
            Image(systemName: isDefault ? "lock.shield.fill" : "app.fill")
                .foregroundColor(isDefault ? .orange : .blue)
            Text(name)
            Spacer()
            Text("已启用")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - User Filtered Apps View

private struct UserFilteredAppsView: View {
    @State private var userFilteredApps: [AppInfo] = []
    @State private var showingAppPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("自定义过滤应用")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showingAppPicker = true
                }) {
                    Label("添加应用", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if userFilteredApps.isEmpty {
                Text("暂无自定义过滤应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(userFilteredApps) { app in
                        UserFilterAppRow(app: app, onDelete: {
                            removeApp(app)
                        })
                    }
                }
                .padding(.leading, 16)
            }
        }
        .onAppear {
            loadUserFilteredApps()
        }
        .onChange(of: showingAppPicker) { oldValue, newValue in
            if newValue {
                // 直接显示 NSOpenPanel，不使用 sheet
                showAppPicker()
                showingAppPicker = false  // 立即重置状态
            }
        }
    }
    
    private func loadUserFilteredApps() {
        guard let bundleIDs = UserDefaults.standard.stringArray(forKey: "userFilteredApps") else {
            userFilteredApps = []
            return
        }
        
        var apps: [AppInfo] = []
        for bundleID in bundleIDs {
            if let appInfo = getAppInfo(for: bundleID) {
                apps.append(appInfo)
            } else {
                // 如果无法获取应用信息，使用 Bundle ID 作为名称
                apps.append(AppInfo(bundleID: bundleID, name: bundleID))
            }
        }
        userFilteredApps = apps
    }
    
    private func getAppInfo(for bundleID: String) -> AppInfo? {
        // 尝试从运行中的应用中获取
        let runningApps = NSWorkspace.shared.runningApplications
        if let runningApp = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
            let name = runningApp.localizedName ?? bundleID
            let icon = runningApp.icon
            return AppInfo(bundleID: bundleID, name: name, icon: icon)
        }
        
        // 尝试从已安装的应用中获取
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = appURL.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return AppInfo(bundleID: bundleID, name: name, icon: icon)
        }
        
        return nil
    }
    
    private func addApp(_ app: AppInfo) {
        var bundleIDs = UserDefaults.standard.stringArray(forKey: "userFilteredApps") ?? []
        
        // 检查是否已存在
        if !bundleIDs.contains(app.id) {
            bundleIDs.append(app.id)
            UserDefaults.standard.set(bundleIDs, forKey: "userFilteredApps")
            loadUserFilteredApps()
            print("✅ 已添加过滤应用: \(app.name) (\(app.id))")
        }
    }
    
    private func removeApp(_ app: AppInfo) {
        var bundleIDs = UserDefaults.standard.stringArray(forKey: "userFilteredApps") ?? []
        bundleIDs.removeAll { $0 == app.id }
        UserDefaults.standard.set(bundleIDs, forKey: "userFilteredApps")
        loadUserFilteredApps()
        print("✅ 已移除过滤应用: \(app.name) (\(app.id))")
    }
    
    private func showAppPicker() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.application]
        openPanel.message = "选择要过滤的应用"
        openPanel.prompt = "选择"
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        // 获取设置窗口作为父窗口，使对话框显示在设置窗口前面
        let settingsWindow = WindowManager.shared.settingsWindow
        
        if let parentWindow = settingsWindow {
            // 使用 beginSheetModal，对话框会自动显示在父窗口前面
            openPanel.beginSheetModal(for: parentWindow) { response in
                if response == .OK, let url = openPanel.url {
                    if let appInfo = self.getAppInfo(from: url.path) {
                        self.addApp(appInfo)
                    }
                }
            }
        } else {
            // 如果没有设置窗口，使用普通 begin 方法
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    if let appInfo = self.getAppInfo(from: url.path) {
                        self.addApp(appInfo)
                    }
                }
            }
        }
    }
    
    private func getAppInfo(from appPath: String) -> AppInfo? {
        guard let bundle = Bundle(path: appPath),
              let bundleID = bundle.bundleIdentifier else {
            return nil
        }
        
        // 获取应用名称
        let name = bundle.localizedInfoDictionary?["CFBundleName"] as? String ??
                   bundle.infoDictionary?["CFBundleName"] as? String ??
                   (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        // 获取应用图标
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        
        return AppInfo(bundleID: bundleID, name: name, icon: icon)
    }
}

private struct UserFilterAppRow: View {
    let app: AppInfo
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue)
                    .frame(width: 16, height: 16)
            }
            
            Text(app.name)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
    }
}


// MARK: - Shortcuts Settings

private struct ShortcutsSettingsView: View {
    @Binding var hotKeyKeyCode: Int
    @Binding var hotKeyModifiersRaw: Int
    
    var hotKeyModifiers: UInt32 {
        get { UInt32(hotKeyModifiersRaw) }
        set { hotKeyModifiersRaw = Int(newValue) }
    }
    
    @State private var isRecording = false
    @State private var currentKeyCode: Int = 0x0B
    @State private var currentModifiers: UInt32 = UInt32(cmdKey)
    
    // 默认快捷键常量
    private let defaultKeyCode: Int = 0x0B // B
    private let defaultModifiers: Int = Int(cmdKey)
    
    var body: some View {
        Form {
            Section("全局快捷键") {
                HStack {
                    Text("显示/隐藏面板:")
                    Spacer()
                    
                    if isRecording {
                        Text("按下快捷键...")
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        HotKeyDisplay(keyCode: hotKeyKeyCode, modifiers: hotKeyModifiers)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    Button(isRecording ? "取消" : "更改") {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    // 恢复默认按钮
                    if !isRecording && (hotKeyKeyCode != defaultKeyCode || hotKeyModifiersRaw != defaultModifiers) {
                        Button("恢复默认") {
                            resetToDefault()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.secondary)
                    }
                }
                
                Text("用于快速显示或隐藏剪贴板面板（默认：⌘B）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("面板内快捷键") {
                ShortcutRow(title: "切换标签页", shortcut: "Tab", description: "在剪贴板和笔记之间切换")
                ShortcutRow(title: "选择卡片", shortcut: "↑ ↓ ← →", description: "使用方向键导航卡片")
                ShortcutRow(title: "复制选中项", shortcut: "⌘C 或 ⏎", description: "复制卡片内容到剪贴板")
                ShortcutRow(title: "删除选中项", shortcut: "⌫", description: "删除当前选中的卡片")
            }
            
            Section("快捷键说明") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("⌘").font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                        Text("Command")
                    }
                    HStack(spacing: 4) {
                        Text("⇧").font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                        Text("Shift")
                    }
                    HStack(spacing: 4) {
                        Text("⌥").font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                        Text("Option")
                    }
                    HStack(spacing: 4) {
                        Text("⌃").font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                        Text("Control")
                    }
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            currentKeyCode = hotKeyKeyCode
            currentModifiers = hotKeyModifiers
        }
    }
    
    private func startRecording() {
        isRecording = true
        currentKeyCode = 0
        currentModifiers = 0
        
        // 开始录制快捷键
        HotKeyRecorder.shared.startRecording { keyCode, modifiers in
            DispatchQueue.main.async {
                self.currentKeyCode = keyCode
                self.currentModifiers = modifiers
                self.isRecording = false
                
                // 立即更新并注册快捷键
                self.hotKeyKeyCode = keyCode
                self.hotKeyModifiersRaw = Int(modifiers)
                
                // 重新注册快捷键
                HotKeyManager.shared.registerHotKey(
                    keyCode: UInt32(keyCode),
                    modifiers: modifiers
                )
                
                print("✅ 快捷键已更新: keyCode=\(keyCode), modifiers=\(modifiers)")
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        HotKeyRecorder.shared.stopRecording()
        
        if currentKeyCode != 0 {
            hotKeyKeyCode = currentKeyCode
            hotKeyModifiersRaw = Int(currentModifiers)
            // 重新注册快捷键
            HotKeyManager.shared.registerHotKey(
                keyCode: UInt32(hotKeyKeyCode),
                modifiers: hotKeyModifiers
            )
            print("✅ 快捷键已更新: keyCode=\(hotKeyKeyCode), modifiers=\(hotKeyModifiers)")
        }
    }
    
    private func resetToDefault() {
        hotKeyKeyCode = defaultKeyCode
        hotKeyModifiersRaw = defaultModifiers
        currentKeyCode = defaultKeyCode
        currentModifiers = UInt32(defaultModifiers)
        
        // 重新注册默认快捷键
        HotKeyManager.shared.registerHotKey(
            keyCode: UInt32(defaultKeyCode),
            modifiers: UInt32(defaultModifiers)
        )
        
        print("✅ 快捷键已恢复默认: ⌘B")
    }
}

private struct HotKeyDisplay: View {
    let keyCode: Int
    let modifiers: UInt32
    
    var body: some View {
        HStack(spacing: 4) {
            if modifiers & UInt32(cmdKey) != 0 {
                Text("⌘")
            }
            if modifiers & UInt32(shiftKey) != 0 {
                Text("⇧")
            }
            if modifiers & UInt32(optionKey) != 0 {
                Text("⌥")
            }
            if modifiers & UInt32(controlKey) != 0 {
                Text("⌃")
            }
            Text(keyCodeToString(keyCode))
        }
        .font(.system(size: 13, design: .monospaced))
    }
    
    private func keyCodeToString(_ code: Int) -> String {
        // macOS 虚拟键码映射
        let mapping: [Int: String] = [
            // 字母键
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x1F: "O", 0x20: "U", 0x22: "I",
            0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N",
            0x2E: "M",
            // 数字键
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
            0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
            // 功能键
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            // 特殊键
            0x24: "⏎", 0x30: "Tab", 0x31: "Space", 0x33: "⌫",
            0x35: "Esc", 0x7E: "↑", 0x7D: "↓", 0x7B: "←", 0x7C: "→",
            // 符号键
            0x1B: "-", 0x18: "=", 0x21: "[", 0x1E: "]", 0x2A: "\\",
            0x29: ";", 0x27: "'", 0x2B: ",", 0x2C: "/", 0x2F: ".", 0x32: "`"
        ]
        return mapping[code] ?? "?"
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: String
    var description: String? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }
}

// MARK: - Subscription Settings

private struct SubscriptionSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("订阅功能")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("订阅功能即将推出")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("未来将支持：\n• 云同步\n• 高级功能\n• 优先支持")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - About Settings

private struct AboutSettingsView: View {
    @Binding var checkForUpdatesOnLaunch: Bool
    @StateObject private var updateManager = UpdateManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 应用图标和名称
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Text("EchoFlow")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("优雅的剪贴板管理工具")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // 版本信息
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text(AppConfig.currentVersion)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("构建号")
                            Spacer()
                            Text(AppConfig.buildNumber)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 作者信息
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text("开发者")
                            Spacer()
                            Text("Keben")
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Button(action: {
                                if let url = URL(string: "https://github.com/kebenart/EchoFlow") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("kebenart/EchoFlow")
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 软件更新
                GroupBox {
                    VStack(spacing: 12) {
                        Toggle("启动时自动检查更新", isOn: $checkForUpdatesOnLaunch)
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("检查更新")
                                if case .available(let release) = updateManager.status {
                                    Text("发现新版本 \(release.version)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if case .upToDate = updateManager.status {
                                    Text("已是最新版本")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await updateManager.checkForUpdates(silent: false)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if updateManager.status == .checking {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 14, height: 14)
                                        Text("检查中...")
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                        Text("检查更新")
                                    }
                                }
                            }
                            .disabled(updateManager.status == .checking)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: updateManager.status) { _, newStatus in
                    if case .available(let release) = newStatus {
                        UpdateWindowController.shared.showUpdateAlert(for: release)
                    }
                }
                
                // 版权信息
                Text("© 2025 Keben. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Color Sampling Algorithm Picker

private struct ColorSamplingAlgorithmPicker: View {
    @AppStorage("colorSamplingAlgorithm") private var algorithmRaw: String = ColorSamplingAlgorithm.edgePriority.rawValue
    
    var algorithm: ColorSamplingAlgorithm {
        get { ColorSamplingAlgorithm(rawValue: algorithmRaw) ?? .edgePriority }
        set { algorithmRaw = newValue.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("颜色采样算法", selection: Binding(
                get: { algorithm },
                set: { algorithmRaw = $0.rawValue }
            )) {
                ForEach(ColorSamplingAlgorithm.allCases, id: \.self) { algo in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(algo.displayName)
                            .font(.body)
                        Text(algo.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(algo)
                }
            }
            .pickerStyle(.menu)
            
            Text("选择不同的算法可以提取不同风格的主题色")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Clear Data Buttons

private struct ClearDataButtons: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearClipboardAlert = false
    @State private var showingClearNotesAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                showingClearClipboardAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空剪贴板历史")
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            Button(action: {
                showingClearNotesAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空笔记")
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            Text("清空操作不可恢复，请谨慎操作")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .alert("确认清空剪贴板历史", isPresented: $showingClearClipboardAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearClipboardHistory()
            }
        } message: {
            Text("此操作将删除所有剪贴板历史记录，且无法恢复。")
        }
        .alert("确认清空笔记", isPresented: $showingClearNotesAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearNotes()
            }
        } message: {
            Text("此操作将删除所有笔记，且无法恢复。")
        }
    }
    
    private func clearClipboardHistory() {
        let deleteLockedItems = UserDefaults.standard.bool(forKey: "deleteLockedItems")
        let descriptor = FetchDescriptor<ClipboardItem>()
        do {
            let items = try modelContext.fetch(descriptor)
            var deletedCount = 0
            var skippedCount = 0
            
            for item in items {
                // 如果设置了不删除锁定卡片，且当前卡片已锁定，则跳过
                if !deleteLockedItems && item.isLocked {
                    skippedCount += 1
                    continue
                }
                modelContext.delete(item)
                deletedCount += 1
            }
            
            try modelContext.save()
            
            if skippedCount > 0 {
                print("✅ 已清空 \(deletedCount) 条剪贴板历史记录，跳过 \(skippedCount) 条锁定的卡片")
            } else {
                print("✅ 已清空所有剪贴板历史记录")
            }
            
            // 发送通知刷新界面
            NotificationCenter.default.post(
                name: NSNotification.Name("NewClipboardItemAdded"),
                object: nil
            )
        } catch {
            print("❌ 清空剪贴板历史失败: \(error.localizedDescription)")
        }
    }
    
    private func clearNotes() {
        let deleteLockedItems = UserDefaults.standard.bool(forKey: "deleteLockedItems")
        let descriptor = FetchDescriptor<NoteItem>()
        do {
            let items = try modelContext.fetch(descriptor)
            var deletedCount = 0
            var skippedCount = 0
            
            for item in items {
                // 如果设置了不删除锁定笔记，且当前笔记已锁定，则跳过
                if !deleteLockedItems && item.isLocked {
                    skippedCount += 1
                    continue
                }
                modelContext.delete(item)
                deletedCount += 1
            }
            
            try modelContext.save()
            
            if skippedCount > 0 {
                print("✅ 已清空 \(deletedCount) 条笔记，跳过 \(skippedCount) 条锁定的笔记")
            } else {
                print("✅ 已清空所有笔记")
            }
            
            // 发送通知刷新界面
            NotificationCenter.default.post(
                name: NSNotification.Name("NotesUpdated"),
                object: nil
            )
        } catch {
            print("❌ 清空笔记失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Dock Position Picker

private struct DockPositionPicker: View {
    @Binding var selectedPosition: DockPosition
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(DockPosition.allCases, id: \.self) { position in
                DockPositionButton(
                    position: position,
                    isSelected: selectedPosition == position
                ) {
                    selectedPosition = position
                }
            }
        }
    }
}

private struct DockPositionButton: View {
    let position: DockPosition
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // 可视化展示停靠位置
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 48, height: 36)
                    
                    // 根据位置绘制停靠条
                    dockBar
                }
                
                Text(positionName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var dockBar: some View {
        switch position {
        case .bottom:
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 40, height: 6)
                    .padding(.bottom, 2)
            }
            .frame(width: 48, height: 36)
        case .top:
            VStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 40, height: 6)
                    .padding(.top, 2)
                Spacer()
            }
            .frame(width: 48, height: 36)
        case .left:
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 6, height: 28)
                    .padding(.leading, 2)
                Spacer()
            }
            .frame(width: 48, height: 36)
        case .right:
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 6, height: 28)
                    .padding(.trailing, 2)
            }
            .frame(width: 48, height: 36)
        }
    }
    
    private var positionName: String {
        switch position {
        case .bottom: return "底部"
        case .top: return "顶部"
        case .left: return "左侧"
        case .right: return "右侧"
        }
    }
}

// MARK: - Data Management Settings

private struct DataManagementSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Form {
            Section("备份与恢复") {
                BackupRestoreView()
            }
            
            Section("回收站设置") {
                Toggle("启用回收站", isOn: Binding(
                    get: { 
                        // 默认值为 true（开启）
                        if UserDefaults.standard.object(forKey: "enableTrash") == nil {
                            return true
                        }
                        return UserDefaults.standard.bool(forKey: "enableTrash")
                    },
                    set: { UserDefaults.standard.set($0, forKey: "enableTrash") }
                ))
                .help("启用后，删除的项目会进入回收站，3天后自动删除。关闭后，删除会直接永久删除。")
            }
            
            Section("删除设置") {
                Toggle("删除锁定卡片", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "deleteLockedItems") },
                    set: { UserDefaults.standard.set($0, forKey: "deleteLockedItems") }
                ))
                .help("启用后，清空列表和自动删除时会删除锁定的卡片")
            }
            
            Section("清空数据") {
                ClearDataButtons()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Backup/Restore View

private struct BackupRestoreView: View {
    @State private var backupOptions: BackupOptions = .all
    @State private var restoreOptions: BackupOptions = .all
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var backupMessage: String = ""
    @State private var restoreMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("备份与恢复")
                .font(.headline)
            
            // 备份选项
            VStack(alignment: .leading, spacing: 8) {
                Text("备份内容")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("剪贴板", isOn: Binding(
                        get: { backupOptions.contains(.clipboard) },
                        set: { if $0 { backupOptions.insert(.clipboard) } else { backupOptions.remove(.clipboard) } }
                    ))
                    Toggle("笔记", isOn: Binding(
                        get: { backupOptions.contains(.notes) },
                        set: { if $0 { backupOptions.insert(.notes) } else { backupOptions.remove(.notes) } }
                    ))
                    Toggle("回收站", isOn: Binding(
                        get: { backupOptions.contains(.trash) },
                        set: { if $0 { backupOptions.insert(.trash) } else { backupOptions.remove(.trash) } }
                    ))
                    Toggle("设置", isOn: Binding(
                        get: { backupOptions.contains(.settings) },
                        set: { if $0 { backupOptions.insert(.settings) } else { backupOptions.remove(.settings) } }
                    ))
                }
                .padding(.leading, 8)
                
                Button("创建备份") {
                    createBackup()
                }
                .disabled(isBackingUp || backupOptions.isEmpty)
                
                if !backupMessage.isEmpty {
                    Text(backupMessage)
                        .font(.caption)
                        .foregroundColor(backupMessage.contains("成功") ? .green : .red)
                }
            }
            
            Divider()
            
            // 恢复选项
            VStack(alignment: .leading, spacing: 8) {
                Text("恢复内容")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("剪贴板", isOn: Binding(
                        get: { restoreOptions.contains(.clipboard) },
                        set: { if $0 { restoreOptions.insert(.clipboard) } else { restoreOptions.remove(.clipboard) } }
                    ))
                    Toggle("笔记", isOn: Binding(
                        get: { restoreOptions.contains(.notes) },
                        set: { if $0 { restoreOptions.insert(.notes) } else { restoreOptions.remove(.notes) } }
                    ))
                    Toggle("回收站", isOn: Binding(
                        get: { restoreOptions.contains(.trash) },
                        set: { if $0 { restoreOptions.insert(.trash) } else { restoreOptions.remove(.trash) } }
                    ))
                    Toggle("设置", isOn: Binding(
                        get: { restoreOptions.contains(.settings) },
                        set: { if $0 { restoreOptions.insert(.settings) } else { restoreOptions.remove(.settings) } }
                    ))
                }
                .padding(.leading, 8)
                
                Button("恢复备份") {
                    restoreBackup()
                }
                .disabled(isRestoring || restoreOptions.isEmpty)
                
                if !restoreMessage.isEmpty {
                    Text(restoreMessage)
                        .font(.caption)
                        .foregroundColor(restoreMessage.contains("成功") ? .green : .red)
                }
            }
        }
    }
    
    private func createBackup() {
        isBackingUp = true
        backupMessage = ""
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "EchoFlow_Backup_\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).json"
        panel.title = "保存备份"
        
        // 确保弹框显示在设置窗口前面
        if let settingsWindow = WindowManager.shared.settingsWindow {
            panel.beginSheetModal(for: settingsWindow) { response in
                if response == .OK, let url = panel.url {
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try BackupManager.shared.createBackup(options: backupOptions, to: url)
                            DispatchQueue.main.async {
                                backupMessage = "✅ 备份成功: \(url.lastPathComponent)"
                                isBackingUp = false
                            }
                        } catch {
                            DispatchQueue.main.async {
                                backupMessage = "❌ 备份失败: \(error.localizedDescription)"
                                isBackingUp = false
                            }
                        }
                    }
                } else {
                    isBackingUp = false
                }
            }
        } else {
            // 如果没有设置窗口，使用普通方式
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try BackupManager.shared.createBackup(options: backupOptions, to: url)
                            DispatchQueue.main.async {
                                backupMessage = "✅ 备份成功: \(url.lastPathComponent)"
                                isBackingUp = false
                            }
                        } catch {
                            DispatchQueue.main.async {
                                backupMessage = "❌ 备份失败: \(error.localizedDescription)"
                                isBackingUp = false
                            }
                        }
                    }
                } else {
                    isBackingUp = false
                }
            }
        }
    }
    
    private func restoreBackup() {
        isRestoring = true
        restoreMessage = ""
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = "选择备份文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        // 确保弹框显示在设置窗口前面
        if let settingsWindow = WindowManager.shared.settingsWindow {
            panel.beginSheetModal(for: settingsWindow) { response in
                if response == .OK, let url = panel.url {
                    // 验证备份文件
                    do {
                        let backupData = try BackupManager.shared.validateBackup(at: url)
                        
                        let alert = NSAlert()
                        alert.messageText = "确认恢复"
                        alert.informativeText = """
                        确定要从备份恢复吗？
                        
                        备份版本: \(backupData.version)
                        创建时间: \(backupData.createdAt.formatted())
                        
                        这将合并备份中的数据到当前数据中（不会覆盖已存在的项目）。
                        """
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "恢复")
                        alert.addButton(withTitle: "取消")
                        
                        // 确保 alert 也显示在设置窗口前面
                        alert.beginSheetModal(for: settingsWindow) { alertResponse in
                            if alertResponse == .alertFirstButtonReturn {
                                DispatchQueue.global(qos: .userInitiated).async {
                                    do {
                                        try BackupManager.shared.restoreBackup(from: url, options: restoreOptions)
                                        DispatchQueue.main.async {
                                            restoreMessage = "✅ 恢复成功"
                                            isRestoring = false
                                        }
                                    } catch {
                                        DispatchQueue.main.async {
                                            restoreMessage = "❌ 恢复失败: \(error.localizedDescription)"
                                            isRestoring = false
                                        }
                                    }
                                }
                            } else {
                                isRestoring = false
                            }
                        }
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "备份文件无效"
                        alert.informativeText = "无法读取备份文件: \(error.localizedDescription)"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "确定")
                        alert.beginSheetModal(for: settingsWindow) { _ in
                            isRestoring = false
                        }
                    }
                } else {
                    isRestoring = false
                }
            }
        } else {
            // 如果没有设置窗口，使用普通方式
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    // 验证备份文件
                    do {
                        let backupData = try BackupManager.shared.validateBackup(at: url)
                        
                        let alert = NSAlert()
                        alert.messageText = "确认恢复"
                        alert.informativeText = """
                        确定要从备份恢复吗？
                        
                        备份版本: \(backupData.version)
                        创建时间: \(backupData.createdAt.formatted())
                        
                        这将合并备份中的数据到当前数据中（不会覆盖已存在的项目）。
                        """
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "恢复")
                        alert.addButton(withTitle: "取消")
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            DispatchQueue.global(qos: .userInitiated).async {
                                do {
                                    try BackupManager.shared.restoreBackup(from: url, options: restoreOptions)
                                    DispatchQueue.main.async {
                                        restoreMessage = "✅ 恢复成功"
                                        isRestoring = false
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        restoreMessage = "❌ 恢复失败: \(error.localizedDescription)"
                                        isRestoring = false
                                    }
                                }
                            }
                        } else {
                            isRestoring = false
                        }
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "备份文件无效"
                        alert.informativeText = "无法读取备份文件: \(error.localizedDescription)"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                        isRestoring = false
                    }
                } else {
                    isRestoring = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

