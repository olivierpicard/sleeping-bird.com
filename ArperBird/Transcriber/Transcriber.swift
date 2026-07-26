//
//  Transcriber.swift
//  ArperBird
//
//  Created by Olivier Picard on 17/04/2026.
//

import Foundation

// MARK: - Protocol

/// Describes a type that can stream audio and deliver live transcripts.
protocol Transcriber: AnyObject {
    /// Whether microphone recording permission is currently granted.
    /// Read this before `start` to decide whether to begin dictation or
    /// prompt the user. Permission itself is requested during onboarding.
    var hasMicPermission: Bool { get }
    /// Call the closure with the full text since this start function is called
    func start(onText: @escaping (_ text: String) -> Void)
    func stop()
}
