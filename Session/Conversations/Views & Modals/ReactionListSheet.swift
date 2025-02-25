// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import DifferenceKit
import SessionUIKit
import SessionMessagingKit
import SignalUtilitiesKit

final class ReactionListSheet: BaseVC {
    public struct ReactionSummary: Hashable, Differentiable {
        let emoji: EmojiWithSkinTones
        let number: Int
        let isSelected: Bool
        
        var description: String {
            return "\(emoji.rawValue) · \(number)"
        }
    }
    
    private let interactionId: Int64
    private let onDismiss: (() -> ())?
    private var messageViewModel: MessageViewModel = MessageViewModel()
    private var reactionSummaries: [ReactionSummary] = []
    private var selectedReactionUserList: [MessageViewModel.ReactionInfo] = []
    private var lastSelectedReactionIndex: Int = 0
    public var delegate: ReactionDelegate?
    
    // MARK: - UI
    
    private lazy var contentView: UIView = {
        let result: UIView = UIView()
        result.backgroundColor = Colors.modalBackground
        
        let line: UIView = UIView()
        line.backgroundColor = Colors.border.withAlphaComponent(0.5)
        result.addSubview(line)
        
        line.set(.height, to: 0.5)
        line.pin([ UIView.HorizontalEdge.leading, UIView.HorizontalEdge.trailing, UIView.VerticalEdge.top ], to: result)
        
        return result
    }()
    
    private lazy var layout: UICollectionViewFlowLayout = {
        let result: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        result.scrollDirection = .horizontal
        result.sectionInset = UIEdgeInsets(
            top: 0,
            leading: Values.smallSpacing,
            bottom: 0,
            trailing: Values.smallSpacing
        )
        result.minimumLineSpacing = Values.smallSpacing
        result.minimumInteritemSpacing = Values.smallSpacing
        result.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        return result
    }()
    
    private lazy var reactionContainer: UICollectionView = {
        let result: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        result.register(view: Cell.self)
        result.set(.height, to: 48)
        result.backgroundColor = .clear
        result.isScrollEnabled = true
        result.showsHorizontalScrollIndicator = false
        result.dataSource = self
        result.delegate = self
        
        return result
    }()
    
    private lazy var detailInfoLabel: UILabel = {
        let result: UILabel = UILabel()
        result.font = .systemFont(ofSize: Values.mediumFontSize)
        result.textColor = Colors.grey.withAlphaComponent(0.8)
        result.set(.height, to: 32)
        
        return result
    }()
    
    private lazy var clearAllButton: Button = {
        let result: Button = Button(style: .destructiveOutline, size: .small)
        result.translatesAutoresizingMaskIntoConstraints = false
        result.setTitle("MESSAGE_REQUESTS_CLEAR_ALL".localized(), for: .normal)
        result.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        result.layer.borderWidth = 0
        result.isHidden = true
        
        return result
    }()
    
    private lazy var userListView: UITableView = {
        let result: UITableView = UITableView()
        result.dataSource = self
        result.delegate = self
        result.register(view: UserCell.self)
        result.separatorStyle = .none
        result.backgroundColor = .clear
        result.showsVerticalScrollIndicator = false
        
        return result
    }()
    
    // MARK: - Lifecycle
    
    init(for interactionId: Int64, onDismiss: (() -> ())? = nil) {
        self.interactionId = interactionId
        self.onDismiss = onDismiss
        
        super.init(nibName: nil, bundle: nil)
    }
    
    override init(nibName: String?, bundle: Bundle?) {
        preconditionFailure("Use init(for:) instead.")
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("Use init(for:) instead.")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        let swipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(close))
        swipeGestureRecognizer.direction = .down
        view.addGestureRecognizer(swipeGestureRecognizer)
        
        setUpViewHierarchy()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.onDismiss?()
    }

    private func setUpViewHierarchy() {
        view.addSubview(contentView)
        contentView.pin([ UIView.HorizontalEdge.leading, UIView.HorizontalEdge.trailing, UIView.VerticalEdge.bottom ], to: view)
        contentView.set(.height, to: 440)
        populateContentView()
    }
    
    private func populateContentView() {
        // Reactions container
        contentView.addSubview(reactionContainer)
        reactionContainer.pin([ UIView.HorizontalEdge.leading, UIView.HorizontalEdge.trailing ], to: contentView)
        reactionContainer.pin(.top, to: .top, of: contentView, withInset: Values.verySmallSpacing)
        
        // Seperator
        let seperator = UIView()
        seperator.backgroundColor = Colors.border.withAlphaComponent(0.1)
        seperator.set(.height, to: 0.5)
        contentView.addSubview(seperator)
        seperator.pin(.leading, to: .leading, of: contentView, withInset: Values.smallSpacing)
        seperator.pin(.trailing, to: .trailing, of: contentView, withInset: -Values.smallSpacing)
        seperator.pin(.top, to: .bottom, of: reactionContainer, withInset: Values.verySmallSpacing)
        
        // Detail info & clear all
        let stackView = UIStackView(arrangedSubviews: [ detailInfoLabel, clearAllButton ])
        contentView.addSubview(stackView)
        stackView.pin(.top, to: .bottom, of: seperator, withInset: Values.smallSpacing)
        stackView.pin(.leading, to: .leading, of: contentView, withInset: Values.mediumSpacing)
        stackView.pin(.trailing, to: .trailing, of: contentView, withInset: -Values.mediumSpacing)
        
        // Line
        let line = UIView()
        line.set(.height, to: 0.5)
        line.backgroundColor = Colors.border.withAlphaComponent(0.5)
        contentView.addSubview(line)
        line.pin([ UIView.HorizontalEdge.leading, UIView.HorizontalEdge.trailing ], to: contentView)
        line.pin(.top, to: .bottom, of: stackView, withInset: Values.smallSpacing)
        
        // Reactor list
        contentView.addSubview(userListView)
        userListView.pin([ UIView.HorizontalEdge.trailing, UIView.HorizontalEdge.leading, UIView.VerticalEdge.bottom ], to: contentView)
        userListView.pin(.top, to: .bottom, of: line, withInset: 0)
    }
    
    // MARK: - Content
    
    public func handleInteractionUpdates(
        _ allMessages: [MessageViewModel],
        selectedReaction: EmojiWithSkinTones? = nil,
        updatedReactionIndex: Int? = nil,
        initialLoad: Bool = false,
        shouldShowClearAllButton: Bool = false
    ) {
        guard let cellViewModel: MessageViewModel = allMessages.first(where: { $0.id == self.interactionId }) else {
            return
        }
        
        // If we have no more reactions (eg. the user removed the last one) then closed the list sheet
        guard cellViewModel.reactionInfo?.isEmpty == false else {
            close()
            return
        }
        
        // Generated the updated data
        let updatedReactionInfo: OrderedDictionary<EmojiWithSkinTones, [MessageViewModel.ReactionInfo]> = (cellViewModel.reactionInfo ?? [])
            .reduce(into: OrderedDictionary<EmojiWithSkinTones, [MessageViewModel.ReactionInfo]>()) {
                result, reactionInfo in
                guard let emoji: EmojiWithSkinTones = EmojiWithSkinTones(rawValue: reactionInfo.reaction.emoji) else {
                    return
                }
                
                guard var updatedValue: [MessageViewModel.ReactionInfo] = result.value(forKey: emoji) else {
                    result.append(key: emoji, value: [reactionInfo])
                    return
                }
                
                if reactionInfo.reaction.authorId == cellViewModel.currentUserPublicKey {
                    updatedValue.insert(reactionInfo, at: 0)
                }
                else {
                    updatedValue.append(reactionInfo)
                }
                
                result.replace(key: emoji, value: updatedValue)
            }
        let oldSelectedReactionIndex: Int = self.lastSelectedReactionIndex
        let updatedSelectedReactionIndex: Int = updatedReactionIndex
            .defaulting(
                to: {
                    // If we explicitly provided a 'selectedReaction' value then try to use that
                    if selectedReaction != nil, let targetIndex: Int = updatedReactionInfo.orderedKeys.firstIndex(where: { $0 == selectedReaction }) {
                        return targetIndex
                    }

                    // Otherwise try to maintain the index of the currently selected index
                    guard
                        !self.reactionSummaries.isEmpty,
                        let emoji: EmojiWithSkinTones = self.reactionSummaries[safe: oldSelectedReactionIndex]?.emoji,
                        let targetIndex: Int = updatedReactionInfo.orderedKeys.firstIndex(of: emoji)
                    else { return 0 }

                    return targetIndex
                }()
            )
        let updatedSummaries: [ReactionSummary] = updatedReactionInfo
            .orderedKeys
            .enumerated()
            .map { index, emoji in
                ReactionSummary(
                    emoji: emoji,
                    number: updatedReactionInfo.value(forKey: emoji)
                        .defaulting(to: [])
                        .map { Int($0.reaction.count) }
                        .reduce(0, +),
                    isSelected: (index == updatedSelectedReactionIndex)
                )
            }
        
        // Update the general UI
        self.detailInfoLabel.text = updatedSummaries[safe: updatedSelectedReactionIndex]?.description

        // Update general properties
        self.messageViewModel = cellViewModel
        self.lastSelectedReactionIndex = updatedSelectedReactionIndex
        
        // Ensure the first load or a load when returning from a child screen runs without animations (if
        // we don't do this the cells will animate in from a frame of CGRect.zero or have a buggy transition)
        guard !initialLoad else {
            self.reactionSummaries = updatedSummaries
            self.selectedReactionUserList = updatedReactionInfo
                .orderedKeys[safe: updatedSelectedReactionIndex]
                .map { updatedReactionInfo.value(forKey: $0) }
                .defaulting(to: [])
            
            // Update clear all button visibility
            self.clearAllButton.isHidden = !shouldShowClearAllButton
            
            UIView.performWithoutAnimation {
                self.reactionContainer.reloadData()
                self.userListView.reloadData()
            }
            return
        }
        
        // Update the collection view content
        let collectionViewChangeset: StagedChangeset<[ReactionSummary]> = StagedChangeset(
            source: self.reactionSummaries,
            target: updatedSummaries
        )
        
        // If there are changes then we want to reload both the collection and table views
        self.reactionContainer.reload(
            using: collectionViewChangeset,
            interrupt: { $0.changeCount > 1 }
        ) { [weak self] updatedData in
            self?.reactionSummaries = updatedData
        }
        
        // If we changed the selected index then no need to reload the changes
        guard
            oldSelectedReactionIndex == updatedSelectedReactionIndex &&
            self.reactionSummaries[safe: oldSelectedReactionIndex]?.emoji == updatedSummaries[safe: updatedSelectedReactionIndex]?.emoji
        else {
            self.selectedReactionUserList = updatedReactionInfo
                .orderedKeys[safe: updatedSelectedReactionIndex]
                .map { updatedReactionInfo.value(forKey: $0) }
                .defaulting(to: [])
            self.userListView.reloadData()
            return
        }
        
        let tableChangeset: StagedChangeset<[MessageViewModel.ReactionInfo]> = StagedChangeset(
            source: self.selectedReactionUserList,
            target: updatedReactionInfo
                .orderedKeys[safe: updatedSelectedReactionIndex]
                .map { updatedReactionInfo.value(forKey: $0) }
                .defaulting(to: [])
        )
        
        self.userListView.reload(
            using: tableChangeset,
            deleteSectionsAnimation: .none,
            insertSectionsAnimation: .none,
            reloadSectionsAnimation: .none,
            deleteRowsAnimation: .none,
            insertRowsAnimation: .none,
            reloadRowsAnimation: .none,
            interrupt: {  $0.changeCount > 100 }
        ) { [weak self] updatedData in
            self?.selectedReactionUserList = updatedData
        }
    }
    
    // MARK: - Interaction
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch: UITouch = touches.first, contentView.frame.contains(touch.location(in: view)) else {
            close()
            return
        }
        
        super.touchesBegan(touches, with: event)
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func clearAllTapped() {
        guard let selectedReaction: EmojiWithSkinTones = self.reactionSummaries.first(where: { $0.isSelected })?.emoji else { return }
        
        delegate?.removeAllReactions(messageViewModel, for: selectedReaction.rawValue)
    }
}

// MARK: - UICollectionView

extension ReactionListSheet: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // MARK: Data Source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.reactionSummaries.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: Cell = collectionView.dequeue(type: Cell.self, for: indexPath)
        let summary: ReactionSummary = self.reactionSummaries[indexPath.item]
        
        cell.update(
            with: summary.emoji.rawValue,
            count: summary.number,
            isCurrentSelection: summary.isSelected
        )
        
        return cell
    }
    
    // MARK: Interaction
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.handleInteractionUpdates([messageViewModel], updatedReactionIndex: indexPath.item)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension ReactionListSheet: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.selectedReactionUserList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UserCell = tableView.dequeue(type: UserCell.self, for: indexPath)
        let cellViewModel: MessageViewModel.ReactionInfo = self.selectedReactionUserList[indexPath.row]
        cell.update(
            with: cellViewModel.reaction.authorId,
            profile: cellViewModel.profile,
            isZombie: false,
            mediumFont: true,
            accessory: (cellViewModel.reaction.authorId == self.messageViewModel.currentUserPublicKey ?
                .x :
                .none
            )
        )
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let cellViewModel: MessageViewModel.ReactionInfo = self.selectedReactionUserList[indexPath.row]
        
        guard
            let selectedReaction: EmojiWithSkinTones = self.reactionSummaries
                .first(where: { $0.isSelected })?
                .emoji,
            selectedReaction.rawValue == cellViewModel.reaction.emoji,
            cellViewModel.reaction.authorId == self.messageViewModel.currentUserPublicKey
        else { return }
        
        delegate?.removeReact(self.messageViewModel, for: selectedReaction)
    }
}

// MARK: - Cell

extension ReactionListSheet {
    fileprivate final class Cell: UICollectionViewCell {
        // MARK: - UI
        
        private static var contentViewHeight: CGFloat = 32
        private static var contentViewCornerRadius: CGFloat { contentViewHeight / 2 }
        
        private lazy var snContentView: UIView = {
            let result = UIView()
            result.backgroundColor = Colors.receivedMessageBackground
            result.set(.height, to: Cell.contentViewHeight)
            result.layer.cornerRadius = Cell.contentViewCornerRadius
            return result
        }()
        
        private lazy var emojiLabel: UILabel = {
            let result = UILabel()
            result.font = .systemFont(ofSize: Values.mediumFontSize)
            return result
        }()
        
        private lazy var numberLabel: UILabel = {
            let result = UILabel()
            result.textColor = Colors.text
            result.font = .systemFont(ofSize: Values.mediumFontSize)
            
            return result
        }()
        
        // MARK: - Initialization
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            setUpViewHierarchy()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            
            setUpViewHierarchy()
        }
        
        private func setUpViewHierarchy() {
            addSubview(snContentView)
            
            let stackView = UIStackView(arrangedSubviews: [ emojiLabel, numberLabel ])
            stackView.axis = .horizontal
            stackView.alignment = .center
            
            let spacing = Values.smallSpacing + 2
            stackView.spacing = spacing
            stackView.layoutMargins = UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
            stackView.isLayoutMarginsRelativeArrangement = true
            snContentView.addSubview(stackView)
            stackView.pin(to: snContentView)
            snContentView.pin(to: self)
        }
        
        // MARK: - Content
        
        fileprivate func update(
            with emoji: String,
            count: Int,
            isCurrentSelection: Bool
        ) {
            snContentView.addBorder(
                with: (isCurrentSelection == true ? Colors.accent : .clear)
            )
            
            emojiLabel.text = emoji
            numberLabel.text = (count < 1000 ?
                "\(count)" :
                String(format: "%.1fk", Float(count) / 1000)
            )
        }
    }
}

// MARK: - Delegate

protocol ReactionDelegate: AnyObject {
    func react(_ cellViewModel: MessageViewModel, with emoji: EmojiWithSkinTones)
    func removeReact(_ cellViewModel: MessageViewModel, for emoji: EmojiWithSkinTones)
    func removeAllReactions(_ cellViewModel: MessageViewModel, for emoji: String)
}
