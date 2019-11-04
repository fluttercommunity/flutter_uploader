import Flutter
import UIKit
import Alamofire

public class SwiftFlutterUploaderPlugin: NSObject, FlutterPlugin, URLSessionTaskDelegate, URLSessionDataDelegate {

    static let KEY_TASK_ID = "task_id"
    static let KEY_STATUS = "status"
    static let KEY_PROGRESS = "progress"
    static let KEY_MAXIMUM_CONCURRENT_TASK = "FUMaximumConnectionsPerHost"
    static let KEY_MAXIMUM_CONCURRENT_UPLOAD_OPERATION = "FUMaximumUploadOperation"
    static let KEY_TIMEOUT_IN_SECOND = "FUTimeoutInSeconds"
    static let KEY_BACKGROUND_SESSION_IDENTIFIER = "chillisource.flutter_uploader.upload.background"
    static let KEY_ALL_FILES_UPLOADED_MESSAGE = "FUAllFilesUploadedMessage"
    static let KEY_FILE_NAME = "filename"
    static let KEY_FIELD_NAME = "fieldname"
    static let KEY_SAVED_DIR = "savedDir"
    static let STEP_UPDATE = 0
    static let DEFAULT_TIMEOUT = 3600.0

    enum UploadTaskStatus: Int {
        case undefined = 0, enqueue, running, completed, failed, canceled, paused
    }

    struct UploadTask {
        var taskId: String
        var status: UploadTaskStatus
        var progress: Int
        var tag: String?

        init(taskId: String, status: UploadTaskStatus, progress: Int, tag: String?) {
            self.taskId = taskId
            self.status = status
            self.progress = progress
            self.tag = tag
        }
    }

    struct UploadFileInfo {

        var fieldname: String
        var filename: String
        var savedDir: String
        var mimeType: String
        var path: String
       
        init(fieldname: String, filename: String, savedDir: String) {
            self.fieldname = fieldname
            self.filename = filename
            self.savedDir = savedDir
            self.path = "\(savedDir)/\(filename)"
            let mime = MimeType(url: URL(fileURLWithPath: path))
            self.mimeType = mime.value
        }
    }

    let channel: FlutterMethodChannel
    var session: URLSession
    let queue: OperationQueue
    let taskQueue: DispatchQueue
    let timeout: Double
    var allFileUploadedMessage = "All files have been uploaded"
    var backgroundTransferCompletionHander: Any?
    var uploadedData = [String: Data]()
    var runningTaskById = [String: UploadTask]()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_uploader", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterUploaderPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enqueue":
            enqueueMethodCall(call, result)
        case "enqueueBinary":
            enqueueBinaryMethodCall(call, result)
        case "cancel":
            cancelMethodCall(call, result)
        case "cancelAll":
            cancelAllMethodCall(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        self.queue = OperationQueue()
        self.queue.name = "chillisource.flutter_uploader.queue"
        self.session = URLSession()
        self.taskQueue = DispatchQueue(label: "chillisource.flutter_uploader.dispatch.queue")
        self.timeout = SwiftFlutterUploaderPlugin.determineTimeout()
        super.init()
        self.setupSession()
    }

    private func setupSession() {

        let mainBundle = Bundle.main
        var maxConcurrentTasks: NSNumber
        if let concurrentTasks = mainBundle.object(forInfoDictionaryKey: SwiftFlutterUploaderPlugin.KEY_MAXIMUM_CONCURRENT_TASK) {
            maxConcurrentTasks = concurrentTasks as! NSNumber
        } else {
            maxConcurrentTasks = NSNumber(integerLiteral: 3)
        }

        NSLog("MAXIMUM_CONCURRENT_TASKS = \(maxConcurrentTasks)")

        var maxUploadOperation: NSNumber
        if let operationTask = mainBundle.object(forInfoDictionaryKey: SwiftFlutterUploaderPlugin.KEY_MAXIMUM_CONCURRENT_UPLOAD_OPERATION) {
            maxUploadOperation = operationTask as! NSNumber
        } else {
            maxUploadOperation = NSNumber(integerLiteral: 2)
        }

        NSLog("MAXIMUM_CONCURRENT_UPLOAD_OPERATION = \(maxUploadOperation)")

        if let message = mainBundle.object(forInfoDictionaryKey: SwiftFlutterUploaderPlugin.KEY_ALL_FILES_UPLOADED_MESSAGE) {
            allFileUploadedMessage = message as! String
        }

        NSLog("AllFileUploadedMessage = \(allFileUploadedMessage)")

        self.queue.maxConcurrentOperationCount = maxUploadOperation.intValue

        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: SwiftFlutterUploaderPlugin.KEY_BACKGROUND_SESSION_IDENTIFIER)
        sessionConfiguration.httpMaximumConnectionsPerHost = maxConcurrentTasks.intValue
        sessionConfiguration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: queue)
    }

    private func enqueueMethodCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any?]
        let urlString = args["url"] as! String
        let method = args["method"] as! String
        let headers = args["headers"] as? [String: Any?]
        let data = args["data"] as? [String: Any?]
        let files = args["files"] as? [Any]
        let tag = args["tag"] as? String

        let validHttpMethods = ["POST", "PUT", "PATCH"]
        let httpMethod = method.uppercased()

        if (!validHttpMethods.contains(httpMethod)) {
            result(FlutterError(code: "invalid_method", message: "Method must be either POST | PUT | PATCH", details: nil))
            return
        }

        if files == nil || files!.count <= 0 {
            result(FlutterError(code: "invalid_files", message: "There are no items to upload", details: nil))
            return
        }

        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "invalid_url", message: "url is not a valid url", details: nil))
            return
        }

        uploadTaskWithURLWithCompletion(url: url, files: files!, method: method, headers: headers, parameters: data, tag: tag, completion: { (task, error) in
            if (error != nil) {
                result(error!)
            } else {
                let uploadTask = task!
                let taskId = self.identifierForTask(uploadTask)
                self.runningTaskById[taskId] = UploadTask(taskId: taskId, status: .enqueue, progress: 0, tag: tag)
                result(taskId)
                self.sendUpdateProgressForTaskId(taskId, inStatus: .enqueue, andProgress: 0, andTag: tag)
            }
        })
    }

    private func enqueueBinaryMethodCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any?]
        let urlString = args["url"] as! String
        let method = args["method"] as! String
        let headers = args["headers"] as? [String: Any?]
        let file = args["file"] as? [String: Any?]
        let tag = args["tag"] as? String

        let validHttpMethods = ["POST", "PUT", "PATCH"]
        let httpMethod = method.uppercased()

        if (!validHttpMethods.contains(httpMethod)) {
            result(FlutterError(code: "invalid_method", message: "Method must be either POST | PUT | PATCH", details: nil))
            return
        }

        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "invalid_url", message: "url is not a valid url", details: nil))
            return
        }

        guard let f = file else {
            result(FlutterError(code: "invalid_file", message: "file is not a valid path", details: nil))
            return
        }

        let filename = f[SwiftFlutterUploaderPlugin.KEY_FILE_NAME] as! String
        let fieldname = f[SwiftFlutterUploaderPlugin.KEY_FIELD_NAME] as! String
        let savedDir = f[SwiftFlutterUploaderPlugin.KEY_SAVED_DIR] as! String
        let info = UploadFileInfo(fieldname: fieldname, filename: filename, savedDir: savedDir)

        let fileUrl = URL(fileURLWithPath: info.path)

        guard FileManager.default.fileExists(atPath: info.path) else {
            result(FlutterError(code: "invalid_file", message: "file does not exist", details: nil))
            return
        }

        binaryUploadTaskWithURLWithCompletion(url: url, file: fileUrl, method: method, headers: headers, tag: tag, completion: { (task, error) in
            if (error != nil) {
                result(error!)
            } else {
                let uploadTask = task!
                let taskId = self.identifierForTask(uploadTask)
                self.runningTaskById[taskId] = UploadTask(taskId: taskId, status: .enqueue, progress: 0, tag: tag)
                result(taskId)
                self.sendUpdateProgressForTaskId(taskId, inStatus: .enqueue, andProgress: 0, andTag: tag)
            }
        })
    }

    private func cancelMethodCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any?]
        let taskId = args[SwiftFlutterUploaderPlugin.KEY_TASK_ID] as! String
        self.cancelWithTaskId(taskId)
        result(nil)
    }

    private func cancelAllMethodCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.cancelAllTasks()
        result(nil)
    }

    private func cancelWithTaskId(_ taskId: String) {
        session.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            uploadTasks.forEach({ (uploadTask) in
                let state = uploadTask.state
                let taskIdValue = self.identifierForTask(uploadTask)
                if taskIdValue == taskId && state == .running {
                    uploadTask.cancel()
                    self.sendUpdateProgressForTaskId(taskId, inStatus: .canceled, andProgress: -1, andTag: nil)
                    return
                }
            })
        }
    }

    private func cancelAllTasks() {
        session.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            uploadTasks.forEach({ (uploadTask) in
                let state = uploadTask.state
                let taskId = self.identifierForTask(uploadTask)
                if state == .running {
                    uploadTask.cancel()
                    self.sendUpdateProgressForTaskId(taskId, inStatus: .canceled, andProgress: -1, andTag: nil)
                }
            })
        }
    }

    private func identifierForTask(_ task: URLSessionUploadTask) -> String {
        return "\(self.session.configuration.identifier ?? "chillisoure.flutter_uploader").\(task.taskIdentifier)"
    }

    private func identifierForTask(_ task: URLSessionUploadTask, withSession session: URLSession) -> String {
        return "\(session.configuration.identifier ?? "chillisoure.flutter_uploader").\(task.taskIdentifier)"
    }

    private func binaryUploadTaskWithURLWithCompletion(url: URL,
                                                       file: URL,
                                                       method: String,
                                                       headers: [String: Any?]?,
                                                       tag: String?,
                                                       completion completionHandler:@escaping (URLSessionUploadTask?, FlutterError?) -> Void) {
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = method
        request.addValue("*/*", forHTTPHeaderField: "Accept")

        headers?.forEach { (key, value) in
            if let v = value as? String {
                request.addValue(v, forHTTPHeaderField: key)
            }
        }

        request.timeoutInterval = self.timeout

        let uploadTask = self.session.uploadTask(with: request as URLRequest, fromFile: URL(fileURLWithPath: file.path))
        uploadTask.taskDescription = "\(file.path),KEEP"
        uploadTask.resume()
        completionHandler(uploadTask, nil)
    }

    private func uploadTaskWithURLWithCompletion(url: URL, files: [Any],
                                                 method: String,
                                                 headers: [String: Any?]?,
                                                 parameters data: [String: Any?]?,
                                                 tag: String?,
                                                 completion completionHandler:@escaping (URLSessionUploadTask?, FlutterError?) -> Void) {

            var flutterError: FlutterError?
            let fm = FileManager.default
            var fileCount: Int = 0
            let formData = MultipartFormData()
            let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

            if(data != nil) {
                data?.forEach({ (key, value) in
                    if let v = value as? String {
                        formData.append(v.data(using: .utf8)!, withName: key)
                    }
                })
            }

            for file in files {
                let f = file as! [String: Any]
                let filename = f[SwiftFlutterUploaderPlugin.KEY_FILE_NAME] as! String
                let fieldname = f[SwiftFlutterUploaderPlugin.KEY_FIELD_NAME] as! String
                let savedDir = f[SwiftFlutterUploaderPlugin.KEY_SAVED_DIR] as! String
                var isDir: ObjCBool = false
                let path = "\(savedDir)/\(filename)"
                let fm = FileManager.default
                if fm.fileExists(atPath: path, isDirectory: &isDir) {
                    if !isDir.boolValue {
                        let fileInfo = UploadFileInfo(fieldname: fieldname, filename: filename, savedDir: savedDir)
                        let filePath = URL(fileURLWithPath: fileInfo.path)
                        formData.append(filePath, withName: fileInfo.fieldname, fileName: fileInfo.filename, mimeType: fileInfo.mimeType)
                        fileCount += 1
                    } else {
                        flutterError = FlutterError(code: "io_error", message: "path \(path) is a directory. please provide valid file path", details: nil)
                    }
                } else {
                    flutterError = FlutterError(code: "io_error", message: "file at path \(path) doesn't exists", details: nil)
                }
            }

            let tout: Int = Int(self.timeout)

            if fileCount <= 0 {
                completionHandler(nil, flutterError)
            } else {
                let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
                let requestFile = "\(requestId).req"
                let tempPath = tempDirectory.appendingPathComponent(requestFile, isDirectory: false)

                if fm.fileExists(atPath: tempPath!.path) {
                    do {
                        try fm.removeItem(at: tempPath!)
                    } catch {
                        completionHandler(nil, FlutterError(code: "io_error", message: "failed to delete file \(requestFile)", details: nil))
                        return
                    }
                }

                let path = tempPath!.path
                do {
                    let requestfileURL = URL(fileURLWithPath: path)
                    try formData.writeEncodedData(to: requestfileURL)
                } catch {
                    completionHandler(nil, FlutterError(code: "io_error", message: "failed to write request \(requestFile)", details: nil))
                    return
                }

                self.makeRequest(path, url, method, headers, formData.contentType, formData.contentLength, tout, completion: {
                    (task, error) in
                    completionHandler(task, error)
                })
            }
    }

    private func sendUpdateProgressForTaskId(_ taskId: String, inStatus status: UploadTaskStatus, andProgress progress: Int, andTag tag: String?) {
        self.channel.invokeMethod("updateProgress", arguments: [
            SwiftFlutterUploaderPlugin.KEY_TASK_ID: taskId,
            SwiftFlutterUploaderPlugin.KEY_STATUS: NSNumber(integerLiteral: status.rawValue),
            SwiftFlutterUploaderPlugin.KEY_PROGRESS: NSNumber(integerLiteral: progress),
            "tag": (tag ?? NSNull()) as Any
        ])
    }

    private func sendUploadFailedForTaskId(_ taskId: String, inStatus status: UploadTaskStatus, statusCode: Int, error: FlutterError, tag: String?) {
        self.channel.invokeMethod("uploadFailed", arguments: [
            SwiftFlutterUploaderPlugin.KEY_TASK_ID: taskId,
            SwiftFlutterUploaderPlugin.KEY_STATUS: NSNumber(integerLiteral: status.rawValue),
            "code": error.code,
            "message": error.message ?? NSNull(),
            "details": error.details ?? NSNull(),
            "statusCode": NSNumber(integerLiteral: statusCode),
            "tag": tag as Any
        ])
    }

    private func sendUploadSuccessForTaskId(_ taskId: String, inStatus status: UploadTaskStatus, message: String?, statusCode: Int, headers: [String: Any], tag: String?) {
        self.channel.invokeMethod("uploadCompleted", arguments: [
            SwiftFlutterUploaderPlugin.KEY_TASK_ID: taskId,
            SwiftFlutterUploaderPlugin.KEY_STATUS: NSNumber(integerLiteral: status.rawValue),
            "message": message ?? NSNull(),
            "statusCode": statusCode,
            "headers": headers,
            "tag": tag ?? NSNull()
        ])
    }

    private func makeRequest(_ path: String, _ url: URL, _ method: String, _ headers: [String: Any?]?, _ contentType: String, _ contentLength: UInt64, _ timeout: Int, completion completionHandler: (URLSessionUploadTask?, FlutterError?) -> Void) {

        let request = NSMutableURLRequest(url: url)
        request.httpMethod = method
        request.addValue("*/*", forHTTPHeaderField: "Accept")
        request.addValue("\(contentType)", forHTTPHeaderField: "Content-Type")
        request.addValue("\(contentLength)", forHTTPHeaderField: "Content-Length")

        if headers != nil {
            headers!.forEach { (key, value) in
                if let v = value as? String {
                    request.addValue(v, forHTTPHeaderField: key)
                }
            }
        }

        request.timeoutInterval = Double(timeout)

        let fm = FileManager.default

        if !fm.fileExists(atPath: path) {
            completionHandler(nil, FlutterError(code: "io_error", message: "request file can not be found in path \(path)", details: nil))
            return
        }

        let uploadTask = self.session.uploadTask(with: request as URLRequest, fromFile: URL(fileURLWithPath: path))
        uploadTask.taskDescription = "\(path),DELETE"
        uploadTask.resume()
        completionHandler(uploadTask, nil)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        guard let uploadTask = task as? URLSessionUploadTask else {
            NSLog("URLSessionDidCompleteWithError: not an uplaod task")
            return
        }

        let taskId = identifierForTask(uploadTask, withSession: session)
        let runningTask = self.runningTaskById[taskId]
        let tag = runningTask?.tag

        if error != nil {
            NSLog("URLSessionDidCompleteWithError: \(taskId) failed with \(error!.localizedDescription)")
            var uploadStatus: UploadTaskStatus = .failed
            switch error! {
            case URLError.cancelled:
                uploadStatus = .canceled
            default:
                uploadStatus = .failed
            }

            self.sendUploadFailedForTaskId(taskId, inStatus: uploadStatus, statusCode: 500, error: FlutterError(code: "upload_error", message: error?.localizedDescription, details: Thread.callStackSymbols), tag: tag)
            self.runningTaskById.removeValue(forKey: taskId)
            self.uploadedData.removeValue(forKey: taskId)
            return
        }

        var hasResponseError = false
        var response: HTTPURLResponse?
        var statusCode = 500

        if task.response is HTTPURLResponse {
            response = task.response as? HTTPURLResponse

            if response != nil {
                NSLog("URLSessionDidCompleteWithError: \(taskId) with response: \(response!) and status: \(response!.statusCode)")
                statusCode = response!.statusCode
                hasResponseError = !isRequestSuccessful(response!.statusCode)
            }
        }

        NSLog("URLSessionDidCompleteWithError: upload completed")

        if let pathDescription = uploadTask.taskDescription {
            let split = pathDescription.split(separator: ",")

            if split.count == 2 {
                let path = String(split[0])
                if split[1] == "DELETE" && FileManager.default.fileExists(atPath: path) {
                    do {
                        try FileManager.default.removeItem(atPath: path)
                    } catch {
                        NSLog("URLSessionDidCompleteWithError: Failed to delete file in path \(path)")
                    }
                }
            }
        }

        let headers = response?.allHeaderFields
        var responseHeaders = [String: Any]()
        if headers != nil {
            headers!.forEach { (key, value) in
                if let k = key as? String {
                    responseHeaders[k] = value
                }
            }
        }

        var data: Data = Data()

        if uploadedData.contains(where: { (key, _) in
            return key == taskId
        }) {
            let d = uploadedData[taskId]
            if d != nil {
                data = d!
            }
        }

        self.uploadedData.removeValue(forKey: taskId)
        self.runningTaskById.removeValue(forKey: taskId)

        let dataString = String(data: data, encoding: String.Encoding.utf8)
        let message = dataString == nil ? "" : dataString!
        if error == nil && !hasResponseError {
            NSLog("URLSessionDidCompleteWithError: response: \(message), task: \(getTaskStatusText(uploadTask.state))")
            self.sendUploadSuccessForTaskId(taskId, inStatus: .completed, message: message, statusCode: response?.statusCode ?? 200, headers: responseHeaders, tag: tag)
        } else if hasResponseError {
            NSLog("URLSessionDidCompleteWithError: task: \(getTaskStatusText(uploadTask.state)) statusCode: \(response?.statusCode ?? -1), error:\(message), response:\(String(describing: response))")
            self.sendUploadFailedForTaskId(taskId, inStatus: .failed, statusCode: statusCode, error: FlutterError(code: "upload_error", message: message, details: Thread.callStackSymbols), tag: tag)
        } else {
            NSLog("URLSessionDidCompleteWithError: task: \(getTaskStatusText(uploadTask.state)) statusCode: \(response?.statusCode ?? -1), error:\(error?.localizedDescription ?? "none")")
            self.sendUploadFailedForTaskId(taskId, inStatus: .failed, statusCode: statusCode, error: FlutterError(code: "upload_error", message: error?.localizedDescription, details: Thread.callStackSymbols), tag: tag)
        }
    }

    private func getTaskStatusText(_ state: URLSessionTask.State) -> String {
        switch(state) {
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

    private func isRequestSuccessful(_ statusCode: Int) -> Bool {
        return statusCode >= 200 && statusCode <= 299
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("URLSessionDidReceiveData:")

        guard let uploadTask = dataTask as? URLSessionUploadTask else {
            NSLog("URLSessionDidReceiveData: not an uplaod task")
            return
        }
        let taskId = identifierForTask(uploadTask, withSession: session)

        if uploadedData.contains(where: { (key, _) in
            return key == taskId
        }) {
            NSLog("URLSessionDidReceiveData: existing data with \(taskId)")
            if data.count > 0 {
                self.uploadedData[taskId]?.append(data)
            }
        } else {
            var udata = Data()
            if(data.count > 0) {
                udata.append(data)
            }

            self.uploadedData[taskId] = udata
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        NSLog("URLSessionDidReceiveResponse - url:\(String(describing: response.url)), mimeType:\(response.mimeType ?? "na"), expectedContentLength:\(response.expectedContentLength), suggestedFilename:\(response.suggestedFilename ?? "na")")
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        NSLog("URLSessionDidBecomeInvalidWithError:")
    }

    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        NSLog("URLSessionTaskIsWaitingForConnectivity:")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {

        if totalBytesExpectedToSend == NSURLSessionTransferSizeUnknown {
            NSLog("Unknown transfer size")
        } else {
            guard let uploadTask = task as? URLSessionUploadTask else {
                NSLog("URLSessionDidSendBodyData: an not uplaod task")
                return
            }

            let taskId = identifierForTask(uploadTask, withSession: session)
            let bytesExpectedToSend = Double(integerLiteral: totalBytesExpectedToSend)
            let tBytesSent = Double(integerLiteral: totalBytesSent)
            let progress = round(Double(tBytesSent / bytesExpectedToSend * 100))
            let runningTask = self.runningTaskById[taskId]
            NSLog("URLSessionDidSendBodyData: taskId: \(taskId), byteSent: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSend: \(totalBytesExpectedToSend), progress:\(progress)")

            if runningTask != nil {
                let isRunning: (Int, Int, Int) -> Bool = {
                    (current, previous, step) in
                    let prev = previous + step
                    return (current == 0 || current > prev || current >= 100) &&  current != previous
                }

                if isRunning(Int(progress), runningTask!.progress, SwiftFlutterUploaderPlugin.STEP_UPDATE) {
                    self.sendUpdateProgressForTaskId(taskId, inStatus: .running, andProgress: Int(progress), andTag: runningTask?.tag)
                    self.runningTaskById[taskId] = UploadTask(taskId: taskId, status: .running, progress: Int(progress), tag: runningTask?.tag)
                }
            }
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        NSLog("URLSessionDidFinishEvents:")
        session.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            if( uploadTasks.count == 0) {
                NSLog("all upload tasks have been completed")

                if(self.backgroundTransferCompletionHander != nil) {
                    let completionHandler = self.backgroundTransferCompletionHander as! () -> Void

                    self.backgroundTransferCompletionHander = nil

                    OperationQueue.main.addOperation({
                        [weak self] in
                        completionHandler()

                        let localNotification = UILocalNotification()
                        localNotification.alertBody = self?.allFileUploadedMessage
                        UIApplication.shared.presentLocalNotificationNow(localNotification)
                    })
                }
            }
        }
    }

    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        NSLog("ApplicationHandleEventsForBackgroundURLSession: \(identifier)")
        if identifier == SwiftFlutterUploaderPlugin.KEY_BACKGROUND_SESSION_IDENTIFIER {
            self.backgroundTransferCompletionHander = completionHandler
        }
        return true
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        runningTaskById.removeAll()
        uploadedData.removeAll()
        queue.cancelAllOperations()
    }

    private static func determineTimeout() -> Double {
        if let timeoutSetting = Bundle.main.object(forInfoDictionaryKey: KEY_TIMEOUT_IN_SECOND) {
            return (timeoutSetting as! NSNumber).doubleValue
        } else {
            return SwiftFlutterUploaderPlugin.DEFAULT_TIMEOUT
        }
    }
}
