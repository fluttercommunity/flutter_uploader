//
//  UploadFileInfo.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

struct UploadFileInfo {
    let fieldname: String
    let path: String
    let mimeType: String

    init(fieldname: String, path: String) {
        self.fieldname = fieldname
        self.path = path
        let mime = MimeType(url: URL(fileURLWithPath: path))
        self.mimeType = mime.value
    }
}
