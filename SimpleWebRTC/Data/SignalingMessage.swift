//
//  SignalingSDP.swift
//  SimpleWebRTC
//
//  Created by n0 on 2019/01/08.
//  Copyright © 2019 n0. All rights reserved.
//

import Foundation

//struct SignalingSDP: Codable {
//    let type: String
//    let sdp: String
//}
//
//struct SignalingCandidate: Codable {
//    let type: String
//    let candidate: Candidate
//}
/*
struct SignalingMessage: Codable {
    let type: String?
    let sessionDescription: SDP?
    let candidate: Candidate?
}

struct SDP: Codable {
    let sdp: String
}

struct Candidate: Codable {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String
}
*/

struct SignalingClient: Codable {
    var client: Int?
    var text: SignalingMessage?
}

struct SignalingMessage: Codable {
    var message_type: String?
    var content: SDP?
    var code: String?
}

struct SDP: Codable {
    var sdp: String?
    var type: String?
    var sdpMLineIndex: Int?
    var sdpMid: String?
    var candidate: String?
    var userFragment: String?
}
