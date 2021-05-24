//
//  PersistentUploader.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

protocol UploaderDelegate {
    func uploadEnqueued(taskId: String)

    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int)

    func uploadCompleted(taskId: String, message: String?, statusCode: Int, headers: [String: Any])

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String?, errorStackTrace: [String])
}

extension Array: UploaderDelegate where Element == UploaderDelegate {
    func uploadEnqueued(taskId: String) {
        forEach { (delegate) in
            delegate.uploadEnqueued(taskId: taskId)
        }
    }

    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int) {
        forEach { (delegate) in
            delegate.uploadProgressed(taskId: taskId, inStatus: inStatus, progress: progress)
        }
    }

    func uploadCompleted(taskId: String, message: String?, statusCode: Int, headers: [String: Any]) {
        forEach { (delegate) in
            delegate.uploadCompleted(taskId: taskId, message: message, statusCode: statusCode, headers: headers)
        }
    }

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String?, errorStackTrace: [String]) {
        forEach { (delegate) in
            delegate.uploadFailed(taskId: taskId, inStatus: inStatus, statusCode: statusCode, errorCode: errorCode, errorMessage: errorMessage, errorStackTrace: errorStackTrace)
        }
    }
}
