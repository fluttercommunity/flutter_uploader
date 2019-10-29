import Flutter
import UIKit

public class SwiftFlutterUploaderPlugin: NSObject, FlutterPlugin, URLSessionTaskDelegate, URLSessionDataDelegate {

    let KEY_TASK_ID = "task_id"
    let KEY_STATUS = "status"
    let KEY_PROGRESS = "progress"
    let KEY_MAXIMUM_CONCURRENT_TASK = "FUMaximumConnectionsPerHost"
    let KEY_MAXIMUM_CONCURRENT_UPLOAD_OPERATION = "FUMaximumUploadOperation"
    static let KEY_TIMEOUT_IN_SECOND = "FUTimeoutInSeconds"
    let KEY_BACKGROUND_SESSION_IDENTIFIER = "chillisource.flutter_uploader.upload.background"
    let KEY_ALL_FILES_UPLOADED_MESSAGE = "FUAllFilesUploadedMessage"
    let KEY_FILE_NAME = "filename"
    let KEY_FIELD_NAME = "fieldname"
    let KEY_SAVED_DIR = "savedDir"
    let STEP_UPDATE = 0

    static let DEFAULT_TIMEOUT = 3600.0

    enum UploadTaskStatus: Int {
        case undefined = 0, enqueue, running, completed, failed, canceled, paused
    }

    let uploadFileSuffix = "--multi-part"

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
        var temporalFilePath: URL?

        init(fieldname: String, filename: String, savedDir: String, temporalFilePath: URL? = nil) {
            self.fieldname = fieldname
            self.filename = filename
            self.savedDir = savedDir
            self.path = "\(savedDir)/\(filename)"
            self.temporalFilePath = temporalFilePath
            let mime = MimeType(url: URL(fileURLWithPath: path))
            self.mimeType = mime.value
        }
    }

    var channel: FlutterMethodChannel
    var session: URLSession
    var queue: OperationQueue
    var taskQueue: DispatchQueue
    var runningTaskById = [String: UploadTask]()
    var boundary: String = ""
    let timeout: Double
    var allFileUploadedMessage = "All files have been uploaded"
    var backgroundTransferCompletionHander: Any?
    var uploadedData = [String: Data]()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_uploader", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterUploaderPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("methodCallHandler: \(call.method)")
        switch call.method {
        case "enqueue":
            enqueueMethodCall(call, result)
            break
        case "enqueueBinary":
            enqueueBinaryMethodCall(call, result)
            break
        case "cancel":
            cancelMethodCall(call, result)
            break
        case "cancelAll":
            cancelAllMethodCall(call, result)
            break
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
        NSLog("TIMEOUT = \(timeout)")

        super.init()

        self.setupSession()
    }

    private func setupSession() {

        let mainBundle = Bundle.main
        var maxConcurrentTasks: NSNumber
        if let concurrentTasks = mainBundle.object(forInfoDictionaryKey: KEY_MAXIMUM_CONCURRENT_TASK) {
            maxConcurrentTasks = concurrentTasks as! NSNumber
        } else {
            maxConcurrentTasks = NSNumber(integerLiteral: 3)
        }

        NSLog("MAXIMUM_CONCURRENT_TASKS = \(maxConcurrentTasks)")

        var maxUploadOperation: NSNumber
        if let operationTask = mainBundle.object(forInfoDictionaryKey: KEY_MAXIMUM_CONCURRENT_UPLOAD_OPERATION) {
            maxUploadOperation = operationTask as! NSNumber
        } else {
            maxUploadOperation = NSNumber(integerLiteral: 2)
        }

        NSLog("MAXIMUM_CONCURRENT_UPLOAD_OPERATION = \(maxUploadOperation)")

        if let message = mainBundle.object(forInfoDictionaryKey: KEY_ALL_FILES_UPLOADED_MESSAGE) {
            allFileUploadedMessage = message as! String
        }

        NSLog("AllFileUploadedMessage = \(allFileUploadedMessage)")

        self.queue.maxConcurrentOperationCount = maxUploadOperation.intValue

        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: KEY_BACKGROUND_SESSION_IDENTIFIER)
        sessionConfiguration.httpMaximumConnectionsPerHost = maxConcurrentTasks.intValue
        sessionConfiguration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: queue)
        NSLog("init NSURLSession with id: %@", session.configuration.identifier!)
        let boundaryId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.boundary = "---------------------------------\(boundaryId)"
    }

    private func enqueueMethodCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any?>
        let urlString = args["url"] as! String
        let method = args["method"] as! String
        let headers = args["headers"] as? Dictionary<String, Any?>
        let data = args["data"] as? Dictionary<String, Any?>
        let files = args["files"] as? Array<Any>
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

        uploadTaskWithURLWithCompletion(url: url, files: files!, method: method, headers: headers, parameters: data, tag: tag, completion: { [unowned self] (task, error) in
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
        let args = call.arguments as! Dictionary<String, Any?>
        let urlString = args["url"] as! String
        let method = args["method"] as! String
        let headers = args["headers"] as? Dictionary<String, Any?>
        let file = args["file"] as? Dictionary<String, Any?>
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

        let filename = f[KEY_FILE_NAME] as! String
        let fieldname = f[KEY_FIELD_NAME] as! String
        let savedDir = f[KEY_SAVED_DIR] as! String
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
        let args = call.arguments as! Dictionary<String, Any?>
        let taskId = args[KEY_TASK_ID] as! String
        self.cancelWithTaskId(taskId)
        result(nil)
    }

    private func cancelAllMethodCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        self.cancelAllTasks()
        result(nil)
    }

    private func cancelWithTaskId(_ taskId: String) {
        session.getTasksWithCompletionHandler { [unowned self] (_, uploadTasks, _) in
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
        session.getTasksWithCompletionHandler { [unowned self] (_, uploadTasks, _) in
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
                                                       headers: Dictionary<String, Any?>?,
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
        uploadTask.taskDescription = file.path
        uploadTask.resume()
        completionHandler(uploadTask, nil)
    }

    private func uploadTaskWithURLWithCompletion(url: URL, files: Array<Any>,
                                                 method: String,
                                                 headers: Dictionary<String, Any?>?,
                                                 parameters data: Dictionary<String, Any?>?,
                                                 tag: String?,
                                                 completion completionHandler:@escaping (URLSessionUploadTask?, FlutterError?) -> Void) {

        var itemsToUpload = Array<UploadFileInfo>()
        var flutterError: FlutterError?
        let fm = FileManager.default
        let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempDir = tempDirectory.appendingPathComponent("request_files", isDirectory: true)
        if !fm.fileExists(atPath: tempDir!.path) {
            do {
                try fm.createDirectory(at: tempDir!, withIntermediateDirectories: true, attributes: nil)
            } catch {
                completionHandler(nil, FlutterError(code: "io_error", message: "failed to create directory", details: nil))
                return
            }
        }

        var fileCount:Int = 0;
        
        for file in files {
            let f = file as! Dictionary<String, Any>
            let filename = f[KEY_FILE_NAME] as! String
            let fieldname = f[KEY_FIELD_NAME] as! String
            let savedDir = f[KEY_SAVED_DIR] as! String
            let info = UploadFileInfo(fieldname: fieldname, filename: filename, savedDir: savedDir)
            var isDir: ObjCBool = false

            let fm = FileManager.default
            if fm.fileExists(atPath: info.path, isDirectory:&isDir) {
                if !isDir.boolValue {
                    fileCount += 1
                    let fileId = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
                    let ext = NSURL(fileURLWithPath: info.path).pathExtension!
                    let filename = "\(fileId).\(ext)"
                    let tempPath = tempDir?.appendingPathComponent("\(filename)", isDirectory: false)
                    do {
                        try fm.copyItem(at: URL(fileURLWithPath: info.path), to: tempPath!)
                        let fileInfo = UploadFileInfo(fieldname: info.fieldname, filename: info.filename, savedDir: info.savedDir, temporalFilePath: tempPath)
                        itemsToUpload.append(fileInfo)
                        
                        if let temporalFilePath = fileInfo.temporalFilePath {
                            NSLog("File: \(temporalFilePath) with mimeType: \(fileInfo.mimeType)")
                        }
                    } catch {
                        fileCount -= 1;
                        NSLog("Failed to copy the file: \(info.path) to tempFile: \(tempPath!)")
                    }
                }
                else {
                    flutterError = FlutterError(code: "io_error", message: "path \(info.path) is a directory. please provide valid file path", details: nil);
                }
            }
            else {
                flutterError = FlutterError(code: "io_error", message: "file at path \(info.path) doesn't exists", details: nil);
            }
        }

        let tout: Int = Int(self.timeout)

        if fileCount <= 0 {
            completionHandler(nil, flutterError)
        } else {
            saveToFileWithCompletion(itemsToUpload, data, boundary, completion: {
                [weak self] (path, error) in

                if error != nil {
                    completionHandler(nil, error)
                    return
                }

                self?.makeRequest(path!, url, method, headers, boundary, tout, completion: {
                    (task, error) in
                    completionHandler(task, error)
                })
            })
        }
    }

    private func sendUpdateProgressForTaskId(_ taskId: String, inStatus status: UploadTaskStatus, andProgress progress: Int, andTag tag: String?) {
        self.channel.invokeMethod("updateProgress", arguments: [
            KEY_TASK_ID: taskId,
            KEY_STATUS: NSNumber(integerLiteral: status.rawValue),
            KEY_PROGRESS: NSNumber(integerLiteral: progress),
            "tag": (tag ?? NSNull()) as Any
            ])
    }

    private func sendUploadFailedForTaskId(_ taskId: String, inStatus status: UploadTaskStatus, statusCode: Int, error: FlutterError, tag: String?) {
        self.channel.invokeMethod("uploadFailed", arguments: [
            KEY_TASK_ID: taskId,
            KEY_STATUS: NSNumber(integerLiteral: status.rawValue),
            "code": error.code,
            "message": error.message ?? NSNull(),
            "details": error.details ?? NSNull(),
            "statusCode": NSNumber(integerLiteral: statusCode),
            "tag": tag as Any
            ])
    }

    private func sendUploadSuccessForTaskId(_ taskId: String, inStatus status: UploadTaskStatus, message: String?, statusCode: Int, headers: [String: Any], tag: String?) {
        self.channel.invokeMethod("uploadCompleted", arguments: [
            KEY_TASK_ID: taskId,
            KEY_STATUS: NSNumber(integerLiteral: status.rawValue),
            "message": message ?? NSNull(),
            "statusCode": statusCode,
            "headers": headers,
            "tag": tag ?? NSNull()
            ])
    }

    private func saveToFileWithCompletion(_ uploadItems: Array<UploadFileInfo>, _ parameters: Dictionary<String, Any?>?, _ boundary: String,
                                          completion completionHandler: (String?, FlutterError?) -> Void) {

        taskQueue.sync {
            var dataRequest = ""
            if(parameters != nil) {
                parameters?.forEach({ (key, value) in
                    if let v = value as? String {
                        dataRequest += "--\(boundary)\r\n"
                        dataRequest += "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
                        dataRequest += "\(v)\r\n"
                    }
                })
            }

            let fm = FileManager.default
            let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
            let requestFile = "\(requestId).req"
            let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let tempDir = tempDirectory.appendingPathComponent("requests", isDirectory: true)
            if !fm.fileExists(atPath: tempDir!.path) {
                do {
                    try fm.createDirectory(at: tempDir!, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    completionHandler(nil, FlutterError(code: "io_error", message: "failed to create directory", details: nil))
                    return
                }
            }

            let tempPath = tempDir?.appendingPathComponent(requestFile, isDirectory: false)

            if fm.fileExists(atPath: tempPath!.path) {
                do {
                    try fm.removeItem(at: tempPath!)
                } catch {
                    completionHandler(nil, FlutterError(code: "io_error", message: "failed to delete file \(requestFile)", details: nil))
                    return
                }
            }

            do {

                try dataRequest.write(toFile: tempPath!.path, atomically: true, encoding: String.Encoding.utf8)

                let stream = FileHandle(forWritingAtPath: tempPath!.path)
                defer {
                    stream?.closeFile()
                }

                stream?.seekToEndOfFile()

                uploadItems.forEach({ info in
                    var fileRequest = ""
                    fileRequest += "--\(boundary)\r\n"
                    fileRequest += "Content-Disposition: form-data; name=\"\(info.fieldname)\"; filename=\"\(info.filename)\"\r\n"
                    fileRequest += "Content-Type: \(info.mimeType)\r\n\r\n"
                    stream?.write(fileRequest.data(using: String.Encoding.utf8)!)

                    NSLog("attaching the file: \(info.path) - tempPath:\(info.temporalFilePath?.path ?? "na")")

                    if info.temporalFilePath != nil && fm.fileExists(atPath: info.temporalFilePath!.path) {
                        stream?.write(fm.contents(atPath: info.temporalFilePath!.path)!)
                    } else if (fm.fileExists(atPath: info.path)) {
                        stream?.write(fm.contents(atPath: info.path)!)
                    }

                    stream?.write("\r\n".data(using: String.Encoding.utf8)!)

                    if info.temporalFilePath != nil {
                        do {
                            try fm.removeItem(at: info.temporalFilePath!)
                        } catch {

                        }
                    }

                    stream?.write("\r\n--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
                })

                stream?.closeFile()

                completionHandler(tempPath!.path, nil)
            } catch {
                completionHandler(nil, FlutterError(code: "io_error", message: "failed to write request", details: nil))
                return
            }

        }
    }

    private func makeRequest(_ path: String, _ url: URL, _ method: String, _ headers: Dictionary<String, Any?>?, _ boundary: String, _ timeout: Int, completion completionHandler: (URLSessionUploadTask?, FlutterError?) -> Void) {

        let request = NSMutableURLRequest(url: url)
        request.httpMethod = method
        request.addValue("*/*", forHTTPHeaderField: "Accept")
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

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
        uploadTask.taskDescription = path
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
                break
            default:
                uploadStatus = .failed
                break
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

        let path = uploadTask.taskDescription

        if path != nil && FileManager.default.fileExists(atPath: path!) {
            do {
                try FileManager.default.removeItem(atPath: path!)
            } catch {
                NSLog("URLSessionDidCompleteWithError: Failed to delete file in path \(path!)")
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
    
    private func isRequestSuccessful(_ statusCode:Int) -> Bool {
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

                if isRunning(Int(progress), runningTask!.progress, STEP_UPDATE) {
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
                        [unowned self] in
                        completionHandler()

                        let localNotification = UILocalNotification()
                        localNotification.alertBody = self.allFileUploadedMessage
                        UIApplication.shared.presentLocalNotificationNow(localNotification)
                    })
                }
            }
        }
    }

    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        NSLog("ApplicationHandleEventsForBackgroundURLSession: \(identifier)")
        if identifier == KEY_BACKGROUND_SESSION_IDENTIFIER {
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
