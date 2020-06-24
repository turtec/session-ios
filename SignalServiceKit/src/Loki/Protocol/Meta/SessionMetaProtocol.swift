import PromiseKit

// A few notes about making changes in this file:
//
// • Don't use a database transaction if you can avoid it.
// • If you do need to use a database transaction, use a read transaction if possible.
// • For write transactions, consider making it the caller's responsibility to manage the database transaction (this helps avoid unnecessary transactions).
// • Think carefully about adding a function; there might already be one for what you need.
// • Document the expected cases in which a function will be used
// • Express those cases in tests.

/// See [Receipts, Transcripts & Typing Indicators](https://github.com/loki-project/session-protocol-docs/wiki/Receipts,-Transcripts-&-Typing-Indicators) for more information.
@objc(LKSessionMetaProtocol)
public final class SessionMetaProtocol : NSObject {

    internal static var storage: OWSPrimaryStorage { OWSPrimaryStorage.shared() }

    // MARK: - Sending

    // MARK: Message Destination(s)
    @objc(getDestinationsForOutgoingSyncMessage)
    public static func objc_getDestinationsForOutgoingSyncMessage() -> NSMutableSet {
        return NSMutableSet(set: MultiDeviceProtocol.getUserLinkedDevices())
    }

    @objc(getDestinationsForOutgoingGroupMessage:inThread:)
    public static func objc_getDestinations(for outgoingGroupMessage: TSOutgoingMessage, in thread: TSThread) -> NSMutableSet {
        guard let thread = thread as? TSGroupThread else { preconditionFailure("Can't get destinations for group message in non-group thread.") }
        var result: Set<String> = []
        if thread.isPublicChat {
            storage.dbReadConnection.read { transaction in
                if let openGroup = LokiDatabaseUtilities.getPublicChat(for: thread.uniqueId!, in: transaction) {
                    result = [ openGroup.server ] // Aim the message at the open group server
                } else {
                    // Should never occur
                }
            }
        } else {
            result = Set(outgoingGroupMessage.sendingRecipientIds())
                .intersection(thread.groupModel.groupMemberIds)
                .subtracting(MultiDeviceProtocol.getUserLinkedDevices())
        }
        return NSMutableSet(set: result)
    }

    // MARK: Note to Self
    @objc(isThreadNoteToSelf:)
    public static func isThreadNoteToSelf(_ thread: TSThread) -> Bool {
        guard let thread = thread as? TSContactThread else { return false }
        var isNoteToSelf = false
        storage.dbReadConnection.read { transaction in
            isNoteToSelf = LokiDatabaseUtilities.isUserLinkedDevice(thread.contactIdentifier(), transaction: transaction)
        }
        return isNoteToSelf
    }

    // MARK: Transcripts
    @objc(shouldSendTranscriptForMessage:inThread:)
    public static func shouldSendTranscript(for message: TSOutgoingMessage, in thread: TSThread) -> Bool {
        guard message.shouldSyncTranscript() else { return false }
        let isOpenGroupMessage = (thread as? TSGroupThread)?.isPublicChat == true
        let wouldSignalRequireTranscript = (AreRecipientUpdatesEnabled() || !message.hasSyncedTranscript)
        guard wouldSignalRequireTranscript && !isOpenGroupMessage else { return false }
        var usesMultiDevice = false
        storage.dbReadConnection.read { transaction in
            usesMultiDevice = !storage.getDeviceLinks(for: getUserHexEncodedPublicKey(), in: transaction).isEmpty
                || UserDefaults.standard[.masterHexEncodedPublicKey] != nil
        }
        return usesMultiDevice
    }

    // MARK: Typing Indicators
    /// Invoked only if typing indicators are enabled in the settings. Provides an opportunity
    /// to avoid sending them if certain conditions are met.
    @objc(shouldSendTypingIndicatorForThread:)
    public static func shouldSendTypingIndicator(for thread: TSThread) -> Bool {
        guard !thread.isGroupThread(), let contactID = thread.contactIdentifier() else { return false }
        var isContactFriend = false
        storage.dbReadConnection.read { transaction in
            isContactFriend = (storage.getFriendRequestStatus(for: contactID, transaction: transaction) == .friends)
        }
        return isContactFriend
    }

    // MARK: Receipts
    @objc(shouldSendReceiptForThread:)
    public static func shouldSendReceipt(for thread: TSThread) -> Bool {
        guard !thread.isGroupThread(), let contactID = thread.contactIdentifier() else { return false }
        var isContactFriend = false
        storage.dbReadConnection.read { transaction in
            isContactFriend = (storage.getFriendRequestStatus(for: contactID, transaction: transaction) == .friends)
        }
        return isContactFriend
    }

    // MARK: - Receiving

    @objc(shouldSkipMessageDecryptResult:)
    public static func shouldSkipMessageDecryptResult(_ result: OWSMessageDecryptResult) -> Bool {
        // Called from OWSMessageReceiver to prevent messages from even being added to the processing queue.
        // This intentionally doesn't take into account multi device.
        return result.source == getUserHexEncodedPublicKey() // Should never occur
    }

    @objc(updateDisplayNameIfNeededForHexEncodedPublicKey:using:transaction:)
    public static func updateDisplayNameIfNeeded(for publicKey: String, using dataMessage: SSKProtoDataMessage, in transaction: YapDatabaseReadWriteTransaction) {
        guard let profile = dataMessage.profile, let rawDisplayName = profile.displayName, !rawDisplayName.isEmpty else { return }
        let shortID = publicKey.substring(from: publicKey.index(publicKey.endIndex, offsetBy: -8))
        let displayName = "\(rawDisplayName) (...\(shortID))"
        let profileManager = SSKEnvironment.shared.profileManager
        profileManager.updateProfileForContact(withID: publicKey, displayName: displayName, with: transaction)
    }

    @objc(updateProfileKeyIfNeededForPublicKey:using:)
    public static func updateProfileKeyIfNeeded(for publicKey: String, using dataMessage: SSKProtoDataMessage) {
        guard dataMessage.hasProfileKey, let profileKey = dataMessage.profileKey else { return }
        guard profileKey.count == kAES256_KeyByteLength else {
            print("[Loki] Unexpected profile key size: \(profileKey.count).")
            return
        }
        let profilePictureURL = dataMessage.profile?.profilePicture
        let profileManager = SSKEnvironment.shared.profileManager
        profileManager.setProfileKeyData(profileKey, forRecipientId: publicKey, avatarURL: profilePictureURL)
    }
}
