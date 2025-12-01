//
//  ClipboardWindowListView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/30.
//

import SwiftUI
import AppKit
import SwiftData

/// 窗口模式下的剪切板列表视图 - 使用 BaseClipboardContentView 统一渲染
struct ClipboardWindowListView: NSViewRepresentable {
    let items: [ClipboardItem]
    let searchText: String
    @Binding var focusedIndex: Int
    let timeRefreshTrigger: Int
    let onItemSelected: (Int, ClipboardItem) -> Void
    let onItemDoubleClick: (ClipboardItem) -> Void
    let onTabKey: () -> Void
    let onDelete: (ClipboardItem) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = WindowClipboardTableView()
        
        // 配置 ScrollView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // 配置 TableView
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowSizeStyle = .custom
        tableView.headerView = nil
        tableView.allowsEmptySelection = true
        tableView.focusRingType = .none
        tableView.usesAutomaticRowHeights = false
        
        // 设置列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("WindowCardColumn"))
        column.resizingMask = [.autoresizingMask]
        column.width = 360
        tableView.addTableColumn(column)
        
        // 设置数据源和代理
        let coordinator = context.coordinator
        coordinator.tableView = tableView
        coordinator.items = items
        coordinator.focusedIndex = focusedIndex
        coordinator.focusedIndexBinding = $focusedIndex
        coordinator.timeRefreshTrigger = timeRefreshTrigger
        coordinator.onItemSelected = onItemSelected
        coordinator.onItemDoubleClick = onItemDoubleClick
        coordinator.onDelete = onDelete
        
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        tableView.coordinator = coordinator
        
        // 设置双击动作
        tableView.doubleAction = #selector(coordinator.handleDoubleClick(_:))
        tableView.target = coordinator
        
        scrollView.documentView = tableView
        
        // 延迟设置第一响应者，确保视图已添加到窗口
        DispatchQueue.main.async {
            tableView.window?.makeFirstResponder(tableView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        let coordinator = context.coordinator
        
        // 检查数据是否变化
        let itemsChanged = coordinator.items.count != items.count ||
            !zip(coordinator.items, items).allSatisfy { $0.id == $1.id }
        
        // 检查时间刷新触发器是否变化
        let timeChanged = coordinator.timeRefreshTrigger != timeRefreshTrigger
        
        // 更新数据
        coordinator.items = items
        coordinator.focusedIndex = focusedIndex
        coordinator.focusedIndexBinding = $focusedIndex
        coordinator.timeRefreshTrigger = timeRefreshTrigger
        coordinator.onItemSelected = onItemSelected
        coordinator.onItemDoubleClick = onItemDoubleClick
        coordinator.onDelete = onDelete
        coordinator.onTabKey = onTabKey
        
        // 更新列宽
        if let column = tableView.tableColumns.first {
            let availableWidth = nsView.bounds.width - 24
            column.width = max(availableWidth, 300)
        }
        
        // 如果数据变化，刷新表格
        if itemsChanged {
            tableView.reloadData()
        } else if timeChanged {
            // 只更新时间显示，不重载整个表格
            coordinator.updateVisibleCellsTime()
        }
        
        // 滚动到焦点项
        if focusedIndex >= 0 && focusedIndex < items.count {
            tableView.scrollRowToVisible(focusedIndex)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var tableView: NSTableView?
        var items: [ClipboardItem] = []
        var focusedIndex: Int = 0
        var timeRefreshTrigger: Int = 0
        var onItemSelected: ((Int, ClipboardItem) -> Void)?
        var onItemDoubleClick: ((ClipboardItem) -> Void)?
        var onDelete: ((ClipboardItem) -> Void)?
        var onTabKey: (() -> Void)?
        var focusedIndexBinding: Binding<Int>?
        
        // 存储当前可见的 cell，便于轻量级更新选中状态
        private var cellViews: [Int: WeakWindowCellRef] = [:]
        
        private func cleanupCellViews() {
            cellViews = cellViews.filter { $0.value.value != nil }
        }
        
        func handleTabKey() {
            onTabKey?()
        }
        
        func updateVisibleCellsTime() {
            // 更新所有可见 cell 的时间显示
            for (_, cellRef) in cellViews {
                cellRef.value?.updateTime(trigger: timeRefreshTrigger)
            }
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return items.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0 && row < items.count else { return nil }
            
            let item = items[row]
            let isFocused = (row == focusedIndex)
            
            // 重用或创建 cell view
            let identifier = NSUserInterfaceItemIdentifier("WindowClipboardCell")
            var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? WindowClipboardCellView
            
            if cellView == nil {
                cellView = WindowClipboardCellView()
                cellView?.identifier = identifier
            }
            
            // 配置 cell
            cellView?.configure(
                item: item,
                index: row,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: { [weak self] in
                    self?.selectRow(row)
                },
                onDoubleTap: { [weak self] in
                    self?.onItemDoubleClick?(item)
                },
                onDelete: { [weak self] in
                    self?.onDelete?(item)
                }
            )
            
            // 记录弱引用
            if let cellView = cellView {
                cleanupCellViews()
                cellViews[row] = WeakWindowCellRef(value: cellView)
            }
            
            return cellView
        }
        
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 88
        }
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = WindowClipboardRowView()
            return rowView
        }
        
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            selectRow(row)
            return false
        }
        
        // MARK: - Selection
        
        func selectRow(_ row: Int) {
            guard row >= 0 && row < items.count else { return }
            
            let oldFocus = focusedIndex
            focusedIndex = row
            focusedIndexBinding?.wrappedValue = row
            onItemSelected?(row, items[row])
            
            // 轻量级更新旧/新 cell 的选中样式
            if let oldCellRef = cellViews[oldFocus], let oldCell = oldCellRef.value {
                oldCell.updateFocus(false)
            }
            if let newCellRef = cellViews[row], let newCell = newCellRef.value {
                newCell.updateFocus(true)
            }
            
            tableView?.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView?.scrollRowToVisible(row)
            
            // 确保 TableView 获得键盘焦点
            if let tv = tableView, tv.window?.firstResponder != tv {
                tv.window?.makeFirstResponder(tv)
            }
        }
        
        // MARK: - Keyboard Navigation
        
        func moveFocus(by delta: Int) {
            let newIndex = max(0, min(items.count - 1, focusedIndex + delta))
            if newIndex != focusedIndex {
                selectRow(newIndex)
            }
        }
        
        func performCopy(at index: Int) {
            if index >= 0 && index < items.count {
                onItemDoubleClick?(items[index])
            }
        }

        func performCopy() {
            if focusedIndex >= 0 && focusedIndex < items.count {
                onItemDoubleClick?(items[focusedIndex])
            }
        }
        
        // MARK: - Double Click Handler
        
        @objc func handleDoubleClick(_ sender: Any?) {
            guard let tableView = tableView else { return }
            let row = tableView.clickedRow
            if row >= 0 && row < items.count {
                onItemDoubleClick?(items[row])
            }
        }
    }
}

// 弱引用封装
private struct WeakWindowCellRef {
    weak var value: WindowClipboardCellView?
}

// MARK: - Custom NSTableView with Keyboard Support

class WindowClipboardTableView: NSTableView {
    weak var coordinator: ClipboardWindowListView.Coordinator?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        return result
    }
    
    override func keyDown(with event: NSEvent) {
        let handled = handleKeyEvent(event)
        if !handled {
            super.keyDown(with: event)
        }
    }
    
    /// 处理键盘事件，返回 true 表示已处理
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // 处理 Command + 1-9 快捷键
        if modifiers.contains(.command) {
            var targetIndex: Int?
            switch keyCode {
            case 18: targetIndex = 0  // 1
            case 19: targetIndex = 1  // 2
            case 20: targetIndex = 2  // 3
            case 21: targetIndex = 3  // 4
            case 23: targetIndex = 4  // 5
            case 22: targetIndex = 5  // 6
            case 26: targetIndex = 6  // 7
            case 28: targetIndex = 7  // 8
            case 25: targetIndex = 8  // 9
            default: break
            }
            
            if let index = targetIndex {
                coordinator?.performCopy(at: index)
                return true
            }
            
            // Cmd + C 复制
            if keyCode == 8 { // C key
                coordinator?.performCopy()
                return true
            }
        }
        
        // 无修饰键的快捷键
        if modifiers.isEmpty || modifiers == .numericPad || modifiers == .function {
            switch keyCode {
            case 48: // Tab
                coordinator?.handleTabKey()
                return true
            case 126: // Up Arrow
                coordinator?.moveFocus(by: -1)
                return true
            case 125: // Down Arrow
                coordinator?.moveFocus(by: 1)
                return true
            case 36: // Return/Enter
                coordinator?.performCopy()
                return true
            case 76: // Numpad Enter
                coordinator?.performCopy()
                return true
            default:
                break
            }
        }
        
        return false
    }
}

// MARK: - Custom Row View

class WindowClipboardRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set { }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        // 不绘制默认选择样式
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        // 不绘制默认背景
    }
}

// MARK: - Window Clipboard Cell View (使用 NSHostingView 包装 SwiftUI)

class WindowClipboardCellView: NSView {
    private var hostingView: NSHostingView<AnyView>?
    private var currentItem: ClipboardItem?
    private var currentIndex: Int = 0
    private var currentIsFocused: Bool = false
    private var currentTimeRefreshTrigger: Int = 0
    private var currentOnTap: (() -> Void)?
    private var currentOnDoubleTap: (() -> Void)?
    private var currentOnDelete: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    func configure(
        item: ClipboardItem,
        index: Int,
        isFocused: Bool,
        timeRefreshTrigger: Int,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        // 检查是否需要重建视图（在更新 currentItem 之前检查）
        let needsRebuild = currentItem?.id != item.id || hostingView == nil
        
        currentOnTap = onTap
        currentOnDoubleTap = onDoubleTap
        currentOnDelete = onDelete
        currentItem = item
        currentIndex = index
        
        if needsRebuild {
            hostingView?.removeFromSuperview()
            
            let contentView = BaseClipboardContentView(
                item: item,
                index: index,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                config: .row,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                onDelete: onDelete
            )
            
            let hosting = NSHostingView(rootView: AnyView(contentView))
            hosting.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hosting)
            
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
                hosting.topAnchor.constraint(equalTo: topAnchor),
                hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            hostingView = hosting
            currentIsFocused = isFocused
            currentTimeRefreshTrigger = timeRefreshTrigger
        } else if currentIsFocused != isFocused || currentTimeRefreshTrigger != timeRefreshTrigger {
            // 只更新焦点状态或时间，不重建整个视图
            rebuildContentView(isFocused: isFocused, timeRefreshTrigger: timeRefreshTrigger)
        }
    }
    
    private func rebuildContentView(isFocused: Bool, timeRefreshTrigger: Int) {
        guard let item = currentItem,
              let onTap = currentOnTap,
              let onDoubleTap = currentOnDoubleTap,
              let onDelete = currentOnDelete else { return }
        
        let contentView = BaseClipboardContentView(
            item: item,
            index: currentIndex,
            isFocused: isFocused,
            timeRefreshTrigger: timeRefreshTrigger,
            config: .row,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onDelete: onDelete
        )
        
        hostingView?.rootView = AnyView(contentView)
        currentIsFocused = isFocused
        currentTimeRefreshTrigger = timeRefreshTrigger
    }
    
    func updateFocus(_ isFocused: Bool) {
        guard currentIsFocused != isFocused else { return }
        rebuildContentView(isFocused: isFocused, timeRefreshTrigger: currentTimeRefreshTrigger)
    }
    
    func updateTime(trigger: Int) {
        guard currentTimeRefreshTrigger != trigger else { return }
        rebuildContentView(isFocused: currentIsFocused, timeRefreshTrigger: trigger)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentIsFocused = false
    }
}
