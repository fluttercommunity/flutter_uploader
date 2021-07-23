//
//  UploadResultDatabase.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

/// A helper class which stores the upload results for later retrieval by the plugin.
/// This mimics the behavior of the workmanager LiveData on Android, which allows a limited retrieval of completed work.
class UploadResultDatabase: UploaderDelegate {
    static let shared = UploadResultDatabase()

    private init() {
        if let url = resultsPListURL, let plist = try? loadPropertyList(url) {
            for result in plist {
                if let map = result as? [String: Any] {
                    self.results.append(map)
                }
            }
        }
    }

    public func clear() {
        results.removeAll()

        guard let url = resultsPListURL else { return }

        do {
            try savePropertyList(url, [])
        } catch {
            print("error write \(error)")
        }
    }

    var results: [[String: Any]] = []

    func uploadEnqueued(taskId: String) {
        results.append([
            Key.taskId: taskId,
            Key.status: UploadTaskStatus.enqueue.rawValue
        ])

        guard let url = resultsPListURL else { return }

        do {
            try savePropertyList(url, results)
        } catch {
            print("error write \(error)")
        }
    }

    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int) {
        // No need to store in-flight.
    }

    func uploadCompleted(taskId: String, message: String?, statusCode: Int, headers: [String: Any]) {
        results.append([
            Key.taskId: taskId,
            Key.status: UploadTaskStatus.completed.rawValue,
            Key.message: message ?? "",
            Key.statusCode: statusCode,
            Key.headers: headers
        ])

        guard let url = resultsPListURL else { return }

        do {
            try savePropertyList(url, results)
        } catch {
            print("error write \(error)")
        }
    }

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String?, errorStackTrace: [String]) {
        results.append([
            Key.taskId: taskId,
            Key.status: inStatus.rawValue,
            Key.statusCode: statusCode,
            Key.code: errorCode,
            Key.message: errorMessage ?? NSNull(),
            Key.details: errorStackTrace
        ])

        guard let url = resultsPListURL else { return }

        do {
            try savePropertyList(url, results)
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

    private var resultsPListURL: URL? {
        let documentDirectoryURL = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return documentDirectoryURL?.appendingPathComponent("flutter_uploader-results.plist")
    }
}
