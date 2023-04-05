//
//  ContainerRoom.swift
//  Circles
//
//  Created by Charles Wright on 3/22/23.
//

import Foundation
import os
import Matrix

class ContainerRoom<T: Matrix.Room>: Matrix.Room {
    @Published public var rooms: [T]
    var logger: os.Logger
    
    public required init(roomId: RoomId, session: Matrix.Session, initialState: [ClientEventWithoutRoomId], initialTimeline: [ClientEventWithoutRoomId] = []) throws {
        self.rooms = []
        self.logger = Logger(subsystem: "container", category: roomId.description)
        try super.init(roomId: roomId, session: session, initialState: initialState, initialTimeline: initialTimeline)
        
        // Now let's look to see what (if any) child rooms we have
        
        if let dict = self.state[M_SPACE_CHILD] {
            let _ = Task {
                var tmpRooms = [T]()
                for (stateKey, event) in dict {
                    guard let childRoomId = RoomId(stateKey),
                          let content = event.content as? SpaceChildContent,
                          content.via?.first != nil
                    else {
                        continue
                    }
                    logger.debug("Found a child room: \(childRoomId)")
                    /*
                    let stateEvents = try await self.session.getRoomStateEvents(roomId: roomId)
                    let room = try T(roomId: childRoomId, session: session, initialState: stateEvents, initialTimeline: [])
                    */
                    guard let room = try await session.getRoom(roomId: childRoomId, as: T.self)
                    else {
                        logger.error("Failed to create child room \(childRoomId)")
                        continue
                    }
                    tmpRooms.append(room)
                }
                let newRooms = tmpRooms
                logger.debug("Found a total of \(newRooms.count) child rooms")
                await MainActor.run {
                    self.rooms = newRooms
                }
            }
        }
    }
    
    public override func updateTimeline(from events: [ClientEventWithoutRoomId]) async throws {
        logger.debug("Updating timeline")
        try await super.updateTimeline(from: events)
    }
    
    // Add a Room object to our rooms list whenever we get a new space child
    public override func updateState(from event: ClientEventWithoutRoomId) async {
        logger.debug("Updating state")
        // First do all the normal stuff to update our local room state
        await super.updateState(from: event)
        
        // Then check to see whether this event is one that we need to handle
        if event.type == M_SPACE_CHILD {
            logger.debug("Got a new \(event.type) event")
            // Make sure it's a valid space child event
            guard let stateKey = event.stateKey,
                  let content = event.content as? SpaceChildContent,
                  let childRoomId = RoomId(stateKey)
            else {
                return
            }
            logger.debug("Child room id = \(childRoomId)")
            
            // OK, are we adding or removing a space child room?
            if content.via?.first == nil {
                // We're removing an old child room from the space
                
                await MainActor.run {
                    self.rooms.removeAll(where: { $0.roomId == childRoomId })
                }
                return

            } else {
                // We're adding a new child room to the space
                
                /*
                guard let stateEvents = try? await self.session.getRoomStateEvents(roomId: roomId),
                      let room = try? T(roomId: roomId, session: self.session, initialState: stateEvents)
                else {
                    return
                }
                */
                guard let room = try? await self.session.getRoom(roomId: childRoomId, as: T.self)
                else {
                    logger.error("Failed to create Room for new child room \(childRoomId)")
                    return
                }
                await MainActor.run {
                    self.rooms.append(room)
                }
            }
        }
    }
    
    public func leaveChildRoom(_ childRoomId: RoomId) async throws {
        try await self.session.removeSpaceChild(childRoomId, from: self.roomId)
        try await self.session.leave(roomId: childRoomId)
    }
    
    public func removeChildRoom(_ childRoomId: RoomId) async throws {
        try await self.session.removeSpaceChild(childRoomId, from: self.roomId)
        // NOTE: We don't have to do anything to the `rooms` object here.
        //       If everything works as it should, Matrix will give us the
        //       m.space.child event on our next sync, and then we will
        //       automatically create the Room object and add it to our list.
    }
    
    public func addChildRoom(_ childRoomId: RoomId) async throws {
        try await self.session.addSpaceChild(childRoomId, to: self.roomId)
        // NOTE: We don't have to do anything to the `rooms` object here.
        //       If everything works as it should, Matrix will give us the
        //       m.space.child event on our next sync, and then we will
        //       automatically create the Room object and add it to our list.
    }
    
    public func createChildRoom(name: String,
                                type: String?,
                                encrypted: Bool,
                                avatar: Matrix.NativeImage?
    ) async throws -> RoomId {
        let childRoomId = try await self.session.createRoom(name: name, type: type, encrypted: encrypted)
        try await self.addChildRoom(childRoomId)
        if let image = avatar {
            try await self.session.setAvatarImage(roomId: childRoomId, image: image)
        }
        return childRoomId
    }
}
