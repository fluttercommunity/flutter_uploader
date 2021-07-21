//
//  UploadTask.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

enum UploadTaskStatus: Int {
    case undefined = 0, enqueue, running, completed, failed, canceled, paused
}

struct UploadTask {
    let taskId: String
    let status: UploadTaskStatus
    let progress: Int
    let tag: String?
    let allowCellular: Bool

    init(taskId: String, status: UploadTaskStatus, progress: Int, tag: String? = nil, allowCellular: Bool = true) {
        self.taskId = taskId
        self.status = status
        self.progress = progress
        self.tag = tag
        self.allowCellular = allowCellular
    }
}
