//
//  Constants.swift
//  Kombucha Social
//
//  Created by Macro Ramius on 12/14/20.
//

// swiftlint:disable identifier_name

import Foundation

let APP_PREFIX = "social.kombucha"

let ROOM_TAG_FOLLOWING = APP_PREFIX + ".following"
let ROOM_TAG_OUTBOUND = APP_PREFIX + ".outbound"
let ROOM_TAG_GROUP = APP_PREFIX + ".group"
let ROOM_TAG_CHAT = APP_PREFIX + ".chat"
let ROOM_TAG_PHOTOS = APP_PREFIX + ".photos"
let ROOM_TAG_NOTICES = APP_PREFIX + ".notices"

let EVENT_TYPE_CIRCLES = "social.kombucha.circles"
let EVENT_TYPE_CONFIGURED = "social.kombucha.configured"
let EVENT_TYPE_ROOMTYPE = "social.kombucha.room_type"

let ROOM_TYPE_CIRCLE = APP_PREFIX + ".circle"
let ROOM_TYPE_GROUP = APP_PREFIX + ".group"
let ROOM_TYPE_CHAT = APP_PREFIX + ".chat"
let ROOM_TYPE_PHOTOS = APP_PREFIX + ".photos"

// Use this for the pseudo-circle containing all of the rooms
// that we're following.
let CIRCLE_TAG_FOLLOWING = APP_PREFIX + ".following"

let KOMBUCHA_DEBUG = false

let PLAINTEXT_CACHE_FOLDER: String? = nil
let DECRYPTED_CACHE_FOLDER: String = "decrypted"
