//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//  Copyright 2022 FUTO Holdings, Inc
//
//  MatrixRoom.swift
//  Circles for iOS
//
//  Created by Charles Wright on 10/28/20.
//

// swiftlint:disable identifier_name

import Foundation
import MatrixSDK

class MatrixRoom: ObservableObject, Identifiable, Equatable, Hashable {
    private let mxroom: MXRoom
    let roomId: RoomId
    var id: String {
        roomId.description
    }
    let matrix: MatrixSession
    private var localEchoEvent: MXEvent?
    private var backwardTimeline: MXRoomEventTimeline?

    @Published var first: MatrixMessage?
    @Published var last: MatrixMessage?
    @Published var isPaginating: Bool = false

    @Published var membership = [String:String]()

    var downloadingAvatar: Bool = false
    
    // This local info works together with the MXSession's ignored users list,
    // which is stored in the Matrix account_data.
    // Having a local ignore list lets us block out messages from users who
    // weren't ignored when the message came in, but have since been ignored.
    private var ignoredSenders: Set<String> = []

    init(from mxroom: MXRoom, on matrix: MatrixSession) {
        self.mxroom = mxroom
        self.roomId = RoomId(mxroom.roomId)!
        self.matrix = matrix

        _ = Task {
            try await asyncInit()
        }
    }
    
    func asyncInit() async throws {
        try await self.updateDisplayName()
        try await self.updateAvatar()
        self.initTimeline()
        self.refresh()
        self.updatePowerLevels()
    }


    func _eventHandler(event: MXEvent, direction: MXTimelineDirection, state: MXRoomState?) {

        print("TIMELINE --------")
        print("TIMELINE Handling new event with id [\(event.eventId ?? "???")]")
        if event.eventType == .roomEncrypted {
            print("TIMELINE Event [\(event.eventId ?? "???")] in Room [\(self.displayName ?? self.id)] is encrypted.  Hopefully we'll see it again.")
            //return
        } else if event.eventType == .roomMessage {
            print("TIMELINE Event [\(event.eventId ?? "???")] is a room message.  Processing...")
        } else if event.eventType == .reaction {
            // FIXME Look at MXAggregations.h for the SDK's way of supporting reactions
            // * There's a `listenToReactionCountUpdateInRoom()` function that we can use to keep track of the reactions
            // * There's a `aggregatedReactionsOnEvent()` function for getting all the reactions for an event
            // So how in the world do we get an instance of this thing???
            // --> It's matrix.session.aggregations :)
            print("TIMELINE Event [\(event.eventId ?? "???")] is a reaction.  Ignoring for now...")
            return
        }
        print("TIMELINE --------")


        switch event.eventType {
            
        case .roomEncrypted:
            // I want to see encrypted events too, when they never get decrypted
            let msg = MatrixMessage(from: event, in: self)
            self.objectWillChange.send()
            self.messages[msg.id] = msg

        case .roomMessage:
            /* FIXME: Need to find a better way to handle ignored users
                      Right here, we really need to have an accurate list of which messages we've fetched
            // Hide messages from people on our ignore list
            if self.ignoredSenders.contains(event.sender) {
                return
            }
            */

            let msg = MatrixMessage(from: event, in: self)
            self.objectWillChange.send()
            //self.messages.insert(msg)
            self.messages[msg.id] = msg

            if self.first == nil || msg.timestamp < self.first!.timestamp {
                self.first = msg
            }

            if self.last == nil || msg.timestamp > self.last!.timestamp {
                self.last = msg
            }

            if self.localEchoEvent?.eventId == event.eventId {
                // Aha, here's the "real" version of our local echo guy.  We only need this to exist in one place.
                self.localEchoEvent = nil
            }

        case .roomMember:
            guard direction == .forwards else {
                // Ignore historical membership events
                return
            }
            guard let userId = event.stateKey,
                  let userState = event.content["membership"] as? String else {
                print("ROOM.TIMELINE\tGot a bogus m.room.member event")
                return
            }

            let validStates = ["invite", "join", "leave", "ban", "knock"]
            guard validStates.contains(userState) else {
                print("ROOM.TIMELINE\tGot a bogus membership state [\(userState)]")
                return
            }

            print("ROOM.TIMELINE\tGot a membership update: \(userId) --> \(userState)")
            self.membership[userId] = userState

        case .roomName:
            guard direction == .forwards else {
                return
            }
            if let newName = event.content["name"] as? String {
                self.displayName = newName
            }

        case .roomAvatar:
            guard direction == .forwards else {
                return
            }
            if let url = event.content["url"] as? String {
                _ = Task {
                    try await fetchAvatar(from: url)
                }
            }

        default:
            break
        }
    }

    func initTimeline() {
        self.backwardTimeline = MXRoomEventTimeline(room: mxroom, andInitialEventId: nil)
        self.backwardTimeline?.resetPagination()

        //let eventTypes: [MXEventType] = [.roomMessage, .roomEncrypted]
        let eventTypes: [MXEventType] = [.roomMessage, .roomMember, .roomEncrypted, .roomAvatar]
        _ = self.backwardTimeline?.listenToEvents(eventTypes, self._eventHandler)

        self.mxroom.liveTimeline() { maybeTimeline in
            guard let timeline = maybeTimeline else {
                return
            }

            _ = timeline.listenToEvents(eventTypes, self._eventHandler)
        }
    }

    func refresh() {
        self.updateOwners()
        self.updateMembers()
        // self.loadMessages(max: 25)
        self.paginate() { _ in }
    }

    var type: String? {
        self.mxroom.summary?.roomTypeString
    }


    @Published var displayName: String?

    func updateDisplayName() async throws {
        let newName = try await matrix.getDisplayName(roomId: roomId)
        await MainActor.run {
            displayName = newName
        }
    }

    func setDisplayName(_ name: String) async throws {
        try await matrix.setDisplayName(roomId: roomId, name: name)
        await MainActor.run {
            displayName = name
        }
    }

    // FIXME Make this one settable as well as gettable
    //       The set() just makes the API call
    var topic: String? {
        mxroom.summary?.topic
    }

    /*
    // FIXME Make this one settable as well as gettable
    //       The set() just makes the API call
    var avatarURL: String? {
        mxroom.summary.avatar
    }
    */

    // FIXME Make this one settable as well as gettable
    //       The set() just makes the API call
    @Published var avatarImage: UIImage?

    private func fetchAvatar(from url: String) async throws {
        guard let mxc = MXC(url)
        else {
            let msg = "Invalid MXC URL"
            print(msg)
            throw Matrix.Error(msg)
        }
        let data = try await matrix.downloadData(mxc: mxc)
        let image = UIImage(data: data)
        await MainActor.run {
            self.avatarImage = image
        }
    }

    func updateAvatar() async throws {
        let image = try await matrix.getAvatarImage(roomId: roomId)
        await MainActor.run {
            self.avatarImage = image
        }
    }

    func setAvatarImage(image: UIImage) async throws {
        try await matrix.setAvatarImage(roomId: roomId, image: image)
    }

    func enableEncryption(completion: @escaping (MXResponse<Void>)->Void) {
        self.mxroom
            .enableEncryption(withAlgorithm: "m.megolm.v1.aes-sha2",
                              completion: completion)
    }


    /*
    var creator: MatrixUser? {
        guard let userId = mxroom.summary.creatorUserId else {
            return nil
        }
        return matrix.getUser(userId: userId)
    }
    */
    var creatorId: UserId? {
        UserId(mxroom.summary.creatorUserId)
    }

    var owners: [MatrixUser] {
        userPowerLevels.keys.compactMap { key in
            let uid = key as String
            guard let power = self.userPowerLevels[uid] else {
                return nil
            }
            if power >= 100 {
                guard let userId = UserId(uid) else { return nil }
                return matrix.getUser(userId: userId)
            } else {
                return nil
            }
        }
    }

    private var allPowerLevels: MXRoomPowerLevels?
    @Published var userPowerLevels = [String: Int]()

    func updatePowerLevels() {

        mxroom.state { roomState in
            guard let allPLs = roomState?.powerLevels else {
                print("ROOM\tCouldn't get ANY power levels for room \(self.id) (\(self.displayName ?? "???"))")
                return
            }
            print("ROOM\tGot basic power levels for room \(self.id)")
            self.allPowerLevels = allPLs

            guard let userPLs = allPLs.users as? [String:Int] else {
                print("ROOM\tCouldn't get user power levels for room \(self.id) (\(self.displayName ?? "???"))")
                return
            }
            print("ROOM\tGot user power levels for room \(self.id)")
            self.userPowerLevels = userPLs
        }

    }

    func getPowerLevel(userId: String) -> Int {
        if let power = userPowerLevels[userId] {
            return power
        }

        if let PLs = allPowerLevels {
            return PLs.usersDefault
        }

        return 0
    }

    func setPowerLevel(userId: String, power: Int, completion handler: @escaping (MXResponse<Void>) -> Void) {
        mxroom.setPowerLevel(ofUser: userId, powerLevel: power) { response in
            if response.isSuccess {
                self.objectWillChange.send()
                // Also update our local cache
                self.userPowerLevels[userId] = power
            }

            handler(response)
        }
    }

    func amIaModerator() -> Bool {
        guard let power = self.userPowerLevels[matrix.whoAmI()] else {
            return false
        }

        return power >= 50
    }

    func asyncOwners(completion: @escaping (MXResponse<[MatrixUser]>) -> Void) {
        mxroom.state { state in
            guard let PLs = state?.powerLevels?.users else {
                let msg = "Couldn't find power levels"
                completion(.failure(KSError(message: msg)))
                return
            }

            var owners: [MatrixUser] = []
            for (u, l) in PLs {
                // swiftlint:disable:next force_cast
                let userId = u as! String
                // swiftlint:disable:next force_cast
                let level = l as! Int
                if level >= 100 {
                    if let user = self.matrix.getUser(userId: userId) {
                        owners.append(user)
                    }
                }
            }
            completion(.success(owners))
        }
    }

    func updateOwners() {
        self.updatePowerLevels()
    }

    private var cachedMemberUserIds: [String] = []

    // var roomLocalAvatarUrls: [String: String] = [:]
    // var roomLocalDisplayNames: [String: String] = [:]

    private var mxMembers: MXRoomMembers?

    func updateMembers() {
        self.asyncMembers(completion: { _ in })
    }

    func asyncMembers(completion: @escaping (MXResponse<[MatrixUser]>) -> Void) {
        print("ASYNCMEMBERS\tGetting members for room \(self.displayName) [\(self.id)]")
        matrix.fetchRoomMemberList(roomId: self.id) { response in
            guard case let .success(latestMembership) = response else {
                let msg = "Matrix request failed"
                print("ASYNCMEMBERS\t\(msg)")
                let err = KSError(message: msg)
                completion(.failure(err))
                return
            }
            self.membership = latestMembership
        }
    }

    func _getCurrentMembers(state: String) -> [MatrixUser] {
        self.membership.keys.compactMap { key in
            let userId = key as String
            guard let userState = self.membership[key] else {
                return nil
            }
            if userState == state {
                return matrix.getUser(userId: userId)
            } else {
                return nil
            }
        }

    }

    var joinedMembers: [MatrixUser] {
        _getCurrentMembers(state: "join")
    }

    var invitedMembers: [MatrixUser] {
        _getCurrentMembers(state: "invite")
    }

    var leftMembers: [MatrixUser] {
        _getCurrentMembers(state: "leave")
    }

    var bannedMembers: [MatrixUser] {
        _getCurrentMembers(state: "ban")
    }
    
    var membersCount: UInt {
        guard let summary = mxroom.summary else {
            return 0
        }
        return summary.membersCount.joined
    }

    var timestamp: Date {
        guard let summary = mxroom.summary else {
            // Garbage value
            return Date()
        }
        let seconds = summary.lastMessage.originServerTs / 1000
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
    
    // FIXME Make messages @Published, so we don't have to deal with
    //       sending the update manually when it changes
    // var messages: [MatrixMessage] = []
    //
    // 2020-11-20 Making the message store a Set instead of Array
    //            Now we need to handle messages coming in from
    //            potentially multiple different directions, eg.
    //            the room's timeline event handler(s).
    //            Just to be sure we never get duplicates, we're
    //            going with the Set for internal purposes.
    //            This also lets us get away from caring about
    //            keeping the thing sorted internally, and it
    //            should be more efficient to test whether or not
    //            a given message is in our collection.
    //var messages: Set<MatrixMessage> = []
    // 2022-04-27 I want to be able to see when a message fails
    //            to decrypt.  So it's easier if we have a single
    //            way to uniquely identify each message in the
    //            room.  This argues for making the messages a dict.
    var messages: [String: MatrixMessage] = [:]
    
    func canPaginate() -> Bool {
        backwardTimeline?.canPaginate(.backwards) ?? false
    }

    // Request more messages from the server (and/or the MXStore)
    func paginate(count: UInt = 25, completion: @escaping (MXResponse<Void>)->Void) {
        guard let timeline = self.backwardTimeline else {
            let msg = "Error: No timeline for room [\(self.displayName ?? self.id)]"
            let err = KSError(message: msg)
            print(msg)
            completion(.failure(err))
            return
        }

        if !timeline.canPaginate(.backwards) {
            let msg = "Error: Can't paginate our timeline for room [\(self.displayName ?? self.id)]"
            let err = KSError(message: msg)
            print(msg)
            completion(.failure(err))
            return
        }
        
        if !self.isPaginating {
            self.isPaginating = true
            timeline.paginate(count, direction: .backwards, onlyFromStore: false) { response in
                // When we get this call, the timeline will have been populated in the MXSession/MXStore
                switch response {
                case .failure(let error):
                    print("Pagination request failed: \(error)")
                case .success:
                    self.objectWillChange.send()
                }
                self.isPaginating = false
                completion(response)
            }
        }
    }

    func getMessages(since date: Date? = nil) -> [MatrixMessage] {
        if let cutoff = date {
            let result = self.messages.values
                .filter({ $0.timestamp > cutoff })
                .filter({ !self.ignoredSenders.contains($0.sender) })
                .sorted(by: {$0.timestamp > $1.timestamp})
            print("Found \(result.count) messages since \(date) in room [\(self.displayName ?? self.id)]")
            return result
        } else {
            // return Array(self.messages)
            return self.messages.values
                .filter({ !self.ignoredSenders.contains($0.sender) })
                .sorted(by: {$0.timestamp > $1.timestamp})
        }
    }

    func getTopLevelMessages(since date: Date? = nil) -> [MatrixMessage] {
        self.getMessages(since: date)
            .filter( {$0.relatesToId == nil} )
    }

    func getReplies(to eventId: String) -> [MatrixMessage] {
        return self.getMessages().filter { (msg) in
            switch msg.content {
            case .text(let content):
                return content.relates_to?.in_reply_to?.event_id == eventId
            case .notice(let content):
                return content.relates_to?.in_reply_to?.event_id == eventId
            default:
                return false
            }
        }
    }
    
    var localEchoMessage: MatrixMessage? {
        guard let mxevent = self.localEchoEvent else {
            return nil
        }
        return MatrixMessage(from: mxevent, in: self)
    }

    var membershipEvents: [MXEvent] {
        if let enumerator = mxroom.enumeratorForStoredMessagesWithType(in: ["m.room.member"]) {
            return enumerator.nextEventsBatch(100, threadId: nil) ?? []
        }
        return []
    }

    func whoInvitedMe() -> String? {
        let me = self.matrix.whoAmI()
        guard let enumerator = mxroom.enumeratorForStoredMessagesWithType(in: ["m.room.member"]) else {
            return nil
        }
        var batch: [MXEvent]?
        var inviteEvent: MXEvent?
        repeat {
            batch = enumerator.nextEventsBatch(100, threadId: nil)
            inviteEvent = batch?.last {
                $0.type == kMXEventTypeStringRoomMember && $0.stateKey == me
            }
            if let event = inviteEvent {
                return event.sender
            }
        } while inviteEvent == nil && batch != nil

        return nil
    }

    func invite(userId: String, completion: @escaping (MXResponse<Void>) -> Void = { _ in }) {
        print("ROOM\tInviting user [\(userId)]")
        mxroom.invite(.userId(userId)) { response in
            switch response {
            case .failure(let err):
                print("ROOM\tFailed to invite \(userId) -- \(err)")
            case .success:
                print("ROOM\tSuccessfully invited \(userId)")
            }
            completion(response)
        }
    }
    
    func kick(userId: String, reason: String, completion: @escaping (MXResponse<String>) -> Void = { _ in }) {
        print("Kicking user \(userId) from room \(self.displayName ?? self.id)")
        mxroom.kickUser(userId, reason: reason) { response in
            switch response {
            case .failure(let err):
                let msg = "Failed to kick user [\(userId)]"
                print(msg)
                completion(.failure(KSError(message: msg)))
            case .success:
                print("Successfully kicked user \(userId)")
                self.updateMembers()
                self.objectWillChange.send()
                completion(.success(userId))
            }
        }
    }

    func ban(userId: String, reason: String, completion: @escaping (MXResponse<String>) -> Void = { _ in }) {
        mxroom.banUser(userId, reason: reason) { response in
            switch response {
            case .failure(let err):
                completion(.failure(KSError(message: "Failed to ban user [\(userId)]")))
            case .success:
                self.updateMembers()
                self.objectWillChange.send()
                completion(.success(userId))
            }
        }
    }
    
    func setTopic(topic: String, completion: @escaping (MXResponse<Void>) -> Void) {
        self.mxroom.setTopic(topic) { response in
            switch response {
            case .failure(let error):
                print("Failed to set topic: \(error)")
            case .success:
                self.objectWillChange.send()
                // print("Yay success changing topic")
            }
            completion(response)
        }
    }

    var isEncrypted: Bool {
        guard let summary = mxroom.summary else {
            return false
        }
        return summary.isEncrypted
    }

    func postText(text: String, completion: @escaping (MXResponse<String?>) -> Void) {
        self.localEchoEvent = nil
        self.mxroom.sendTextMessage(text, localEcho: &self.localEchoEvent) { response in
            switch response {
            case .failure(let error):
                print("POST Failed to send text message: \(error)")
            case .success(let eventIdFromServer):
                self.objectWillChange.send()

                // At this point, we should have our "real" eventId from the homeserver.
                // Let's go ahead and put the message into the collection.
                if let event = self.localEchoEvent {
                    let msg = MatrixMessage(from: event, in: self)
                    //self.messages.insert(msg)
                    self.messages[event.eventId] = msg
                    // IMPORTANT: We also must remove the local echo,
                    // or any Views that try to use it will get double-vision
                    self.localEchoEvent = nil
                }

            }
            completion(response)
        }
    }

    func postReply(to event: MXEvent, text: String, completion: @escaping (MXResponse<String?>) -> Void) {
        // FIXME This shit does some of the most awful butchering I've ever seen
        //       It copies the parent message right into the content!
        //       NOT what we want here, when we have a "real"er threaded(-ish) UI
        /*
        self.mxroom.sendReply(to: event,
                              textMessage: text,
                              formattedTextMessage: nil,
                              stringLocalizations: nil,
                              localEcho: &self.localEchoEvent,
                              completion: completion)
        */

        // Better version.  Hack it together ourselves with the lower-level function
        let inReplyTo: [String: String] = ["event_id": event.eventId]
        let relatesTo: [String: [String:String]] = ["m.in_reply_to": inReplyTo]
        var content: [String: Any] = [:]
        content["msgtype"] = kMXMessageTypeText
        content["body"] = text
        content["m.relates_to"] = relatesTo
        self.mxroom.sendMessage(withContent: content, localEcho: &self.localEchoEvent, completion: completion)
    }

    func postImage(image: UIImage, caption: String? = nil, completion: @escaping (MXResponse<String?>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.90) else {
            let msg = "Failed to compress image"
            print(msg)
            completion(.failure(KSError(message: msg)))
            return
        }

        let thumbnailSize = CGSize(width: CGFloat(640), height: CGFloat(640))
        guard let thumb = downscale_image(from: image, to: thumbnailSize) else {
            let msg = "Failed to create thumbnail"
            print(msg)
            completion(.failure(KSError(message: msg)))
            return
        }
        
        // Created these vars to track the actual image data that we're going to upload
        // It might be the original, or if that's too big, it might be the downsampled
        var uploadImage = image
        var uploadData = data

        // Don't try to upload more than 4 MB
        let MAX_DATA_SIZE = 4 << 20
        
        if data.count > MAX_DATA_SIZE {
            print("Need to resize...")
            let maxSize = CGSize(width: CGFloat(1024), height: CGFloat(768))
            guard let newImage = downscale_image(from: image, to: maxSize) else {
                let msg = "Failed to downscale image"
                print(msg)
                completion(.failure(KSError(message: msg)))
                return
            }
            guard let newData = newImage.jpegData(compressionQuality: 0.75) else {
                let msg = "Failed to compress downscaled image"
                print(msg)
                completion(.failure(KSError(message: msg)))
                return
            }
            uploadImage = newImage
            uploadData = newData
        }

        var blurhash: String?
        let tinyWidth: Int = BLURHASH_WIDTH * 16
        let tinyHeight: Int = Int(CGFloat(tinyWidth) * thumb.size.height / thumb.size.width)
        let tinySize = CGSize(width: tinyWidth, height: tinyHeight)
        print("SENDIMAGE\tTiny image is \(tinyWidth)x\(tinyHeight)")
        // BlurHash'ing the thumbnail was sloooooooow
        // Let's see what happens with a 4x smaller version
        if let tiny = downscale_image(from: thumb, to: tinySize) {
            let blurWidth: Int = BLURHASH_WIDTH
            let blurHeight: Int = Int( CGFloat(blurWidth) * CGFloat(tinyHeight) / CGFloat(tinyWidth))
            print("SENDIMAGE\tBlurHash will be \(blurWidth)x\(blurHeight)")
            blurhash = tiny.blurHash(numberOfComponents: (blurWidth,blurHeight))
        }

        print("SENDIMAGE\tAttempting to upload \(uploadData.count) data")
        self.mxroom.sendImage(
            data: uploadData,
            size: uploadImage.size,
            mimeType: "image/jpeg",
            thumbnail: thumb,
            blurhash: blurhash,
            //caption: caption,
            localEcho: &self.localEchoEvent
        ) { response in
            switch response {
            case .failure(let error):
                print("SENDIMAGE\tFailed to send image: \(error)")
                completion(.failure(KSError(message: "Failed to send image")))
            case .success(let msg):
                print("SENDIMAGE\tUpload image success!  [\(msg ?? "(no response message)")]")
                self.objectWillChange.send()

                // At this point, we should have our "real" eventId from the homeserver.
                // Let's go ahead and put the message into the collection.
                if let event = self.localEchoEvent {
                    let msg = MatrixMessage(from: event, in: self)
                    //self.messages.insert(msg)
                    self.messages[event.eventId] = msg
                    // IMPORTANT: We also must remove the local echo,
                    // or any Views that try to use it will get double-vision
                    self.localEchoEvent = nil
                }
                completion(.success(msg))
            }
        }
    }
    
    var tags: [String] {
        guard let tags = mxroom.accountData.tags else {
            return []
        }
        // Not sure why we have to do this moronic dance,
        // when Swift should already know that the Key type is String.
        // Hmmm...  #ThisWillAllMakeSenseWhenIAmOlder
        return tags.keys.compactMap { tag in
            tag
        }
    }

    func addTag(tag: String, completion: @escaping (MXResponse<Void>) -> Void) {
        let order = String(format: "%1.2f", Double.random(in: 0 ..< 1))
        mxroom.addTag(tag, withOrder: order, completion: completion)
    }

    func removeTag(tag: String, completion handler: @escaping (MXResponse<Void>) -> Void) {
        mxroom.removeTag(tag) { response in
            switch response {
            case .failure(let error):
                let msg = "Failed to remove tag \"\(tag)\": \(error)"
                print(msg)
            case .success:
                print("Successfully set tag \"\(tag)\"!")
            }
            handler(response)
        }
    }

    func redact(message: MatrixMessage, reason: String?, completion: @escaping (MXResponse<Void>) -> Void) {
        mxroom.redactEvent(message.id, reason: reason) { response in
            if response.isSuccess {
                self.objectWillChange.send()
                self.messages[message.id] = nil
            }
            completion(response)
        }
    }
    
    func report(message: MatrixMessage, severity: Int, reasons: [String], completion: @escaping (MXResponse<Void>) -> Void) {
        let reason = reasons.joined(separator: "|")
        mxroom.reportEvent(message.id,
                           score: severity,
                           reason: reason) { response in
            if response.isSuccess {
                self.objectWillChange.send()
                self.messages[message.id] = nil
            }
            completion(response)
        }
    }

    var cryptoAlgorithm: String {
        if isEncrypted {
            return matrix.getCryptoAlgorithm(roomId: self.id)
        } else {
            return "Plaintext"
        }
    }

    var inboundOlmSessions: [MXOlmInboundGroupSession] {
        matrix.getInboundGroupSessions()
            .filter { groupSession in
                groupSession.roomId == self.id
            }
    }

    var outboundOlmSessions: [MXOlmOutboundGroupSession] {
        matrix.getOutboundGroupSessions()
            .filter { groupSession in
                groupSession.roomId == self.id
            }
    }

    // For Equatable
    static func == (lhs: MatrixRoom, rhs: MatrixRoom) -> Bool {
        return lhs.id == rhs.id
    }

    // For Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
