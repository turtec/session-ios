// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import SessionUIKit

class MessageRequestsCell: UITableViewCell {
    static let reuseIdentifier = "MessageRequestsCell"
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setUpViewHierarchy()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setUpViewHierarchy()
        setupLayout()
    }
    
    // MARK: - UI
    
    private let iconContainerView: UIView = {
        let result: UIView = UIView()
        result.translatesAutoresizingMaskIntoConstraints = false
        result.clipsToBounds = true
        result.backgroundColor = Colors.sessionMessageRequestsBubble
        result.layer.cornerRadius = (Values.mediumProfilePictureSize / 2)
        
        return result
    }()
    
    private let iconImageView: UIImageView = {
        let result: UIImageView = UIImageView(image: #imageLiteral(resourceName: "message_requests").withRenderingMode(.alwaysTemplate))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.tintColor = Colors.sessionMessageRequestsIcon
        
        return result
    }()
    
    private let titleLabel: UILabel = {
        let result: UILabel = UILabel()
        result.translatesAutoresizingMaskIntoConstraints = false
        result.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        result.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        result.font = .boldSystemFont(ofSize: Values.mediumFontSize)
        result.text = NSLocalizedString("MESSAGE_REQUESTS_TITLE", comment: "")
        result.textColor = Colors.sessionMessageRequestsTitle
        result.lineBreakMode = .byTruncatingTail
        
        return result
    }()
    
    private let unreadCountView: UIView = {
        let result: UIView = UIView()
        result.translatesAutoresizingMaskIntoConstraints = false
        result.clipsToBounds = true
        result.backgroundColor = Colors.text.withAlphaComponent(Values.veryLowOpacity)
        result.layer.cornerRadius = (FullConversationCell.unreadCountViewSize / 2)
        
        return result
    }()
    
    private let unreadCountLabel: UILabel = {
        let result = UILabel()
        result.translatesAutoresizingMaskIntoConstraints = false
        result.font = .boldSystemFont(ofSize: Values.verySmallFontSize)
        result.textColor = Colors.text
        result.textAlignment = .center
        
        return result
    }()
    
    private func setUpViewHierarchy() {
        backgroundColor = Colors.cellPinned
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = Colors.cellSelected
        
        
        contentView.addSubview(iconContainerView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(unreadCountView)
        
        iconContainerView.addSubview(iconImageView)
        unreadCountView.addSubview(unreadCountLabel)
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: 68),
            
            iconContainerView.leftAnchor.constraint(
                equalTo: contentView.leftAnchor,
                // Need 'accentLineThickness' to line up correctly with the 'ConversationCell'
                constant: (Values.accentLineThickness + Values.mediumSpacing)
            ),
            iconContainerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: Values.mediumProfilePictureSize),
            iconContainerView.heightAnchor.constraint(equalToConstant: Values.mediumProfilePictureSize),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 25),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),
            
            titleLabel.leftAnchor.constraint(equalTo: iconContainerView.rightAnchor, constant: Values.mediumSpacing),
            titleLabel.rightAnchor.constraint(lessThanOrEqualTo: contentView.rightAnchor, constant: -Values.mediumSpacing),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            unreadCountView.leftAnchor.constraint(equalTo: titleLabel.rightAnchor, constant: (Values.smallSpacing / 2)),
            unreadCountView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            unreadCountView.widthAnchor.constraint(equalToConstant: FullConversationCell.unreadCountViewSize),
            unreadCountView.heightAnchor.constraint(equalToConstant: FullConversationCell.unreadCountViewSize),
            
            unreadCountLabel.topAnchor.constraint(equalTo: unreadCountView.topAnchor),
            unreadCountLabel.leftAnchor.constraint(equalTo: unreadCountView.leftAnchor),
            unreadCountLabel.rightAnchor.constraint(equalTo: unreadCountView.rightAnchor),
            unreadCountLabel.bottomAnchor.constraint(equalTo: unreadCountView.bottomAnchor)
        ])
    }
    
    // MARK: - Content
    
    func update(with count: Int) {
        unreadCountLabel.text = "\(count)"
        unreadCountView.isHidden = (count <= 0)
    }
}
