//
// Created by Eugene Kazaev on 08/09/2020.
// Copyright (c) 2020 CocoaPods. All rights reserved.
//

import ChatLayout
import Foundation
import UIKit

@available(iOS 13.0, *)
typealias DataSource = UICollectionViewDiffableDataSource<DiffableSection, DiffableCell>
@available(iOS 13.0, *)
typealias Snapshot = NSDiffableDataSourceSnapshot<DiffableSection, DiffableCell>

struct DiffableSection: Hashable {

    let section: Section

    init(section: Section) {
        self.section = section
    }

    func hash(into hasher: inout Hasher) {
        return hasher.combine(section.differenceIdentifier)
    }

    static func ==(lhs: DiffableSection, rhs: DiffableSection) -> Bool {
        return lhs.section.differenceIdentifier == rhs.section.differenceIdentifier
    }

}

struct DiffableCell: Hashable {

    let cell: Cell

    init(cell: Cell) {
        self.cell = cell
    }

//    func hash(into hasher: inout Hasher) {
//        return hasher.combine(cell.differenceIdentifier)
//    }
//
//    static func ==(lhs: DiffableCell, rhs: DiffableCell) -> Bool {
//        return lhs.cell.differenceIdentifier == rhs.cell.differenceIdentifier
//    }

}

@available(iOS 13.0, *)
final class DiffableChatCollectionDataSource: NSObject, ChatCollectionDataSource {

    var collectionView: UICollectionView {
        didSet {
            let diffableDataSource = DataSource(collectionView: collectionView, cellProvider: { [weak self] collectionView, indexPath, cell -> UICollectionViewCell? in
                guard let self = self else {
                    return nil
                }
                switch cell.cell {
                case let .message(message, bubbleType: bubbleType):
                    switch message.data {
                    case let .text(text):
                        let cell = self.createTextCell(messageId: message.id, indexPath: indexPath, text: text, alignment: cell.cell.alignment, user: message.owner, bubbleType: bubbleType, status: message.status, messageType: message.type)
                        return cell
                    case let .url(url, isLocallyStored: _):
                        return self.createURLCell(messageId: message.id, indexPath: indexPath, url: url, alignment: cell.cell.alignment, user: message.owner, bubbleType: bubbleType, status: message.status, messageType: message.type)
                    case let .image(source, isLocallyStored: _):
                        let cell = self.createImageCell(messageId: message.id, indexPath: indexPath, alignment: cell.cell.alignment, user: message.owner, source: source, bubbleType: bubbleType, status: message.status, messageType: message.type)
                        return cell
                    }
                case let .messageGroup(group):
                    let cell = self.createGroupTitle(indexPath: indexPath, alignment: cell.cell.alignment, title: group.title)
                    return cell
                case let .date(group):
                    let cell = self.createDateTitle(indexPath: indexPath, alignment: cell.cell.alignment, title: group.value)
                    return cell
                case .typingIndicator:
                    return self.createTypingIndicatorCell(indexPath: indexPath)
                default:
                    fatalError()
                }
            })
            self.dataSource = diffableDataSource
        }
    }

    private unowned var reloadDelegate: ReloadDelegate

    private unowned var editingDelegate: EditingAccessoryControllerDelegate

    let editNotifier = EditNotifier()

    var sections: [Section] = [] {
        didSet {
            var snapshot = Snapshot()
            let diffableSections = sections.map({ DiffableSection(section: $0) })
            snapshot.appendSections(diffableSections)
            diffableSections.forEach { section in
                snapshot.appendItems(section.section.cells.map({ DiffableCell(cell: $0) }), toSection: section)
            }
            dataSource.apply(snapshot, animatingDifferences: true, completion: {
                print("Hell")
            })
        }
    }

    private var dataSource: DataSource!

    fileprivate var chatLayout: ChatLayout {
        guard let chatLayout = collectionView.collectionViewLayout as? ChatLayout else {
            fatalError("Only ChatLayout is supported")
        }
        return chatLayout
    }

    init(reloadDelegate: ReloadDelegate, editingDelegate: EditingAccessoryControllerDelegate) {
        self.reloadDelegate = reloadDelegate
        self.editingDelegate = editingDelegate
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    }

    func registerCells() {
        collectionView.register(TextMessageCollectionCell.self, forCellWithReuseIdentifier: TextMessageCollectionCell.reuseIdentifier)
        collectionView.register(ImageCollectionCell.self, forCellWithReuseIdentifier: ImageCollectionCell.reuseIdentifier)
        collectionView.register(TitleCollectionCell.self, forCellWithReuseIdentifier: TitleCollectionCell.reuseIdentifier)
        collectionView.register(TypingIndicatorCollectionCell.self, forCellWithReuseIdentifier: TypingIndicatorCollectionCell.reuseIdentifier)
        collectionView.register(TextTitleView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TextTitleView.reuseIdentifier)
        collectionView.register(TextTitleView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: TextTitleView.reuseIdentifier)
        if #available(iOS 13.0, *) {
            collectionView.register(URLCollectionCell.self, forCellWithReuseIdentifier: URLCollectionCell.reuseIdentifier)
        }
    }

    private func createTextCell(messageId: UUID, indexPath: IndexPath, text: String, alignment: ChatItemAlignment, user: User, bubbleType: Cell.BubbleType, status: MessageStatus, messageType: MessageType) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextMessageCollectionCell.reuseIdentifier, for: indexPath) as! TextMessageCollectionCell
        setupMessageContainerView(cell.customView, messageId: messageId, alignment: alignment)
        setupCellLayoutView(cell.customView.customView, user: user, alignment: alignment, bubble: bubbleType, status: status)

        let bubbleView = cell.customView.customView.customView
        let controller = TextMessageController(text: text,
            type: messageType,
            bubbleController: buildTextBubbleController(bubbleView: bubbleView, messageType: messageType, bubbleType: bubbleType))
        bubbleView.customView.setup(with: controller)
        controller.view = bubbleView.customView
        cell.delegate = bubbleView.customView

        return cell
    }

    @available(iOS 13, *)
    private func createURLCell(messageId: UUID, indexPath: IndexPath, url: URL, alignment: ChatItemAlignment, user: User, bubbleType: Cell.BubbleType, status: MessageStatus, messageType: MessageType) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: URLCollectionCell.reuseIdentifier, for: indexPath) as! URLCollectionCell
        setupMessageContainerView(cell.customView, messageId: messageId, alignment: alignment)
        setupCellLayoutView(cell.customView.customView, user: user, alignment: alignment, bubble: bubbleType, status: status)

        let bubbleView = cell.customView.customView.customView
        let controller = URLController(url: url,
            messageId: messageId,
            bubbleController: buildDefaultBubbleController(for: bubbleView, messageType: messageType, bubbleType: bubbleType))

        bubbleView.customView.setup(with: controller)
        controller.view = bubbleView.customView
        controller.delegate = reloadDelegate
        cell.delegate = bubbleView.customView

        return cell
    }

    private func createImageCell(messageId: UUID, indexPath: IndexPath, alignment: ChatItemAlignment, user: User, source: ImageMessageSource, bubbleType: Cell.BubbleType, status: MessageStatus, messageType: MessageType) -> ImageCollectionCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCollectionCell.reuseIdentifier, for: indexPath) as! ImageCollectionCell

        setupMessageContainerView(cell.customView, messageId: messageId, alignment: alignment)
        setupCellLayoutView(cell.customView.customView, user: user, alignment: alignment, bubble: bubbleType, status: status)

        let bubbleView = cell.customView.customView.customView
        let controller = ImageController(source: source,
            messageId: messageId,
            bubbleController: buildDefaultBubbleController(for: bubbleView, messageType: messageType, bubbleType: bubbleType))

        controller.delegate = reloadDelegate
        bubbleView.customView.setup(with: controller)
        controller.view = bubbleView.customView
        cell.delegate = bubbleView.customView

        return cell
    }

    private func createTypingIndicatorCell(indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TypingIndicatorCollectionCell.reuseIdentifier, for: indexPath) as! TypingIndicatorCollectionCell
        let alignment = ChatItemAlignment.leading
        cell.customView.alignment = alignment
        cell.customView.customView.alignment = .bottom
        let bubbleView = cell.customView.customView.customView
        let controller = TextMessageController(text: "Typing...",
            type: .incoming,
            bubbleController: buildTextBubbleController(bubbleView: bubbleView, messageType: .incoming, bubbleType: .tailed))
        bubbleView.customView.setup(with: controller)
        controller.view = bubbleView.customView

        return cell
    }

    private func createGroupTitle(indexPath: IndexPath, alignment: ChatItemAlignment, title: String) -> TitleCollectionCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCollectionCell.reuseIdentifier, for: indexPath) as! TitleCollectionCell
        cell.customView.text = title
        cell.customView.preferredMaxLayoutWidth = chatLayout.layoutFrame.width
        cell.customView.textColor = .gray
        cell.customView.numberOfLines = 0
        cell.customView.font = .preferredFont(forTextStyle: .caption2)
        cell.contentView.layoutMargins = UIEdgeInsets(top: 2, left: 16, bottom: 2, right: 16)
        return cell
    }

    private func createDateTitle(indexPath: IndexPath, alignment: ChatItemAlignment, title: String) -> TitleCollectionCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCollectionCell.reuseIdentifier, for: indexPath) as! TitleCollectionCell
        cell.customView.preferredMaxLayoutWidth = chatLayout.layoutFrame.width
        cell.customView.text = title
        cell.customView.textColor = .gray
        cell.customView.numberOfLines = 0
        cell.customView.font = .preferredFont(forTextStyle: .caption2)
        cell.contentView.layoutMargins = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        return cell
    }

    private func setupMessageContainerView<CustomView>(_ messageContainerView: MessageContainerView<EditingAccessoryView, CustomView>, messageId: UUID, alignment: ChatItemAlignment) {
        messageContainerView.alignment = alignment
        if let accessoryView = messageContainerView.accessoryView {
            editNotifier.add(delegate: accessoryView)
            accessoryView.setIsEditing(editNotifier.isEditing)

            let controller = EditingAccessoryController(messageId: messageId)
            controller.view = accessoryView
            controller.delegate = editingDelegate
            accessoryView.setup(with: controller)
        }
    }

    private func setupCellLayoutView<CustomView>(_ cellView: CellLayoutContainerView<AvatarView, CustomView, StatusView>,
                                                 user: User,
                                                 alignment: ChatItemAlignment,
                                                 bubble: Cell.BubbleType,
                                                 status: MessageStatus) {
        cellView.alignment = .bottom
        cellView.leadingView?.isHidden = !alignment.isIncoming
        cellView.trailingView?.isHidden = alignment.isIncoming
        cellView.trailingView?.setup(with: status)

        if let avatarView = cellView.leadingView {
            let avatarViewController = AvatarViewController(user: user, bubble: bubble)
            avatarView.setup(with: avatarViewController)
            avatarViewController.view = avatarView
        }
    }

    private func buildTextBubbleController<CustomView>(bubbleView: ImageMaskedView<CustomView>, messageType: MessageType, bubbleType: Cell.BubbleType) -> BubbleController {
        let textBubbleController = TextBubbleController(bubbleView: bubbleView, type: messageType, bubbleType: bubbleType)
        let bubbleController = DefaultBubbleController(bubbleView: bubbleView, controllerProxy: textBubbleController, type: messageType, bubbleType: bubbleType)
        return bubbleController
    }

    private func buildDefaultBubbleController<CustomView>(for bubbleView: ImageMaskedView<CustomView>, messageType: MessageType, bubbleType: Cell.BubbleType) -> BubbleController {
        let contentBubbleController = FullCellContentBubbleController(bubbleView: bubbleView)
        let bubbleController = DefaultBubbleController(bubbleView: bubbleView, controllerProxy: contentBubbleController, type: messageType, bubbleType: bubbleType)
        return bubbleController
    }

}

@available(iOS 13.0, *)
extension DiffableChatCollectionDataSource: UICollectionViewDataSource {

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataSource.numberOfSections(in: collectionView)
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.collectionView(collectionView, numberOfItemsInSection: section)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return  dataSource.collectionView(collectionView, cellForItemAt: indexPath)
    }

    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                withReuseIdentifier: TextTitleView.reuseIdentifier,
                for: indexPath) as! TextTitleView
            view.customView.text = sections[indexPath.section].title
            view.customView.preferredMaxLayoutWidth = 300
            view.customView.textColor = .lightGray
            view.customView.numberOfLines = 0
            view.customView.font = .preferredFont(forTextStyle: .caption2)
            return view
        case UICollectionView.elementKindSectionFooter:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                withReuseIdentifier: TextTitleView.reuseIdentifier,
                for: indexPath) as! TextTitleView
            view.customView.text = "Made with ChatLayout"
            view.customView.preferredMaxLayoutWidth = 300
            view.customView.textColor = .lightGray
            view.customView.numberOfLines = 0
            view.customView.font = .preferredFont(forTextStyle: .caption2)
            return view
        default:
            fatalError()
        }
    }

}

@available(iOS 13.0, *)
extension DiffableChatCollectionDataSource: ChatLayoutDelegate {

    public func shouldPresentHeader(at sectionIndex: Int) -> Bool {
        return false
    }

    public func shouldPresentFooter(at sectionIndex: Int) -> Bool {
        return false
    }

    public func sizeForItem(of kind: ItemKind, at indexPath: IndexPath) -> ItemSize {
        switch kind {
        case .cell:
            let item = sections[indexPath.section].cells[indexPath.item]
            switch item {
            case let .message(message, bubbleType: _):
                switch message.data {
                case .text:
                    return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 36))
                case let .image(_, isLocallyStored: isDownloaded):
                    return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: isDownloaded ? 200 : 80))
                case let .url(_, isLocallyStored: isDownloaded):
                    return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: isDownloaded ? 200 : 80))
                }
            case .date:
                return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 18))
            case .typingIndicator:
                return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 36))
            case .messageGroup:
                return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 18))
            case .deliveryStatus:
                return .estimated(CGSize(width: chatLayout.layoutFrame.width, height: 18))
            }
        case .footer, .header:
            return .auto
        }
    }

    public func alignmentForItem(of kind: ItemKind, at indexPath: IndexPath) -> ChatItemAlignment {
        switch kind {
        case .header:
            return .center
        case .cell:
            let item = sections[indexPath.section].cells[indexPath.item]
            switch item {
            case .date:
                return .center
            case .message, .deliveryStatus, .messageGroup, .typingIndicator:
                return .full
            }
        case .footer:
            return .trailing
        }
    }

}
