//
//  UploadResultDatabase.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

class UploadResultDatabase: UploaderDelegate {
    static let shared = UploadResultDatabase()

    private init() {
        if let plist = try? loadPropertyList(completedPListURL) {
            for c in plist {
                if let map = c as? [String: Any] {
                    self.completed.append(map)
                }
            }
        }

        if let plist = try? loadPropertyList(failedPListURL) {
            for c in plist {
                if let map = c as? [String: Any] {
                    self.failed.append(map)
                }
            }
        }
    }

    public func clear() {
        completed.removeAll()
        failed.removeAll()

        do {
            try savePropertyList(completedPListURL, [])
            try savePropertyList(failedPListURL, [])
        } catch {
            print("error write \(error)")
        }
    }

    var completed: [[String: Any]] = []
    var failed: [[String: Any]] = []
    
    func uploadEnqueued(taskId: String) {
    }

    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int) {
        // No need to store in-flight.
    }

    func uploadCompleted(taskId: String, message: String, statusCode: Int, headers: [String: Any]) {
        completed.append([
            "taskId": taskId,
            "message": message,
            "statusCode": statusCode,
            "headers": headers
        ])

        do {
            try savePropertyList(completedPListURL, completed)
        } catch {
            print("error write \(error)")
        }
    }

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String, errorStackTrace: [String]) {
        failed.append([
            "taskId": taskId,
            "statusCode": statusCode,
            "code": errorCode,
            "message": errorMessage,
            "details": errorStackTrace
        ])

        do {
            try savePropertyList(failedPListURL, failed)
        } catch {
            print("error write \(error)")
        }
    }

    private func savePropertyList(_ plistURL: URL, _ plist: Any) throws {
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: plistURL)
    }

    private func loadPropertyList(_ plistURL: URL) throws -> [Any] {
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [Any] else {
            return []
        }
        return plist
    }

    private var completedPListURL: URL {
        let documentDirectoryURL = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return documentDirectoryURL.appendingPathComponent("flutter_uploader-completed.plist")
    }

    private var failedPListURL: URL {
        let documentDirectoryURL = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return documentDirectoryURL.appendingPathComponent("flutter_uploader-failed.plist")
    }
}
