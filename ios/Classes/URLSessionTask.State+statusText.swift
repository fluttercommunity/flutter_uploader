//
//  URLSessionTask.State+statusText.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

extension URLSessionTask.State {
    func statusText() -> String {
        switch self {
        case .running:
            return "running"
        case .canceling:
            return "canceling"
        case .completed:
            return "completed"
        case .suspended:
            return "suspended"
        default:
            return "unknown"
        }
    }
}
