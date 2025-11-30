//
//  ClipboardListView.swift
//  EchoFlow
//
//  Created by keben on 2025/11/29.
//

import SwiftUI
import SwiftData
import AppKit
import Combine

/// 剪贴板列表入口视图 (负责事件监听与布局配置)
struct ClipboardListView: View {
    @Binding var searchText: String
    let dockPosition: DockPosition
    
    // 时间刷新触发器 (向下传递)
    @State private var timeRefreshTrigger: Int = 0
    // 强制刷新触发器 (用于数据变更)
    @State private var forceRefreshTrigger: Int = 0

    var body: some View {
        // 使用 NSTableView 优化性能
        ClipboardListContent(
            searchText: searchText,
            dockPosition: dockPosition,
            timeRefreshTrigger: timeRefreshTrigger,
            forceRefreshTrigger: forceRefreshTrigger
        )
        // 接收时间更新通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateTimeOnly"))) { _ in
            // 轻量级更新，只会触发依赖 trigger 的时间文本重绘
            timeRefreshTrigger += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewClipboardItemAdded"))) { notification in
            // 强制刷新
            forceRefreshTrigger += 1
            // 添加一个小延迟，确保 SwiftData 已经更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                forceRefreshTrigger += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LinkMetadataUpdated"))) { _ in
            // 链接元数据更新，强制刷新
            forceRefreshTrigger += 1
        }
    }
}

/// 剪贴板列表内容视图 (使用 NSTableView 优化性能)
fileprivate struct ClipboardListContent: View {
    @Environment(\.modelContext) private var modelContext
    
    // 动态查询
    @Query private var items: [ClipboardItem]
    
    let dockPosition: DockPosition
    let timeRefreshTrigger: Int
    let forceRefreshTrigger: Int
    
    // MARK: - Local State
    @State private var focusedIndex: Int = 0
    @State private var isCopying: Bool = false
    @AppStorage("copyBehavior") private var copyBehaviorRaw: String = "copyToPasteboard"
    
    // MARK: - Init (Dynamic Predicate)
    init(searchText: String, dockPosition: DockPosition, timeRefreshTrigger: Int, forceRefreshTrigger: Int) {
        self.dockPosition = dockPosition
        self.timeRefreshTrigger = timeRefreshTrigger
        self.forceRefreshTrigger = forceRefreshTrigger
        
        // 核心优化：在数据库层面过滤，而不是加载到内存后过滤
        let predicate: Predicate<ClipboardItem>
        if searchText.isEmpty {
            predicate = #Predicate<ClipboardItem> { _ in true }
        } else {
            predicate = #Predicate<ClipboardItem> { item in
                item.content.localizedStandardContains(searchText) ||
                item.sourceApp.localizedStandardContains(searchText)
            }
        }
        
        // 按创建时间倒序
        let sortDescriptors = [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        _items = Query(filter: predicate, sort: sortDescriptors)
    }

    var body: some View {
        // 根据停靠位置选择不同的布局方式
        Group {
            if items.isEmpty {
                // 空状态视图 - 避免空的 NSCollectionView 抢占焦点
                emptyStateView
            } else if dockPosition.isHorizontal {
                // 水平布局（顶部/底部）：使用水平滚动视图
                ClipboardHorizontalCollectionView(
                    items: items,
                    dockPosition: dockPosition,
                    timeRefreshTrigger: timeRefreshTrigger,
                    forceRefreshTrigger: forceRefreshTrigger,
                    focusedIndex: $focusedIndex,
                    onItemTap: { index, item in
                        handleCardTap(at: index, item: item)
                    },
                    onItemDoubleTap: { item in
                        handleCardDoubleTap(item)
                    },
                    onItemDelete: { item in
                        deleteItem(item)
                    },
                    onCopyAction: {
                        performCopyAction()
                    },
                    onFocusChange: { newIndex in
                        focusedIndex = newIndex
                    }
                )
                .id("horizontal-\(forceRefreshTrigger)") // 强制视图在 forceRefreshTrigger 变化时重新创建
            } else {
                // 垂直布局（左右侧）：使用 NSTableView
                ClipboardTableView(
                    items: items,
                    dockPosition: dockPosition,
                    timeRefreshTrigger: timeRefreshTrigger,
                    focusedIndex: $focusedIndex,
                    onItemTap: { index, item in
                        handleCardTap(at: index, item: item)
                    },
                    onItemDoubleTap: { item in
                        handleCardDoubleTap(item)
                    },
                    onItemDelete: { item in
                        deleteItem(item)
                    },
                    onCopyAction: {
                        performCopyAction()
                    },
                    onFocusChange: { newIndex in
                        focusedIndex = newIndex
                    }
                )
            }
        }
        .onAppear {
            resetFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            resetFocus()
        }
        .onChange(of: forceRefreshTrigger) { oldValue, newValue in
            // 当强制刷新触发时，重置焦点并确保视图更新
            // 重置焦点到第一个项目
            if items.count > 0 {
                focusedIndex = 0
            }
        }
        .onChange(of: items.count) { _, newCount in
            if focusedIndex >= newCount {
                focusedIndex = max(0, newCount - 1)
            }
        }
    }

    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("剪贴板历史为空")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("复制内容后会自动显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions

    private func resetFocus() {
        focusedIndex = 0
    }
    
    /// 新增项目处理
    private func handleNewItemAdded() {
        focusedIndex = 0
    }
    
    /// 链接元数据更新处理
    private func handleLinkMetadataUpdated(itemId: UUID) {
        // 查找对应的卡片并刷新
        // 由于使用 AppKit 视图，需要通过 coordinator 来刷新
        // 这里主要触发视图更新，实际的刷新会在 updateNSView 中处理
        DispatchQueue.main.async {
            // 强制重新配置可见的卡片
            // 这个通知会被 ClipboardCardCellView 监听并处理
            NotificationCenter.default.post(
                name: NSNotification.Name("RefreshCardView"),
                object: nil,
                userInfo: ["itemId": itemId]
            )
        }
    }

    /// 处理卡片点击 (仅聚焦)
    private func handleCardTap(at index: Int, item: ClipboardItem) {
        focusedIndex = index
    }
    
    /// 处理卡片双击 (复制)
    private func handleCardDoubleTap(_ item: ClipboardItem) {
        copyToPasteboard(item)
    }
    
    /// 执行当前聚焦项的复制
    private func performCopyAction() {
        guard focusedIndex < items.count else { return }
        copyToPasteboard(items[focusedIndex])
    }

    /// 复制逻辑
    private func copyToPasteboard(_ item: ClipboardItem) {
        guard !isCopying else { return }
        isCopying = true
        
        print("📋 复制内容: \(item.content.prefix(20))...")
        
        // 执行复制逻辑
        switch item.type {
        case .image:
            if item.content.starts(with: "/") {
                let fileURL = URL(fileURLWithPath: item.content)
                PasteboardManager.shared.writeToPasteboard(fileURLs: [fileURL])
            } else if let imageData = item.imageData, let image = NSImage(data: imageData) {
                PasteboardManager.shared.writeToPasteboard(image: image)
            } else {
                PasteboardManager.shared.writeToPasteboard(content: item.content)
            }
        case .file:
            let paths = item.content.split(separator: "\n").map { String($0) }
            let fileURLs = paths.map { URL(fileURLWithPath: $0) }
            PasteboardManager.shared.writeToPasteboard(fileURLs: fileURLs)
        default:
            PasteboardManager.shared.writeToPasteboard(content: item.content)
        }

        NSSound.beep()

        // 先隐藏窗口，避免时间戳更新导致的列表重排与消失动画冲突
        let shouldPaste = (copyBehaviorRaw == "copyToCurrentApp")
        
        if shouldPaste {
            WindowManager.shared.hidePanel {
                // 面板隐藏后再更新时间戳
                PasteboardManager.shared.updateItemTimestamp(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    PasteSimulator.shared.simulatePaste(delay: 0.05)
                }
            }
        } else {
            WindowManager.shared.hidePanel {
                // 面板隐藏后再更新时间戳
                PasteboardManager.shared.updateItemTimestamp(item)
            }
        }
        
        // 冷却时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.isCopying = false
        }
    }

    /// 删除逻辑
    private func deleteItem(_ item: ClipboardItem) {
        let deletedIndex = items.firstIndex(where: { $0.id == item.id }) ?? focusedIndex
        
        // 数据库删除
        modelContext.delete(item)
        try? modelContext.save()
        
        // 修正焦点
        let newCount = items.count
        if newCount == 0 {
            focusedIndex = 0
        } else if deletedIndex <= focusedIndex {
            let nextFocus = max(0, focusedIndex - 1)
            focusedIndex = nextFocus
        }
    }
}

// MARK: - Horizontal Collection View (for Top/Bottom Docking)

/// 水平滚动集合视图，用于顶部/底部停靠
struct ClipboardHorizontalCollectionView: NSViewRepresentable {
    let items: [ClipboardItem]
    let dockPosition: DockPosition
    let timeRefreshTrigger: Int
    let forceRefreshTrigger: Int
    @Binding var focusedIndex: Int
    let onItemTap: (Int, ClipboardItem) -> Void
    let onItemDoubleTap: (ClipboardItem) -> Void
    let onItemDelete: (ClipboardItem) -> Void
    let onCopyAction: () -> Void
    let onFocusChange: (Int) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let clipView = NSClipView()
        let collectionView = NSCollectionView()
        
        // 配置 ScrollView（水平滚动）
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // 配置 CollectionView
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        // 注册 item 类型（必须在设置数据源之前注册）
        let identifier = NSUserInterfaceItemIdentifier("ClipboardCardItem")
        collectionView.register(ClipboardCardCollectionItem.self, forItemWithIdentifier: identifier)
        
        // 创建水平流布局
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.itemSize = NSSize(width: 240, height: 240)
        flowLayout.minimumInteritemSpacing = 16
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        collectionView.collectionViewLayout = flowLayout
        
        // 设置数据源和代理
        let coordinator = context.coordinator
        coordinator.collectionView = collectionView
        coordinator.items = items
        coordinator.dockPosition = dockPosition
        coordinator.timeRefreshTrigger = timeRefreshTrigger
        coordinator.forceRefreshTrigger = forceRefreshTrigger
        coordinator.focusedIndex = focusedIndex
        coordinator.onItemTap = onItemTap
        coordinator.onItemDoubleTap = onItemDoubleTap
        coordinator.onItemDelete = onItemDelete
        coordinator.onCopyAction = onCopyAction
        coordinator.onFocusChange = onFocusChange
        
        collectionView.dataSource = coordinator
        collectionView.delegate = coordinator
        
        clipView.documentView = collectionView
        scrollView.contentView = clipView
        scrollView.documentView = collectionView
        
        // 监听链接元数据更新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LinkMetadataUpdated"),
            object: nil,
            queue: .main
        ) { [weak collectionView, weak coordinator] notification in
            guard let collectionView = collectionView, let coordinator = coordinator,
                  let itemId = notification.userInfo?["itemId"] as? UUID else { return }
            
            // 查找对应的 item 并刷新
            if let itemIndex = coordinator.items.firstIndex(where: { $0.id == itemId }) {
                let indexPath = IndexPath(item: itemIndex, section: 0)
                // 重新配置对应的 cell
                if let collectionItem = collectionView.item(at: indexPath) as? ClipboardCardCollectionItem,
                   itemIndex < coordinator.items.count {
                    let item = coordinator.items[itemIndex]
                    let isFocused = (itemIndex == coordinator.focusedIndex)
                    collectionItem.configure(
                        item: item,
                        index: itemIndex,
                        isFocused: isFocused,
                        timeRefreshTrigger: coordinator.timeRefreshTrigger,
                        onTap: { [weak coordinator] in
                            coordinator?.onItemTap?(itemIndex, item)
                        },
                        onDoubleTap: { [weak coordinator] in
                            coordinator?.onItemDoubleTap?(item)
                        },
                        onDelete: { [weak coordinator] in
                            coordinator?.onItemDelete?(item)
                        }
                    )
                }
            }
        }
        
        // 创建键盘事件处理视图
        let keyHandler = KeyboardHandlerView(
            coordinator: coordinator as AnyObject,
            dockPosition: dockPosition
        )
        scrollView.addSubview(keyHandler)
        keyHandler.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyHandler.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            keyHandler.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            keyHandler.topAnchor.constraint(equalTo: scrollView.topAnchor),
            keyHandler.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let collectionView = nsView.documentView as? NSCollectionView else { 
            return 
        }
        let coordinator = context.coordinator
        let previousFocusedIndex = coordinator.focusedIndex
        
        // 确保 item 已注册（在更新时再次检查）
        let identifier = NSUserInterfaceItemIdentifier("ClipboardCardItem")
        collectionView.register(ClipboardCardCollectionItem.self, forItemWithIdentifier: identifier)
        
        // 检查数据是否变化（更严格的比较，包括强制刷新触发器）
        var itemsChanged: Bool
        if coordinator.forceRefreshTrigger != forceRefreshTrigger {
            itemsChanged = true
        } else if coordinator.items.count != items.count {
            itemsChanged = true
        } else {
            // 比较每个项目的 ID、创建时间和链接元数据
            itemsChanged = !zip(coordinator.items, items).allSatisfy { oldItem, newItem in
                let basicMatch = oldItem.id == newItem.id && oldItem.createdAt == newItem.createdAt
                // 检查链接元数据是否更新
                let linkMetadataMatch = oldItem.linkTitle == newItem.linkTitle && 
                                       oldItem.linkFaviconData == newItem.linkFaviconData
                return basicMatch && linkMetadataMatch
            }
        }
        
        // 更新数据
        coordinator.items = items
        coordinator.dockPosition = dockPosition
        coordinator.timeRefreshTrigger = timeRefreshTrigger
        coordinator.forceRefreshTrigger = forceRefreshTrigger
        coordinator.focusedIndex = focusedIndex
        coordinator.onItemTap = onItemTap
        coordinator.onItemDoubleTap = onItemDoubleTap
        coordinator.onItemDelete = onItemDelete
        coordinator.onCopyAction = onCopyAction
        
        // 如果数据变化，强制刷新集合视图
        if itemsChanged {
            collectionView.reloadData()
        } else if coordinator.forceRefreshTrigger != forceRefreshTrigger {
            // 即使数据没变化，但 forceRefreshTrigger 变化了，也需要刷新
            collectionView.reloadData()
        }
        
        // 滚动到焦点项（使用智能滚动，只在卡片被裁剪时才滚动）
        if focusedIndex >= 0 && focusedIndex < items.count {
            let indexPath = IndexPath(item: focusedIndex, section: 0)
            
            // 如果是内部导航触发的（键盘或鼠标点击），跳过滚动（已在对应处理函数中处理）
            if !coordinator.isKeyboardNavigating {
                // 使用智能滚动：只在卡片被裁剪时才滚动
                coordinator.smartScrollToItem(at: indexPath, in: collectionView)
            }
            collectionView.selectionIndexPaths = [indexPath]
            
            // 重置导航标志
            coordinator.isKeyboardNavigating = false
        }

        if previousFocusedIndex != focusedIndex {
            coordinator.applyFocusChange(from: previousFocusedIndex, to: focusedIndex)
        }
    }
    
    func makeCoordinator() -> HorizontalCoordinator {
        HorizontalCoordinator()
    }
    
    class HorizontalCoordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        weak var collectionView: NSCollectionView?
        var items: [ClipboardItem] = []
        var dockPosition: DockPosition = .bottom
        var timeRefreshTrigger: Int = 0
        var forceRefreshTrigger: Int = 0
        var focusedIndex: Int = 0
        var onItemTap: ((Int, ClipboardItem) -> Void)?
        var onItemDoubleTap: ((ClipboardItem) -> Void)?
        var onItemDelete: ((ClipboardItem) -> Void)?
        var onCopyAction: (() -> Void)?
        var onFocusChange: ((Int) -> Void)?
        
        // 标记是否由键盘导航触发的焦点变化，防止 updateNSView 覆盖智能滚动
        var isKeyboardNavigating: Bool = false
        
        private var cellViews: [Int: WeakRef<ClipboardCardCellView>] = [:]
        
        // MARK: - NSCollectionViewDataSource
        
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            return items.count
        }
        
        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            guard indexPath.item >= 0 && indexPath.item < items.count else {
                let identifier = NSUserInterfaceItemIdentifier("ClipboardCardItem")
                return collectionView.makeItem(withIdentifier: identifier, for: indexPath) ?? NSCollectionViewItem()
            }
            
            let item = items[indexPath.item]
            let isFocused = (indexPath.item == focusedIndex)
            
            let identifier = NSUserInterfaceItemIdentifier("ClipboardCardItem")
            
            guard let collectionItem = collectionView.makeItem(withIdentifier: identifier, for: indexPath) as? ClipboardCardCollectionItem else {
                let newItem = ClipboardCardCollectionItem()
                newItem.configure(
                    item: item,
                    index: indexPath.item,
                    isFocused: isFocused,
                    timeRefreshTrigger: timeRefreshTrigger,
                    onTap: { [weak self] in
                        self?.onItemTap?(indexPath.item, item)
                    },
                    onDoubleTap: { [weak self] in
                        self?.onItemDoubleTap?(item)
                    },
                    onDelete: { [weak self] in
                        self?.onItemDelete?(item)
                    }
                )
                if let cellView = newItem.cardCellView {
                    cellViews[indexPath.item] = WeakRef(value: cellView)
                }
                return newItem
            }
            
            collectionItem.configure(
                item: item,
                index: indexPath.item,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: { [weak self] in
                    self?.onItemTap?(indexPath.item, item)
                },
                onDoubleTap: { [weak self] in
                    self?.onItemDoubleTap?(item)
                },
                onDelete: { [weak self] in
                    self?.onItemDelete?(item)
                }
            )
            
            if let cellView = collectionItem.cardCellView {
                cellViews[indexPath.item] = WeakRef(value: cellView)
            }
            
            return collectionItem
        }
        // ... (delegate methods remain same but removed duplicate observer code)
        
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            if let indexPath = indexPaths.first {
                focusedIndex = indexPath.item
                
                // 鼠标点击也使用智能滚动
                smartScrollToItem(at: indexPath, in: collectionView)
                
                // 标记为已处理滚动，防止 updateNSView 重复滚动
                isKeyboardNavigating = true
                onFocusChange?(indexPath.item)
            }
        }
        
        /// 智能滚动：只在卡片被裁剪时才滚动
        func smartScrollToItem(at indexPath: IndexPath, in collectionView: NSCollectionView) {
            guard let layoutAttributes = collectionView.layoutAttributesForItem(at: indexPath) else {
                collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredHorizontally)
                return
            }
            
            let itemFrame = layoutAttributes.frame
            let visibleRect = collectionView.visibleRect
            
            // 检查卡片是否完全在可视区域内
            let isFullyVisible = visibleRect.contains(itemFrame)
            
            // 如果卡片已经完全可见，不需要滚动
            if isFullyVisible {
                return
            }
            
            // 卡片被裁剪，需要滚动
            // 根据哪边被裁剪来决定滚动方向
            let leftClipped = itemFrame.minX < visibleRect.minX
            let rightClipped = itemFrame.maxX > visibleRect.maxX
            
            let scrollPosition: NSCollectionView.ScrollPosition
            if leftClipped {
                scrollPosition = .left
            } else if rightClipped {
                scrollPosition = .right
            } else {
                scrollPosition = .centeredHorizontally
            }
            
            collectionView.scrollToItems(at: [indexPath], scrollPosition: scrollPosition)
        }
        
        func moveFocus(by offset: Int, in collectionView: NSCollectionView) {
            let totalCount = items.count
            guard totalCount > 0 else { return }
            
            let newIndex = focusedIndex + offset
            guard newIndex >= 0 && newIndex < totalCount else { return }
            
            // 标记为键盘导航，防止 updateNSView 覆盖智能滚动
            isKeyboardNavigating = true
            
            // 更新旧焦点
            if let oldCellViewRef = cellViews[focusedIndex], let oldCellView = oldCellViewRef.value {
                oldCellView.updateFocus(isFocused: false)
            }
            
            focusedIndex = newIndex
            onFocusChange?(newIndex)
            
            // 更新新焦点
            if let newCellViewRef = cellViews[newIndex], let newCellView = newCellViewRef.value {
                newCellView.updateFocus(isFocused: true)
            }
            
            // 智能滚动：只在卡片被裁剪或即将被裁剪时才滚动
            let indexPath = IndexPath(item: newIndex, section: 0)
            collectionView.selectionIndexPaths = [indexPath]
            
            // 检查项目是否在可视区域内
            if let layoutAttributes = collectionView.layoutAttributesForItem(at: indexPath) {
                let itemFrame = layoutAttributes.frame
                let visibleRect = collectionView.visibleRect
                
                // 检查卡片是否完全可见
                let isFullyVisible = visibleRect.contains(itemFrame)
                
                if !isFullyVisible {
                    // 卡片被裁剪，根据移动方向滚动
                    let scrollPosition: NSCollectionView.ScrollPosition = offset > 0 ? .right : .left
                    collectionView.scrollToItems(at: [indexPath], scrollPosition: scrollPosition)
                }
            } else {
                // 如果无法获取布局属性，使用默认居中滚动
                collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredHorizontally)
            }
        }

        func applyFocusChange(from oldIndex: Int, to newIndex: Int) {
            guard oldIndex != newIndex else { return }
            cleanupCellViews()
            updateFocusView(at: oldIndex, isFocused: false)
            updateFocusView(at: newIndex, isFocused: true)
        }

        private func cleanupCellViews() {
            cellViews = cellViews.filter { $0.value.value != nil }
        }

        private func updateFocusView(at index: Int, isFocused: Bool) {
            guard index >= 0 && index < items.count else { return }
            if let cellView = cellViews[index]?.value {
                cellView.updateFocus(isFocused: isFocused)
                return
            }

            guard let collectionView = collectionView else { return }
            let indexPath = IndexPath(item: index, section: 0)
            if let collectionItem = collectionView.item(at: indexPath) as? ClipboardCardCollectionItem,
               let cellView = collectionItem.cardCellView {
                cellViews[index] = WeakRef(value: cellView)
                cellView.updateFocus(isFocused: isFocused)
            }
        }
    }
}

/// Collection View Item for horizontal layout
class ClipboardCardCollectionItem: NSCollectionViewItem {
    var cardCellView: ClipboardCardCellView?
    
    override func loadView() {
        // 创建一个容器视图
        view = NSView()
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 确保 view 已加载
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
        // 如果已存在 cell view，更新它；否则创建新的
        if let existingView = cardCellView {
            existingView.configure(
                item: item,
                index: index,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                onDelete: onDelete
            )
        } else {
            let cellView = ClipboardCardCellView()
            cellView.configure(
                item: item,
                index: index,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                onDelete: onDelete
            )
            
            // 设置约束
            cellView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(cellView)
            NSLayoutConstraint.activate([
                cellView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cellView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                cellView.topAnchor.constraint(equalTo: view.topAnchor),
                cellView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            cardCellView = cellView
        }
    }
}

// MARK: - NSTableView Wrapper (for Left/Right Docking)

/// NSTableView 包装器，用于垂直布局（左右侧停靠）
struct ClipboardTableView: NSViewRepresentable {
    let items: [ClipboardItem]
    let dockPosition: DockPosition
    let timeRefreshTrigger: Int
    @Binding var focusedIndex: Int
    let onItemTap: (Int, ClipboardItem) -> Void
    let onItemDoubleTap: (ClipboardItem) -> Void
    let onItemDelete: (ClipboardItem) -> Void
    let onCopyAction: () -> Void
    let onFocusChange: (Int) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // 配置 ScrollView（垂直布局：垂直滚动）
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // 配置 TableView（垂直布局）
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 16) // 垂直间距
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowSizeStyle = .custom
        tableView.headerView = nil
        tableView.allowsEmptySelection = true
        tableView.focusRingType = .none
        tableView.usesAutomaticRowHeights = false
        
        // 设置列（垂直布局：列宽填满，但最小宽度为 240）
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CardColumn"))
        column.resizingMask = [] // 不允许调整大小
        // 确保列宽至少为 240，以适应卡片宽度
        // 使用 scrollView 的宽度而不是 tableView 的宽度，因为 tableView 的 bounds 可能还没有设置
        let minColumnWidth: CGFloat = 240
        let scrollViewWidth = scrollView.bounds.width > 0 ? scrollView.bounds.width : 300
        let availableWidth = scrollViewWidth - 40
        column.width = max(availableWidth, minColumnWidth)
        tableView.addTableColumn(column)
        
        // 延迟更新列宽，确保视图布局完成
        DispatchQueue.main.async {
            let finalWidth = scrollView.bounds.width > 0 ? scrollView.bounds.width - 40 : minColumnWidth
            column.width = max(finalWidth, minColumnWidth)
        }
        
        // 设置数据源和代理
        let coordinator = context.coordinator
        coordinator.tableView = tableView
        coordinator.items = items
        coordinator.dockPosition = dockPosition
        coordinator.timeRefreshTrigger = timeRefreshTrigger
        coordinator.focusedIndex = focusedIndex
        coordinator.onItemTap = onItemTap
        coordinator.onItemDoubleTap = onItemDoubleTap
        coordinator.onItemDelete = onItemDelete
        coordinator.onCopyAction = onCopyAction
        coordinator.onFocusChange = onFocusChange
        
        tableView.dataSource = coordinator
        tableView.delegate = coordinator
        
        scrollView.documentView = tableView
        
        // 创建键盘事件处理视图
        let keyHandler = KeyboardHandlerView(
            coordinator: coordinator as AnyObject,
            dockPosition: dockPosition
        )
        scrollView.addSubview(keyHandler)
        keyHandler.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyHandler.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            keyHandler.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            keyHandler.topAnchor.constraint(equalTo: scrollView.topAnchor),
            keyHandler.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        let coordinator = context.coordinator
        
        // 检查数据是否变化（更严格的比较，包括强制刷新触发器）
        let itemsChanged: Bool
        // 注意：垂直布局没有 forceRefreshTrigger 参数，但我们可以通过比较 items 来判断
        if coordinator.items.count != items.count {
            itemsChanged = true
        } else {
            // 比较每个项目的 ID、创建时间和链接元数据
            itemsChanged = !zip(coordinator.items, items).allSatisfy { oldItem, newItem in
                let basicMatch = oldItem.id == newItem.id && oldItem.createdAt == newItem.createdAt
                // 检查链接元数据是否更新
                let linkMetadataMatch = oldItem.linkTitle == newItem.linkTitle && 
                                       oldItem.linkFaviconData == newItem.linkFaviconData
                return basicMatch && linkMetadataMatch
            }
        }
        
        // 更新数据
        coordinator.items = items
        coordinator.dockPosition = dockPosition
        coordinator.timeRefreshTrigger = timeRefreshTrigger
        coordinator.focusedIndex = focusedIndex
        coordinator.onItemTap = onItemTap
        coordinator.onItemDoubleTap = onItemDoubleTap
        coordinator.onItemDelete = onItemDelete
        coordinator.onCopyAction = onCopyAction
        
        // 更新列宽以适应新的表格宽度，但确保最小宽度为 240
        if let column = tableView.tableColumns.first {
            let minColumnWidth: CGFloat = 240
            // 使用 scrollView 的宽度，因为它更可靠
            let scrollViewWidth = nsView.bounds.width > 0 ? nsView.bounds.width : 300
            let availableWidth = scrollViewWidth - 40
            column.width = max(availableWidth, minColumnWidth)
        }
        
        // 如果数据变化，强制刷新表格
        if itemsChanged {
            tableView.reloadData()
        } else if coordinator.items.count != items.count {
            // 即使 itemsChanged 为 false，但如果数量变化了，也要刷新
            tableView.reloadData()
        } else {
            // 即使数据没变化，也更新可见的 cell（用于时间刷新、链接元数据更新等）
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
                if let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ClipboardCardCellView,
                   row < items.count {
                    let item = items[row]
                    let isFocused = (row == focusedIndex)
                    cellView.configure(
                        item: item,
                        index: row,
                        isFocused: isFocused,
                        timeRefreshTrigger: timeRefreshTrigger,
                        onTap: { [weak coordinator] in
                            coordinator?.onItemTap?(row, item)
                        },
                        onDoubleTap: { [weak coordinator] in
                            coordinator?.onItemDoubleTap?(item)
                        },
                        onDelete: { [weak coordinator] in
                            coordinator?.onItemDelete?(item)
                        }
                    )
                }
            }
        }
        
        // 监听链接元数据更新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LinkMetadataUpdated"),
            object: nil,
            queue: .main
        ) { [weak tableView, weak coordinator] notification in
            guard let tableView = tableView, let coordinator = coordinator,
                  let itemId = notification.userInfo?["itemId"] as? UUID else { return }
            
            // 查找对应的行并刷新
            if let row = coordinator.items.firstIndex(where: { $0.id == itemId }) {
                if let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ClipboardCardCellView,
                   row < coordinator.items.count {
                    let item = coordinator.items[row]
                    let isFocused = (row == coordinator.focusedIndex)
                    cellView.configure(
                        item: item,
                        index: row,
                        isFocused: isFocused,
                        timeRefreshTrigger: coordinator.timeRefreshTrigger,
                        onTap: { [weak coordinator] in
                            coordinator?.onItemTap?(row, item)
                        },
                        onDoubleTap: { [weak coordinator] in
                            coordinator?.onItemDoubleTap?(item)
                        },
                        onDelete: { [weak coordinator] in
                            coordinator?.onItemDelete?(item)
                        }
                    )
                }
            }
        }
        
        // 滚动到焦点项
        if focusedIndex >= 0 && focusedIndex < items.count {
            tableView.scrollRowToVisible(focusedIndex)
            tableView.selectRowIndexes(IndexSet(integer: focusedIndex), byExtendingSelection: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var tableView: NSTableView?
        var items: [ClipboardItem] = []
        var dockPosition: DockPosition = .bottom
        var timeRefreshTrigger: Int = 0
        var focusedIndex: Int = 0
        var onItemTap: ((Int, ClipboardItem) -> Void)?
        var onItemDoubleTap: ((ClipboardItem) -> Void)?
        var onItemDelete: ((ClipboardItem) -> Void)?
        var onCopyAction: (() -> Void)?
        var onFocusChange: ((Int) -> Void)?
        
        // 存储 cell views 以便更新（使用弱引用避免循环引用）
        private var cellViews: [Int: WeakRef<ClipboardCardCellView>] = [:]
        
        // 清理过期的 cell views 引用
        func cleanupCellViews() {
            cellViews = cellViews.filter { $0.value.value != nil }
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return items.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0 && row < items.count else { 
                print("⚠️ NSTableView: row \(row) 超出范围，items.count = \(items.count)")
                return nil 
            }
            
            // 确保按正确顺序获取项目（items 已经按 createdAt 倒序排序）
            // 索引 0 应该是最新的项目
            let item = items[row]
            let isFocused = (row == focusedIndex)
            
            // 调试：打印前几个项目的顺序
            if row < 3 {
                print("📋 NSTableView row \(row): item.id = \(item.id.uuidString.prefix(8)), createdAt = \(item.createdAt)")
            }
            
            // 重用或创建 cell view
            let identifier = NSUserInterfaceItemIdentifier("ClipboardCardCell")
            var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? ClipboardCardCellView
            
            if cellView == nil {
                cellView = ClipboardCardCellView()
                cellView?.identifier = identifier
            }
            
            // 清理过期的引用（在存储新引用之前）
            cleanupCellViews()
            
            // 更新 cell view（每次都要更新，确保数据正确）
            cellView?.configure(
                item: item,
                index: row,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: { [weak self] in
                    self?.onItemTap?(row, item)
                },
                onDoubleTap: { [weak self] in
                    self?.onItemDoubleTap?(item)
                },
                onDelete: { [weak self] in
                    self?.onItemDelete?(item)
                }
            )
            
            // 存储 cell view 引用以便后续更新（使用弱引用）
            if let cellView = cellView {
                cellViews[row] = WeakRef(value: cellView)
            }
            
            return cellView
        }
        
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 240
        }
        
        func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
            let minColumnWidth: CGFloat = 240
            let availableWidth = tableView.bounds.width > 0 ? tableView.bounds.width - 40 : minColumnWidth
            return max(availableWidth, minColumnWidth)
        }
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            return ClipboardTableRowView()
        }
        
        // MARK: - Keyboard Events
        
        func moveFocus(by offset: Int, in tableView: NSTableView) {
            let totalCount = items.count
            guard totalCount > 0 else { return }
            
            let newIndex = focusedIndex + offset
            guard newIndex >= 0 && newIndex < totalCount else { return }
            
            // 更新旧焦点
            if let oldCellViewRef = cellViews[focusedIndex], let oldCellView = oldCellViewRef.value {
                oldCellView.updateFocus(isFocused: false)
            }
            
            focusedIndex = newIndex
            onFocusChange?(newIndex)
            
            // 更新新焦点
            if let newCellViewRef = cellViews[newIndex], let newCellView = newCellViewRef.value {
                newCellView.updateFocus(isFocused: true)
            }
            
            // 更新选中行
            tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(newIndex)
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let selectedRow = tableView.selectedRow
            if selectedRow >= 0 && selectedRow < items.count {
                focusedIndex = selectedRow
                onFocusChange?(selectedRow)
            }
        }
    }
}

// MARK: - Custom Cell View (Pure AppKit)

/// 纯 AppKit 卡片视图，不使用 SwiftUI
class ClipboardCardCellView: NSView {
    private var cardView: ClipboardCardView?
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
        // 检查 item 是否改变（通过 ID 比较）
        let itemChanged = currentItem?.id != item.id
        
        // 检查链接元数据是否更新（通过比较 linkTitle 和 linkFaviconData）
        let linkMetadataChanged = item.type == .link && (
            currentItem?.linkTitle != item.linkTitle ||
            currentItem?.linkFaviconData != item.linkFaviconData
        )
        
        // 保存配置信息
        currentItem = item
        currentIndex = index
        currentIsFocused = isFocused
        currentTimeRefreshTrigger = timeRefreshTrigger
        currentOnTap = onTap
        currentOnDoubleTap = onDoubleTap
        currentOnDelete = onDelete
        
        // 如果 item 改变了或链接元数据更新了，需要重新创建整个卡片视图
        if itemChanged || linkMetadataChanged || cardView == nil {
            // 移除旧的卡片视图及其约束
            if let oldCardView = cardView {
                oldCardView.removeFromSuperview()
                // 移除所有约束
                NSLayoutConstraint.deactivate(oldCardView.constraints)
                oldCardView.removeConstraints(oldCardView.constraints)
            }
            cardView = nil
            
            // 创建新的卡片视图
            let newCardView = ClipboardCardView(
                item: item,
                index: index,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                onDelete: onDelete
            )
            newCardView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(newCardView)
            
            // 设置固定尺寸约束，使用固定宽高，并确保与父视图对齐
            // 注意：不要使用 top/bottom/leading/trailing，因为这会导致与内部约束冲突
            NSLayoutConstraint.activate([
                newCardView.widthAnchor.constraint(equalToConstant: 240),
                newCardView.heightAnchor.constraint(equalToConstant: 240),
                newCardView.centerXAnchor.constraint(equalTo: centerXAnchor),
                newCardView.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            
            cardView = newCardView
        } else if let existingView = cardView {
            // 如果 item 没改变，只更新焦点状态和时间
            existingView.update(
                item: item,
                index: index,
                isFocused: isFocused,
                timeRefreshTrigger: timeRefreshTrigger,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                onDelete: onDelete
            )
        }
    }
    
    func updateFocus(isFocused: Bool) {
        guard let item = currentItem,
              let onTap = currentOnTap,
              let onDoubleTap = currentOnDoubleTap,
              let onDelete = currentOnDelete else { return }
        
        currentIsFocused = isFocused
        cardView?.update(
            item: item,
            index: currentIndex,
            isFocused: isFocused,
            timeRefreshTrigger: currentTimeRefreshTrigger,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onDelete: onDelete
        )
    }
}

/// 纯 AppKit 卡片视图实现 - 支持 3D 悬停效果
class ClipboardCardView: NSView {
    private var item: ClipboardItem
    private var index: Int
    private var isFocused: Bool
    private var timeRefreshTrigger: Int
    private var onTap: () -> Void
    private var onDoubleTap: () -> Void
    private var onDelete: () -> Void
    
    // 子视图
    private var containerView: NSView?  // 内容容器（用于裁剪圆角）
    private var headerView: NSView?
    private var contentView: NSView?
    private var shortcutBadge: NSView?
    private var borderView: BorderOverlayView?
    
    // MARK: - 炫酷模式相关属性
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering: Bool = false
    private var mouseLocation: CGPoint = .zero
    private var shineLayer: CAGradientLayer?
    private var originalShadowRadius: CGFloat = 8
    private var originalShadowOpacity: Float = 0.15
    
    // 配置常量
    private let maxRotationAngle: CGFloat = 8.0   // 最大倾斜角度
    private let hoverScale: CGFloat = 1.03        // 悬停放大比例
    
    // 检查是否启用炫酷模式
    private var isCoolModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableCoolMode")
    }
    
    init(
        item: ClipboardItem,
        index: Int,
        isFocused: Bool,
        timeRefreshTrigger: Int,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.index = index
        self.isFocused = isFocused
        self.timeRefreshTrigger = timeRefreshTrigger
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onDelete = onDelete
        
        super.init(frame: .zero)
        
        setupView()
        updateBorderState()
        
        // 监听炫酷模式变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoolModeChanged(_:)),
            name: NSNotification.Name("CoolModeChanged"),
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 炫酷模式切换处理
    
    @objc private func handleCoolModeChanged(_ notification: Notification) {
        guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
        
        if !enabled {
            // 关闭炫酷模式时，清理所有特效
            cleanupCoolModeEffects()
        }
        
        // 更新追踪区域（开启时添加，关闭时移除）
        updateTrackingAreas()
    }
    
    /// 清理炫酷模式特效
    private func cleanupCoolModeEffects() {
        // 重置悬停状态
        isHovering = false
        
        // 移除反光层
        removeShineLayer()
        
        // 重置 3D 变换（无动画，直接重置）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.transform = CATransform3DIdentity
        CATransaction.commit()
        
        // 重置阴影
        layer?.shadowRadius = originalShadowRadius
        layer?.shadowOpacity = originalShadowOpacity
    }
    
    func update(
        item: ClipboardItem,
        index: Int,
        isFocused: Bool,
        timeRefreshTrigger: Int,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        // 更新所有属性
        self.item = item
        self.index = index
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onDelete = onDelete
        
        // 更新右键菜单（如果 item 类型改变）
        self.menu = createContextMenu()
        
        // 更新焦点状态
        if self.isFocused != isFocused {
            self.isFocused = isFocused
            updateBorderState()
        }
        
        // 更新时间标签
        if let header = headerView,
           let timeLabel = header.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("timeLabel") }) as? NSTextField {
            timeLabel.stringValue = item.relativeTimeString
        }
        
        // 更新快捷键徽章
        if index < 9 {
            if shortcutBadge == nil {
                let badge = createShortcutBadge()
                badge.translatesAutoresizingMaskIntoConstraints = false
                addSubview(badge)
                NSLayoutConstraint.activate([
                    badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                    badge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
                ])
                shortcutBadge = badge
            } else if let badge = shortcutBadge,
                      let label = badge.subviews.first as? NSTextField {
                label.stringValue = "⌘\(index + 1)"
            }
        } else {
            if let badge = shortcutBadge {
                badge.removeFromSuperview()
                // 清理约束
                NSLayoutConstraint.deactivate(badge.constraints)
                badge.removeConstraints(badge.constraints)
            }
            shortcutBadge = nil
        }
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = false // 保持 false 以支持阴影和 3D 变换
        
        // 设置基础阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: 4)
        layer?.shadowRadius = originalShadowRadius
        layer?.shadowOpacity = originalShadowOpacity
        
        // 设置右键菜单
        self.menu = createContextMenu()
        
        // 创建内容容器（用于裁剪圆角）
        setupContainerView()
        setupSubviews()
        setupBorderView()
    }
    
    private func setupContainerView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true  // 裁剪内容到圆角
        container.layer?.backgroundColor = NSColor.white.cgColor
        
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        containerView = container
    }
    
    // MARK: - 鼠标追踪设置
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // 移除旧的追踪区域
        if let trackingArea = hoverTrackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // 只有在炫酷模式开启时才添加追踪区域
        guard isCoolModeEnabled else { return }
        
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeInKeyWindow,
            .inVisibleRect
        ]
        
        hoverTrackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(hoverTrackingArea!)
    }
    
    // MARK: - 鼠标事件处理
    
    override func mouseEntered(with event: NSEvent) {
        guard isCoolModeEnabled else { return }
        isHovering = true
        animateHoverState(hovering: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        guard isCoolModeEnabled else { return }
        isHovering = false
        animateHoverState(hovering: false)
        resetTransform()
    }
    
    override func mouseMoved(with event: NSEvent) {
        guard isCoolModeEnabled, isHovering else { return }
        let localPoint = convert(event.locationInWindow, from: nil)
        // AppKit Y 轴翻转（从底部向上 → 从顶部向下）
        mouseLocation = CGPoint(x: localPoint.x, y: bounds.height - localPoint.y)
        apply3DTransform()
        updateShinePosition()
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            handleDoubleClick()
        } else {
            handleClick()
        }
    }
    
    // MARK: - 3D 变换效果
    
    private func apply3DTransform() {
        guard let layer = self.layer else { return }
        
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        
        // 计算旋转角度
        let percentX = (mouseLocation.x - centerX) / centerX
        let percentY = (mouseLocation.y - centerY) / centerY
        
        let rotationY = percentX * maxRotationAngle  // 绕 Y 轴（左右倾斜）
        let rotationX = -percentY * maxRotationAngle // 绕 X 轴（上下倾斜）
        
        // 创建 3D 变换
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 500.0  // 透视效果
        transform = CATransform3DRotate(transform, rotationX * .pi / 180, 1, 0, 0)
        transform = CATransform3DRotate(transform, rotationY * .pi / 180, 0, 1, 0)
        transform = CATransform3DScale(transform, hoverScale, hoverScale, 1)
        
        // 应用变换（无动画，跟手）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = transform
        CATransaction.commit()
    }
    
    private func resetTransform() {
        guard let layer = self.layer else { return }
        
        // 弹簧动画回弹
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = layer.transform
        animation.toValue = CATransform3DIdentity
        animation.damping = 15
        animation.stiffness = 200
        animation.duration = animation.settlingDuration
        animation.isRemovedOnCompletion = true
        animation.fillMode = .forwards
        
        layer.add(animation, forKey: "resetTransform")
        layer.transform = CATransform3DIdentity
    }
    
    // MARK: - 悬停状态动画
    
    private func animateHoverState(hovering: Bool) {
        guard let layer = self.layer else { return }
        
        // 阴影动画
        let shadowRadiusAnim = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadiusAnim.fromValue = layer.shadowRadius
        shadowRadiusAnim.toValue = hovering ? 20 : originalShadowRadius
        shadowRadiusAnim.duration = 0.25
        shadowRadiusAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(shadowRadiusAnim, forKey: "shadowRadius")
        layer.shadowRadius = hovering ? 20 : originalShadowRadius
        
        let shadowOpacityAnim = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacityAnim.fromValue = layer.shadowOpacity
        shadowOpacityAnim.toValue = hovering ? 0.3 : originalShadowOpacity
        shadowOpacityAnim.duration = 0.25
        shadowOpacityAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(shadowOpacityAnim, forKey: "shadowOpacity")
        layer.shadowOpacity = hovering ? 0.3 : originalShadowOpacity
        
        // 显示/隐藏反光层
        if hovering {
            setupShineLayer()
        } else {
            removeShineLayer()
        }
    }
    
    // MARK: - 动态反光层
    
    private func setupShineLayer() {
        guard shineLayer == nil, let containerLayer = containerView?.layer else { return }
        
        let shine = CAGradientLayer()
        shine.type = .radial
        shine.colors = [
            NSColor.white.withAlphaComponent(0.25).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        shine.locations = [0.0, 1.0]
        shine.startPoint = CGPoint(x: 0.5, y: 0.5)
        shine.endPoint = CGPoint(x: 1.0, y: 1.0)
        shine.frame = bounds
        shine.cornerRadius = 12
        
        // 添加到容器层的最上方（在内容之上）
        containerLayer.addSublayer(shine)
        
        shineLayer = shine
        updateShinePosition()
    }
    
    private func removeShineLayer() {
        shineLayer?.removeFromSuperlayer()
        shineLayer = nil
    }
    
    private func updateShinePosition() {
        guard let shine = shineLayer else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // 将反光中心定位到鼠标位置
        let normalizedX = mouseLocation.x / bounds.width
        let normalizedY = mouseLocation.y / bounds.height
        shine.startPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        CATransaction.commit()
    }
    
    private func setupBorderView() {
        let view = BorderOverlayView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        // 确保边框在圆角内
        view.layer?.masksToBounds = true
        
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        borderView = view
    }
    
    private func updateBorderState() {
        guard let layer = borderView?.layer else { return }
        
        // 使用事务禁用隐式动画，确保响应迅速
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if isFocused {
            // 选中时使用更深的天蓝色边框
            // 使用 System Blue (R:0 G:0.48 B:1.0)
            let deepSkyBlue = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            layer.borderColor = deepSkyBlue.cgColor
            layer.borderWidth = 4
        } else {
            // 未选中时使用淡边框
            layer.borderColor = NSColor.black.withAlphaComponent(0.1).cgColor
            layer.borderWidth = 1
        }
        
        CATransaction.commit()
    }
    
    private func setupSubviews() {
        guard let container = containerView else { return }
        
        // 创建头部视图（添加到容器中）
        let header = createHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 54)
        ])
        headerView = header
        
        // 创建内容视图（添加到容器中）
        let content = createContentView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: header.bottomAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        contentView = content
        
        // 创建快捷键徽章（添加到主视图，在容器之上）
        if index < 9 {
            let badge = createShortcutBadge()
            badge.translatesAutoresizingMaskIntoConstraints = false
            addSubview(badge)
            NSLayoutConstraint.activate([
                badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                badge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
            ])
            shortcutBadge = badge
        }
    }
    
    private func createHeaderView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        
        // 背景色
        let themeColor: NSColor
        if let hexColor = NSColor(hex: item.themeColorHex) {
            themeColor = hexColor
        } else {
            // 如果解析失败，使用默认颜色（灰色）
            themeColor = NSColor(hex: "#666666") ?? .systemGray
        }
        container.layer?.backgroundColor = themeColor.cgColor
        
        // App 图标
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        // 加载 App 图标
        Task {
            let icon = await AppIconCache.shared.load(bundleID: item.sourceAppBundleID)
            await MainActor.run {
                iconView.image = icon
            }
        }
        
        // 类型和时间标签
        let typeLabel = NSTextField(labelWithString: item.type.displayName)
        typeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        typeLabel.textColor = .white.withAlphaComponent(0.9)
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(typeLabel)
        
        let timeLabel = NSTextField(labelWithString: item.relativeTimeString)
        timeLabel.font = .systemFont(ofSize: 10)
        timeLabel.textColor = .white.withAlphaComponent(0.75)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.identifier = NSUserInterfaceItemIdentifier("timeLabel") // 用于后续更新
        container.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
            
            typeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            typeLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            
            timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            timeLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2)
        ])
        
        return container
    }
    
    private func createContentView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        
        switch item.type {
        case .text, .code:
            let textView = createTextView()
            container.addSubview(textView)
            textView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                textView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                textView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
            ])
            
        case .image:
            let imageView = createImageView()
            container.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 90),
                imageView.heightAnchor.constraint(equalToConstant: 90)
            ])
            
        case .link:
            let linkView = createLinkView()
            container.addSubview(linkView)
            linkView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                linkView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                linkView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            
        case .file:
            let fileView = createFileView()
            container.addSubview(fileView)
            fileView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                fileView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                fileView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            
        case .color:
            let colorView = createColorView()
            container.addSubview(colorView)
            colorView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                colorView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                colorView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }
        
        return container
    }
    
    private func createTextView() -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textContainer?.containerSize = NSSize(width: 216, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        
        // 加载富文本
        if let rtfData = item.richTextData {
            Task {
                // 检测是否为 HTML
                let isHTML = ClipboardCardView.detectHTMLFormat(in: rtfData)
                let result = await RichTextCache.shared.load(data: rtfData, key: rtfData.sha256Hash, isHTML: isHTML)
                await MainActor.run {
                    textView.textStorage?.setAttributedString(NSAttributedString(result.attributedString))
                    if let bgColor = result.backgroundColor {
                        // 从 SwiftUI Color 转换为 NSColor
                        let nsColor = NSColor(bgColor)
                        self.contentView?.layer?.backgroundColor = nsColor.cgColor
                    }
                }
            }
        } else {
            textView.string = item.contentPreview
        }
        
        if item.type == .code {
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            textView.font = .systemFont(ofSize: 12)
        }
        textView.textColor = .labelColor
        
        return textView
    }
    
    // 辅助方法：检测 HTML 格式
    private static func detectHTMLFormat(in data: Data) -> Bool {
        if data.count >= 5 {
            let prefix = data.prefix(5)
            if let prefixString = String(data: prefix, encoding: .utf8),
               prefixString.hasPrefix("{\\rtf") {
                return false
            }
        }
        if let content = String(data: data, encoding: .utf8) {
            let lowerContent = content.lowercased()
            return lowerContent.contains("<html") ||
                   lowerContent.contains("<!doctype html") ||
                   lowerContent.contains("<div") ||
                   lowerContent.contains("<span")
        }
        return false
    }
    
    private func createImageView() -> NSView {
        let container = NSView()
        
        // 图片缩略图
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        if let imageData = item.imageData {
            Task {
                let image = await ImageThumbnailCache.shared.downsample(data: imageData, to: CGSize(width: 90, height: 90), key: imageData.sha256Hash)
                await MainActor.run {
                    imageView.image = image
                }
            }
        } else {
            // 占位符图标
            imageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            imageView.contentTintColor = .secondaryLabelColor
        }
        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 图片名（从 content 中提取，如果是文件路径）- 添加截断处理
        var nameLabel: NSTextField?
        let imageName: String
        if item.content.starts(with: "/") {
            // 是文件路径
            imageName = URL(fileURLWithPath: item.content).lastPathComponent
        } else {
            // 可能是 "Image" 或其他，使用默认名称
            imageName = "图片"
        }
        
        if !imageName.isEmpty {
            let truncatedImageName = truncateString(imageName, maxLength: 30)
            let label = NSTextField(labelWithString: truncatedImageName)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .labelColor
            label.alignment = .center
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byTruncatingMiddle
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            nameLabel = label
        }
        
        // 文件大小（如果有）
        var sizeLabel: NSTextField?
        if let fileSize = item.fileSize {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            let sizeText = formatter.string(fromByteCount: fileSize)
            let label = NSTextField(labelWithString: sizeText)
            label.font = .systemFont(ofSize: 10)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            sizeLabel = label
        }
        
        // 布局约束 - 垂直居中布局
        if let nameLabel = nameLabel, let sizeLabel = sizeLabel {
            // 有图片名和文件大小的情况
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20),
                imageView.widthAnchor.constraint(equalToConstant: 90),
                imageView.heightAnchor.constraint(equalToConstant: 90),
                
                nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
                
                sizeLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                sizeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4)
            ])
        } else if let nameLabel = nameLabel {
            // 只有图片名的情况
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
                imageView.widthAnchor.constraint(equalToConstant: 90),
                imageView.heightAnchor.constraint(equalToConstant: 90),
                
                nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
            ])
        } else {
            // 只有缩略图的情况
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 90),
                imageView.heightAnchor.constraint(equalToConstant: 90)
            ])
        }
        
        return container
    }
    
    private func createLinkView() -> NSView {
        let container = NSView()
        
        // Favicon 或默认图标（参考图片类型，使用更大的尺寸）
        let iconView = NSImageView()
        if let faviconData = item.linkFaviconData {
            Task {
                let image = await ImageThumbnailCache.shared.downsample(data: faviconData, to: CGSize(width: 90, height: 90), key: faviconData.sha256Hash)
                await MainActor.run {
                    iconView.image = image
                }
            }
        } else {
            iconView.image = NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)
            iconView.contentTintColor = .systemBlue
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        // 网站标题（如果有）- 添加截断处理
        var titleLabel: NSTextField?
        if let title = item.linkTitle, !title.isEmpty {
            let truncatedTitle = truncateString(title, maxLength: 30)
            let label = NSTextField(labelWithString: truncatedTitle)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .labelColor
            label.alignment = .center
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byTruncatingMiddle
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            titleLabel = label
        }
        
        // URL（总是显示，作为文件大小位置）- 添加截断处理
        let truncatedURL = truncateString(item.content, maxLength: 40)
        let urlLabel = NSTextField(labelWithString: truncatedURL)
        urlLabel.font = .systemFont(ofSize: 10)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.alignment = .center
        urlLabel.maximumNumberOfLines = 3
        urlLabel.lineBreakMode = .byTruncatingMiddle
        container.addSubview(urlLabel)
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 布局约束 - 参考图片类型的垂直居中布局
        if let titleLabel = titleLabel {
            // 有标题的情况：图标 -> 标题 -> URL
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20),
                iconView.widthAnchor.constraint(equalToConstant: 90),
                iconView.heightAnchor.constraint(equalToConstant: 90),
                
                titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
                
                urlLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
                urlLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                urlLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
            ])
        } else {
            // 没有标题的情况：图标 -> URL
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
                iconView.widthAnchor.constraint(equalToConstant: 90),
                iconView.heightAnchor.constraint(equalToConstant: 90),
                
                urlLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                urlLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
                urlLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                urlLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
            ])
        }
        
        return container
    }
    
    private func createFileView() -> NSView {
        let container = NSView()
        
        // 文件图标
        let iconView = NSImageView()
        if let filePath = item.firstFilePath {
            Task.detached {
                let icon = NSWorkspace.shared.icon(forFile: filePath)
                await MainActor.run {
                    iconView.image = icon
                }
            }
        } else {
            iconView.image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
            iconView.contentTintColor = .systemOrange
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        // 文件名 - 添加截断处理
        var nameLabel: NSTextField?
        if let fileName = item.fileName {
            let truncatedFileName = truncateString(fileName, maxLength: 30)
            let label = NSTextField(labelWithString: truncatedFileName)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .labelColor
            label.alignment = .center
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byTruncatingMiddle
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            nameLabel = label
        }
        
        // 文件大小（如果有）
        var sizeLabel: NSTextField?
        if let fileSize = item.fileSize {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            let sizeText = formatter.string(fromByteCount: fileSize)
            let label = NSTextField(labelWithString: sizeText)
            label.font = .systemFont(ofSize: 10)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            sizeLabel = label
        }
        
        // 布局约束 - 垂直居中布局（参考图片类型）
        if let nameLabel = nameLabel, let sizeLabel = sizeLabel {
            // 有文件名和文件大小的情况
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20),
                iconView.widthAnchor.constraint(equalToConstant: 80),
                iconView.heightAnchor.constraint(equalToConstant: 80),
                
                nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
                
                sizeLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                sizeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4)
            ])
        } else if let nameLabel = nameLabel {
            // 只有文件名的情况
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
                iconView.widthAnchor.constraint(equalToConstant: 80),
                iconView.heightAnchor.constraint(equalToConstant: 80),
                
                nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
            ])
        } else {
            // 只有图标的情况
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 80),
                iconView.heightAnchor.constraint(equalToConstant: 80)
            ])
        }
        
        return container
    }
    
    private func createColorView() -> NSView {
        let container = NSView()
        
        // 颜色方块（与文件图标样式一致）
        let colorView = NSView()
        colorView.wantsLayer = true
        if let color = NSColor(hex: item.content) {
            colorView.layer?.backgroundColor = color.cgColor
        } else {
            colorView.layer?.backgroundColor = NSColor.gray.cgColor
        }
        colorView.layer?.cornerRadius = 10
        colorView.layer?.borderWidth = 1
        colorView.layer?.borderColor = NSColor.black.withAlphaComponent(0.1).cgColor
        colorView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorView)
        
        // 颜色代码（与文件名样式一致）
        let codeLabel = NSTextField(labelWithString: item.content)
        codeLabel.font = .systemFont(ofSize: 11)
        codeLabel.textColor = .labelColor
        codeLabel.alignment = .center
        codeLabel.maximumNumberOfLines = 1
        codeLabel.lineBreakMode = .byTruncatingMiddle
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(codeLabel)
        
        // 布局约束 - 与文件卡片保持一致
        NSLayoutConstraint.activate([
            colorView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            colorView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
            colorView.widthAnchor.constraint(equalToConstant: 80),
            colorView.heightAnchor.constraint(equalToConstant: 80),
            
            codeLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            codeLabel.topAnchor.constraint(equalTo: colorView.bottomAnchor, constant: 8),
            codeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
            codeLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func createShortcutBadge() -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        badge.layer?.cornerRadius = 8
        
        let label = NSTextField(labelWithString: "⌘\(index + 1)")
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            badge.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return badge
    }
    
    override func layout() {
        super.layout()
        // 不需要额外的 layout 逻辑，layer 属性已在 init/update 中配置
    }
    
    @objc private func handleClick() {
        onTap()
    }
    
    @objc private func handleDoubleClick() {
        onDoubleTap()
    }
    
    @objc private func handleDelete() {
        onDelete()
    }
    
    @objc private func handleJumpToLink() {
        guard let url = URL(string: item.content) else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func handleCopyFileName() {
        let fileName: String
        if item.type == .image && item.content.starts(with: "/") {
            fileName = URL(fileURLWithPath: item.content).lastPathComponent
        } else if let filePath = item.firstFilePath {
            fileName = URL(fileURLWithPath: filePath).lastPathComponent
        } else {
            return
        }
        PasteboardManager.shared.writeToPasteboard(content: fileName)
    }
    
    @objc private func handleCopyFilePath() {
        let filePath: String
        if item.type == .image && item.content.starts(with: "/") {
            filePath = item.content
        } else if let path = item.firstFilePath {
            filePath = path
        } else {
            return
        }
        PasteboardManager.shared.writeToPasteboard(content: filePath)
    }
    
    @objc private func handleRevealInFinder() {
        let filePath: String
        if item.type == .image && item.content.starts(with: "/") {
            filePath = item.content
        } else if let path = item.firstFilePath {
            filePath = path
        } else {
            return
        }
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    /// 创建右键菜单
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 根据类型添加不同的菜单项
        switch item.type {
        case .link:
            // 链接类型：跳转至、删除
            let jumpItem = NSMenuItem(title: "跳转至", action: #selector(handleJumpToLink), keyEquivalent: "")
            jumpItem.target = self
            menu.addItem(jumpItem)
            menu.addItem(NSMenuItem.separator())
            let deleteItem = NSMenuItem(title: "删除", action: #selector(handleDelete), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
            
        case .file, .image:
            // 文件/图片类型：复制文件名、复制文件地址、跳转至文件夹、删除
            let copyNameItem = NSMenuItem(title: "复制文件名", action: #selector(handleCopyFileName), keyEquivalent: "")
            copyNameItem.target = self
            menu.addItem(copyNameItem)
            
            let copyPathItem = NSMenuItem(title: "复制文件地址", action: #selector(handleCopyFilePath), keyEquivalent: "")
            copyPathItem.target = self
            menu.addItem(copyPathItem)
            
            let revealItem = NSMenuItem(title: "跳转至文件夹", action: #selector(handleRevealInFinder), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
            
            menu.addItem(NSMenuItem.separator())
            let deleteItem = NSMenuItem(title: "删除", action: #selector(handleDelete), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
            
        default:
            // 其他类型：只有删除
            let deleteItem = NSMenuItem(title: "删除", action: #selector(handleDelete), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
        }
        
        return menu
    }
    
    /// 截断字符串辅助方法
    private func truncateString(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else { return string }
        let truncated = String(string.prefix(maxLength))
        return truncated + "..."
    }
}

/// 边框覆盖视图，用于显示选中边框并拦截点击事件
class BorderOverlayView: NSView {
    // 拦截所有点击事件，确保整个卡片区域都可点击
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 如果点击在自身范围内，返回 self 以拦截事件
        if bounds.contains(point) {
            return self
        }
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        // 转发点击事件给父视图 ClipboardCardView
        if let cardView = superview as? ClipboardCardView {
            cardView.mouseDown(with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // 右键点击显示父视图的上下文菜单
        if let cardView = superview as? ClipboardCardView {
            // 先触发选中
            cardView.mouseDown(with: event)
            // 然后显示菜单
            if let menu = cardView.menu {
                NSMenu.popUpContextMenu(menu, with: event, for: cardView)
            }
        }
    }
    
    // MARK: - 炫酷模式：转发鼠标移动事件
    
    override func mouseEntered(with event: NSEvent) {
        // 转发给父视图以触发悬停效果
        if let cardView = superview as? ClipboardCardView {
            cardView.mouseEntered(with: event)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        // 转发给父视图以结束悬停效果
        if let cardView = superview as? ClipboardCardView {
            cardView.mouseExited(with: event)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        // 转发给父视图以更新 3D 变换
        if let cardView = superview as? ClipboardCardView {
            cardView.mouseMoved(with: event)
        }
    }
}

// MARK: - Color Extensions

extension NSColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除 # 前缀
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }
        
        // 只保留十六进制字符
        hexString = hexString.filter { $0.isHexDigit }
        
        var int: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&int) else {
            print("⚠️ NSColor(hex:) 解析失败: \(hex)")
            return nil
        }
        
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            print("⚠️ NSColor(hex:) 长度无效: \(hexString.count) (期望 3, 6 或 8)")
            return nil
        }
        
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
    
    /// 从 SwiftUI Color 创建 NSColor
    convenience init(_ color: Color) {
        // 使用 NSColor 的通用方法
        // 通过 NSColor 的 resolve 方法获取实际颜色值
        let resolved = color.resolve(in: EnvironmentValues())
        self.init(
            red: CGFloat(resolved.red),
            green: CGFloat(resolved.green),
            blue: CGFloat(resolved.blue),
            alpha: CGFloat(resolved.opacity)
        )
    }
}

// MARK: - Custom Row View

/// 自定义 Table Row View，用于更好的视觉效果
class ClipboardTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // 不绘制默认选中背景
    }
}

// MARK: - Weak Reference Helper

/// 弱引用包装器，用于避免循环引用
class WeakRef<T: AnyObject> {
    weak var value: T?
    init(value: T) {
        self.value = value
    }
}

// MARK: - Keyboard Handler

/// 键盘事件处理视图
class KeyboardHandlerView: NSView {
    weak var coordinator: AnyObject?
    let dockPosition: DockPosition
    
    init(coordinator: AnyObject, dockPosition: DockPosition) {
        self.coordinator = coordinator
        self.dockPosition = dockPosition
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // 允许点击穿透
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.keyCode == 8 { // Cmd + C
            if let tableCoordinator = coordinator as? ClipboardTableView.Coordinator {
                tableCoordinator.onCopyAction?()
            } else if let collectionCoordinator = coordinator as? ClipboardHorizontalCollectionView.HorizontalCoordinator {
                collectionCoordinator.onCopyAction?()
            }
            return
        }
        
        switch event.keyCode {
        case 123: // Left Arrow
            if dockPosition.isHorizontal {
                if let collectionCoordinator = coordinator as? ClipboardHorizontalCollectionView.HorizontalCoordinator,
                   let collectionView = collectionCoordinator.collectionView {
                    collectionCoordinator.moveFocus(by: -1, in: collectionView)
                }
            }
        case 124: // Right Arrow
            if dockPosition.isHorizontal {
                if let collectionCoordinator = coordinator as? ClipboardHorizontalCollectionView.HorizontalCoordinator,
                   let collectionView = collectionCoordinator.collectionView {
                    collectionCoordinator.moveFocus(by: 1, in: collectionView)
                }
            }
        case 126: // Up Arrow
            if !dockPosition.isHorizontal {
                if let tableCoordinator = coordinator as? ClipboardTableView.Coordinator,
                   let tableView = tableCoordinator.tableView {
                    tableCoordinator.moveFocus(by: -1, in: tableView)
                }
            }
        case 125: // Down Arrow
            if !dockPosition.isHorizontal {
                if let tableCoordinator = coordinator as? ClipboardTableView.Coordinator,
                   let tableView = tableCoordinator.tableView {
                    tableCoordinator.moveFocus(by: 1, in: tableView)
                }
            }
        case 36: // Return
            if let tableCoordinator = coordinator as? ClipboardTableView.Coordinator {
                tableCoordinator.onCopyAction?()
            } else if let collectionCoordinator = coordinator as? ClipboardHorizontalCollectionView.HorizontalCoordinator {
                collectionCoordinator.onCopyAction?()
            }
        default:
            super.keyDown(with: event)
        }
    }
}
