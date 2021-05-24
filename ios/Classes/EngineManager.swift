//
//  EngineManager.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

class EngineManager {
    private var headlessRunner: FlutterEngine?
    public var registerPlugins: FlutterPluginRegistrantCallback?

    private let semaphore = DispatchSemaphore(value: 1)

    private func startEngineIfNeeded() {
        semaphore.wait()

        defer {
            semaphore.signal()
        }

        guard let callbackHandle = UploaderDefaults.shared.callbackHandle else {
            if let runner = headlessRunner {
                runner.destroyContext()
                headlessRunner = nil
            }
            return
        }

        // Already started
        if headlessRunner != nil {
            return
        }

        headlessRunner = FlutterEngine(name: "FlutterUploaderIsolate", project: nil, allowHeadlessExecution: true)

        guard let info = FlutterCallbackCache.lookupCallbackInformation(Int64(callbackHandle)) else {
            fatalError("Can not find callback")
        }

        let entryPoint = info.callbackName
        let uri = info.callbackLibraryPath

        DispatchQueue.main.async {
            self.headlessRunner?.run(withEntrypoint: entryPoint, libraryURI: uri)
            if let registerPlugins = SwiftFlutterUploaderPlugin.registerPlugins, let runner = self.headlessRunner {
                registerPlugins(runner)
            } else {
                self.headlessRunner = nil
            }
        }
    }
}

extension EngineManager: UploaderDelegate {
    func uploadEnqueued(taskId: String) {
    }

    func uploadProgressed(taskId: String, inStatus: UploadTaskStatus, progress: Int) {
        startEngineIfNeeded()
    }

    func uploadCompleted(taskId: String, message: String?, statusCode: Int, headers: [String: Any]) {
        startEngineIfNeeded()
    }

    func uploadFailed(taskId: String, inStatus: UploadTaskStatus, statusCode: Int, errorCode: String, errorMessage: String?, errorStackTrace: [String]) {
        startEngineIfNeeded()
    }
}
