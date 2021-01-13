import PromiseKit

// TODO: Clean

@objc(LKPublicChatManager)
public final class PublicChatManager : NSObject {
    private let storage = OWSPrimaryStorage.shared()
    @objc public var chats: [String:OpenGroup] = [:]
    private var pollers: [String:OpenGroupPoller] = [:]
    private var isPolling = false
    
    private var userHexEncodedPublicKey: String? {
        return OWSIdentityManager.shared().identityKeyPair()?.hexEncodedPublicKey
    }
    
    public enum Error : Swift.Error {
        case chatCreationFailed
        case userPublicKeyNotFound
    }
    
    @objc public static let shared = PublicChatManager()
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onThreadDeleted(_:)), name: .threadDeleted, object: nil)
        refreshChatsAndPollers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func startPollersIfNeeded() {
        for (threadID, publicChat) in chats {
            if let poller = pollers[threadID] {
                poller.startIfNeeded()
            } else {
                let poller = OpenGroupPoller(for: publicChat)
                poller.startIfNeeded()
                pollers[threadID] = poller
            }
        }
        isPolling = true
    }
    
    @objc public func stopPollers() {
        for poller in pollers.values { poller.stop() }
        isPolling = false
    }
    
    public func addChat(server: String, channel: UInt64, using transaction: YapDatabaseReadWriteTransaction) -> Promise<OpenGroup> {
        if let existingChat = getChat(server: server, channel: channel) {
            if let newChat = self.addChat(server: server, channel: channel, name: existingChat.displayName, using: transaction) {
                return Promise.value(newChat)
            } else {
                return Promise(error: Error.chatCreationFailed)
            }
        }
        return OpenGroupAPI.getInfo(for: channel, on: server).map2 { channelInfo -> OpenGroup in
            guard let chat = self.addChat(server: server, channel: channel, name: channelInfo.displayName, using: transaction) else { throw Error.chatCreationFailed }
            return chat
        }
    }
    
    @discardableResult
    @objc(addChatWithServer:channel:name:using:)
    public func addChat(server: String, channel: UInt64, name: String, using transaction: YapDatabaseReadWriteTransaction) -> OpenGroup? {
        guard let chat = OpenGroup(channel: channel, server: server, displayName: name, isDeletable: true) else { return nil }
        let model = TSGroupModel(title: chat.displayName, memberIds: [userHexEncodedPublicKey!, chat.server], image: nil, groupId: LKGroupUtilities.getEncodedOpenGroupIDAsData(chat.id), groupType: .openGroup, adminIds: [])
        
        // Store the group chat mapping
        let thread = TSGroupThread.getOrCreateThread(with: model, transaction: transaction)

        // Save the group chat
        Storage.shared.setOpenGroup(chat, for: thread.uniqueId!, using: transaction)

        // Update chats and pollers
        transaction.addCompletionQueue(DispatchQueue.main) {
            self.refreshChatsAndPollers()
        }
        
        return chat
    }
    
    @objc(addChatWithServer:channel:using:)
    public func objc_addChat(server: String, channel: UInt64, using transaction: YapDatabaseReadWriteTransaction) -> AnyPromise {
        return AnyPromise.from(addChat(server: server, channel: channel, using: transaction))
    }
    
    @objc func refreshChatsAndPollers() {
        let newChats = Storage.shared.getAllUserOpenGroups()
        
        // Remove any chats that don't exist in the database
        let removedChatThreadIds = self.chats.keys.filter { !newChats.keys.contains($0) }
        removedChatThreadIds.forEach { threadID in
            let poller = self.pollers.removeValue(forKey: threadID)
            poller?.stop()
        }
        
        // Only append to chats if we have a thread for the chat
        self.chats = newChats.filter { (threadID, group) in
            return TSGroupThread.fetch(uniqueId: threadID) != nil
        }
        
        if (isPolling) { startPollersIfNeeded() }
    }
    
    @objc private func onThreadDeleted(_ notification: Notification) {
        guard let threadId = notification.userInfo?["threadId"] as? String else { return }
        
        // Reset the last message cache
        if let chat = self.chats[threadId] {
            Storage.write { transaction in
                Storage.shared.clearAllData(for: chat.channel, on: chat.server, using: transaction)
            }
        }
        
        // Remove the chat from the db
        Storage.write { transaction in
            Storage.shared.removeOpenGroup(for: threadId, using: transaction)
        }

        refreshChatsAndPollers()
    }
    
    public func getChat(server: String, channel: UInt64) -> OpenGroup? {
        return chats.values.first { chat in
            return chat.server == server && chat.channel == channel
        }
    }
}
