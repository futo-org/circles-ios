//
//  CirclesSession.swift
//  Circles
//
//  Created by Charles Wright on 6/21/22.
//

import Foundation
import Matrix
import os

#if os(macOS)
import AppKit
#else
import UIKit
#endif


class CirclesApplicationSession: ObservableObject {
    var logger: os.Logger
    
    
    var matrix: Matrix.Session
    
    // We don't actually use the "Circles" root space room very much
    // Mostly it's just there to hide our stuff from cluttering up the rooms list in other clients
    // But here we hold on to its roomid in case we need it for anything
    // IDEA: We could store any Circles-specific configuration info in our account data in this room
    var rootRoomId: RoomId
    
    //typealias CircleRoom = ContainerRoom<Matrix.Room> // Each circle is a space, where we know we are joined in every child room
    //typealias PersonRoom = Matrix.SpaceRoom // Each person's profile room is a space, where we may or may not be members of the child rooms
    
    var circles: ContainerRoom<CircleSpace>     // Our top-level circles space contains the spaces for each of our circles
    var groups: ContainerRoom<GroupRoom>        // Groups space contains the individual rooms for each of our groups
    var galleries: ContainerRoom<GalleryRoom>   // Galleries space contains the individual rooms for each of our galleries
    var people: ContainerRoom<PersonRoom>       // People space contains the space rooms for each of our contacts
    var profile: ContainerRoom<Matrix.Room>     // Our profile space contains the "wall" rooms for each circle that we "publish" to our connections
    
    static func loadConfig(matrix: Matrix.Session) async throws -> CirclesConfigContent? {
        Matrix.logger.debug("Loading Circles configuration")
        // Easy mode: Do we have our config saved in the Account Data?
        if let config = try await matrix.getAccountData(for: EVENT_TYPE_CIRCLES_CONFIG, of: CirclesConfigContent.self) {
            Matrix.logger.debug("Found Circles config in the account data")
            return config
        } else {
            Matrix.logger.debug("No Circles config in account data.  Looking for rooms based on tags...")
        }

        // Not so easy mode: Do we have a room with our special tag?
        var tags = [RoomId: [String]]()
        let roomIds = try await matrix.getJoinedRoomIds()
        for roomId in roomIds {
            tags[roomId] = try await matrix.getTags(roomId: roomId)
            Matrix.logger.debug("\(roomId): \(tags[roomId]?.joined(separator: " ") ?? "(none)")")
        }
        
        guard let rootId: RoomId = roomIds.filter({
            if let t = tags[$0] {
                return t.contains(ROOM_TAG_CIRCLES_SPACE_ROOT)
            } else {
                return false
            }
        }).first
        else {
            Matrix.logger.error("Couldn't find Circles space root")
            throw CirclesError("Failed to find Circles space root")
        }
        Matrix.logger.debug("Found Circles space root \(rootId)")
        
        let childRoomIds = try await matrix.getSpaceChildren(rootId)
        
        guard let circlesId: RoomId = childRoomIds.filter({
                if let t = tags[$0] {
                    return t.contains(ROOM_TAG_MY_CIRCLES)
                } else {
                    return false
                }
            }).first
        else {
            Matrix.logger.error("Failed to find circles space")
            throw CirclesError("Failed to find circles space")
        }
        Matrix.logger.debug("Found circles space \(circlesId)")
                    
        guard let groupsId: RoomId = childRoomIds.filter({
                if let t = tags[$0] {
                    return t.contains(ROOM_TAG_MY_GROUPS)
                } else {
                    return false
                }
            }).first
        else {
            Matrix.logger.error("Failed to find groups space")
            throw CirclesError("Failed to find groups space")
        }
        Matrix.logger.debug("Found groups space \(groupsId)")
        
        guard let photosId: RoomId = childRoomIds.filter({
                if let t = tags[$0] {
                    return t.contains(ROOM_TAG_MY_PHOTOS)
                } else {
                    return false
                }
            }).first
        else {
            Matrix.logger.error("Failed to find photos space")
            throw CirclesError("Failed to find photos space")
        }
        Matrix.logger.debug("Found photos space \(photosId)")
        
        // People and Profile space are a bit different - They might not exist in previous Circles Android versions
        // So if we don't find them, it's ok.  Just create them now.
        
        func getSpaceId(tag: String, name: String) async throws -> RoomId {
            if let existingProfileSpaceId = childRoomIds.filter({
                    if let t = tags[$0] {
                        return t.contains(tag)
                    } else {
                        return false
                    }
            }).first {
                Matrix.logger.debug("Found space \(existingProfileSpaceId) with tag \(tag)")
                return existingProfileSpaceId
            }
            else {
                let newProfileSpaceId = try await matrix.createSpace(name: name)
                try await matrix.addTag(roomId: newProfileSpaceId, tag: tag)
                try await matrix.addSpaceChild(newProfileSpaceId, to: rootId)
                return newProfileSpaceId
            }
        }
        
        let displayName = try await matrix.getDisplayName(userId: matrix.creds.userId) ?? matrix.creds.userId.stringValue
        let profileId = try await getSpaceId(tag: ROOM_TAG_MY_PROFILE, name: displayName)
        let peopleId = try await getSpaceId(tag: ROOM_TAG_MY_PEOPLE, name: "My People")
        
        let config = CirclesConfigContent(root: rootId,
                                          circles: circlesId,
                                          groups: groupsId,
                                          galleries: photosId,
                                          people: peopleId,
                                          profile: profileId)
        // Also save this config for future use
        try await matrix.putAccountData(config, for: EVENT_TYPE_CIRCLES_CONFIG)
        
        return config
    }
    
    func setupPushNotifications() async throws {
        // From https://github.com/matrix-org/sygnal/blob/main/docs/applications.md#ios-applications-beware
        let payload = """
        {
          "url": "https://sygnal.circu.li/_matrix/push/v1/notify",
          "format": "event_id_only",
          "default_payload": {
            "aps": {
              "mutable-content": 1,
              "content-available": 1,
              "alert": {"loc-key": "SINGLE_UNREAD", "loc-args": []}
            }
          }
        }
        """
        
        logger.debug("Setting up push notifications")
        
        let path = "/_matrix/client/r0/pushers/set"
        let (data, response) = try await self.matrix.call(method: "POST", path: path, bodyData: payload.data(using: .utf8))
        
        logger.debug("Received \(data.count) bytes of response with status \(response.statusCode)")
    }
    
    init(matrix: Matrix.Session) async throws {
        let logger = Logger(subsystem: "Circles", category: "Session")
        self.logger = logger
        self.matrix = matrix
        
        let startTS = Date()
        
        logger.debug("Loading config from Matrix")
        let configStart = Date()
        guard let config = try await CirclesApplicationSession.loadConfig(matrix: matrix)
        else {
            logger.error("Could not load Circles config")
            throw Matrix.Error("Could not load Circles config")
        }
        let configEnd = Date()
        let configTime = configEnd.timeIntervalSince(configStart)
        logger.debug("\(configTime, privacy: .public) sec to load config from the server")

        logger.debug("Loading Matrix spaces")
        
        
        logger.debug("Loading Groups space")
        let groupsStart = Date()
        guard let groups = try await matrix.getRoom(roomId: config.groups, as: ContainerRoom<GroupRoom>.self)
        else {
            logger.error("Failed to load Groups space")
            throw CirclesError("Failed to load Groups space")
        }
        let groupsEnd = Date()
        let groupsTime = groupsEnd.timeIntervalSince(groupsStart)
        logger.debug("\(groupsTime, privacy: .public) sec to load Groups space")
        
        
        logger.debug("Loading Galleries space")
        let galleriesStart = Date()
        guard let galleries = try await matrix.getRoom(roomId: config.galleries, as: ContainerRoom<GalleryRoom>.self)
        else {
            logger.error("Failed to load Galleries space")
            throw CirclesError("Failed to load Galleries space")
        }
        let galleriesEnd = Date()
        let galleriesTime = galleriesEnd.timeIntervalSince(galleriesStart)
        logger.debug("\(galleriesTime, privacy: .public) sec to load Galleries space")
        
        logger.debug("Loading Circles space")
        let circlesStart = Date()
        guard let circles = try await matrix.getRoom(roomId: config.circles, as: ContainerRoom<CircleSpace>.self)
        else {
            logger.error("Failed to load Circles space")
            throw CirclesError("Failed to load Circles space")
        }
        let circlesEnd = Date()
        let circlesTime = circlesEnd.timeIntervalSince(circlesStart)
        logger.debug("\(circlesTime, privacy: .public) sec to load Circles space")
        
        logger.debug("Loading People space")
        let peopleStart = Date()
        guard let people = try await matrix.getRoom(roomId: config.people, as: ContainerRoom<PersonRoom>.self)
        else {
            logger.error("Failed to load People space")
            throw CirclesError("Failed to load People space")
        }
        let peopleEnd = Date()
        let peopleTime = peopleEnd.timeIntervalSince(peopleStart)
        logger.debug("\(peopleTime, privacy: .public) sec to load People space")
        
        logger.debug("Loading Profile space")
        let profileStart = Date()
        guard let profile = try await matrix.getRoom(roomId: config.profile, as: ContainerRoom<Matrix.Room>.self)
        else {
            logger.error("Failed to load Profile space")
            throw CirclesError("Failed to load Profile space")
        }
        let profileEnd = Date()
        let profileTime = profileEnd.timeIntervalSince(profileStart)
        logger.debug("\(profileTime, privacy: .public) sec to load Profile space")
        
        self.rootRoomId = config.root
        
        self.groups = groups
        self.galleries = galleries
        self.circles = circles
        self.people = people
        self.profile = profile
        
        let endTS = Date()
        
        let totalTime = endTS.timeIntervalSince(startTS)
        logger.debug("\(totalTime, privacy: .public) sec to initialize Circles Session")
        
        logger.debug("Starting Matrix background sync")
        try await matrix.startBackgroundSync()
                
        logger.debug("Finished setting up Circles application session")
    }
    
    func cancelUIA() async throws {
        // Cancel any current Matrix UIA session that we may have
        try await matrix.cancelUIA()
        // And tell any SwiftUI views (eg the main ContentView) that they should re-draw
        await MainActor.run {
            self.objectWillChange.send()
        }
    }

    
    func close() async throws {
        logger.debug("Closing Circles session")
        try await matrix.close()
    }
}
