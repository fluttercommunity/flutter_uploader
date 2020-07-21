//
//  PersistentUploader.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

protocol UploaderDelegate {
    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int)

    func uploadCompleted(taskId: String, message: String, statusCode: Int, headers: [String: Any])

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String, errorStackTrace: [String])
}

extension Array: UploaderDelegate where Element == UploaderDelegate {
    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int) {
        forEach { (e) in
            e.uploadProgressed(taskId: taskId, inStatus: inStatus, progress: progress)
        }
    }

    func uploadCompleted(taskId: String, message: String, statusCode: Int, headers: [String: Any]) {
        forEach { (e) in
            e.uploadCompleted(taskId: taskId, message: message, statusCode: statusCode, headers: headers)
        }
    }

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String, errorStackTrace: [String]) {
        forEach { (e) in
            e.uploadFailed(taskId: taskId, inStatus: inStatus, statusCode: statusCode, errorCode: errorCode, errorMessage: errorMessage, errorStackTrace: errorStackTrace)
        }
    }
}
