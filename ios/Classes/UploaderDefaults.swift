//
//  UploaderDefaults.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

class UploaderDefaults: NSObject {
    static let shared = UploaderDefaults()

    private static let prefCallbackHandle = "flutter_uploader.callbackHandle"

    var callbackHandle: Int? {
        get {
            if UserDefaults.standard.value(forKey: UploaderDefaults.prefCallbackHandle) != nil {
                return UserDefaults.standard.integer(forKey: UploaderDefaults.prefCallbackHandle)
            } else {
                return nil
            }
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: UploaderDefaults.prefCallbackHandle)
            } else {
                UserDefaults.standard.removeObject(forKey: UploaderDefaults.prefCallbackHandle)
            }
        }
    }

    private override init() {
    }
}
