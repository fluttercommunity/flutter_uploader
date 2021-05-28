//
//  AzureUploader.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 11/09/2020.
//

import Foundation

import AZSClient
import PromiseKit

enum AzureError: Error {
    case fileNotFound
    case fileCorrupted
    case cancelled
}

class AzureUploader {
    static let shared = AzureUploader()

    private static let blockSize: UInt64 = 1024 * 512
    //    private static let blockSize: UInt64 = 1024 * 1024 * 2

    private var activeTasks: [String] = []

    private var delegates: [UploaderDelegate] = []

    // MARK: Public API

    func addDelegate(_ delegate: UploaderDelegate) {
        delegates.append(delegate)
    }

    private var opContext: AZSOperationContext {
        let opContext = AZSOperationContext()
        opContext.logLevel = AZSLogLevel.debug
        return opContext
    }

    private var options: AZSBlobRequestOptions {
        return AZSBlobRequestOptions()
    }

    init() {
        delegates.append(EngineManager.shared)
        delegates.append(UploadResultDatabase.shared)
    }

    func upload(connectionString: String, container containerName: String, createContainer: Bool, blobName: String, path: String, completion: @escaping (String) -> Void) {
        let id: String = UUID().uuidString
        delegates.uploadEnqueued(taskId: id)

        activeTasks.append(id)

        completion(id)

        createBlobClient(connectionString: connectionString)
            .then { blobClient in return self.getContainer(blobClient, containerName, create: createContainer) }
            .then { self.createAppendBlob(container: $0, blobName) }
            .then { blob -> Promise<Void> in
                guard let handle = FileHandle(forReadingAtPath: path) else {
                    return Promise(error: AzureError.fileNotFound)
                }

                let contentLength = handle.seekToEndOfFile()

                let promises = Promise<Void>.chainSerially(
                    self.blocks(contentLength).map { block in
                        return { self.handleUpload(taskId: id, blob, handle, block) }
                    }
                )

                return promises.lastValue.done { (_) in
                    if #available(iOS 13.0, *) {
                        try handle.close()
                    } else {
                        handle.closeFile()
                    }
                }
            }
            .done {
                self.delegates.uploadCompleted(taskId: id, message: nil, statusCode: 200, headers: [:])
            }
            .catch { _ in
                if self.activeTasks.contains(id) {
                    self.delegates.uploadFailed(taskId: id, inStatus: .failed, statusCode: 500, errorCode: "", errorMessage: nil, errorStackTrace: [])
                } else {
                    self.delegates.uploadFailed(taskId: id, inStatus: .canceled, statusCode: 500, errorCode: "", errorMessage: nil, errorStackTrace: [])
                }
            }
    }

    func cancelWithTaskId(_ id: String) {
        if let index = activeTasks.firstIndex(of: id) {
            activeTasks.remove(at: index)
        }
    }

    func cancelAllTasks() {
        activeTasks.removeAll()
    }

    private func blocks(_ length: UInt64) -> [UInt64] {
        return (0 ... length / AzureUploader.blockSize).map { $0 * AzureUploader.blockSize }
    }

    private func handleUpload(taskId: String, _ appendBlob: AZSCloudAppendBlob, _ handle: FileHandle, _ start: UInt64) -> Promise<Void> {
        return Promise { seal in
            if !self.activeTasks.contains(taskId) {
                seal.reject(AzureError.cancelled)
                return
            }

            let contentLength = handle.seekToEndOfFile()

            if #available(iOS 13.0, *) {
                do {
                    try handle.seek(toOffset: start)
                } catch {
                    seal.reject(AzureError.fileCorrupted)
                    return
                }
            } else {
                handle.seek(toFileOffset: start)
                if handle.offsetInFile != start {
                    seal.reject(AzureError.fileCorrupted)
                    return
                }
            }

            let thisBlock = min(contentLength - start, AzureUploader.blockSize)

            if thisBlock > 0 {
                appendBlob.appendBlock(
                    with: handle.readData(ofLength: Int(thisBlock)),
                    contentMD5: nil,
                    accessCondition: AZSAccessCondition(),
                    requestOptions: options,
                    operationContext: opContext) { (error, _) in
                    if let error = error {
                        seal.reject(error)
                    } else {
                        let bytesWritten = start + thisBlock
                        let progress = (Double(bytesWritten) / Double(contentLength)) * 100

                        self.delegates.uploadProgressed(taskId: taskId, inStatus: .running, progress: Int(round(progress)))
                        seal.fulfill(Void())
                    }
                }
            } else {
                seal.fulfill(Void())
            }
        }
    }

    private func createBlobClient(connectionString: String) -> Promise<AZSCloudBlobClient> {
        return Promise { seal in
            let account = try AZSCloudStorageAccount(fromConnectionString: connectionString)
            seal.fulfill(account.getBlobClient())
        }
    }

    private func createAppendBlob(container: AZSCloudBlobContainer, _ name: String) -> Promise<AZSCloudAppendBlob> {
        return Promise { seal in
            let appendBlob = container.appendBlobReference(fromName: name)

            appendBlob.createIfNotExists(with: AZSAccessCondition(), requestOptions: options, operationContext: opContext) { (error, _) in
                if let error = error {
                    seal.reject(error)
                } else {
                    seal.fulfill(appendBlob)
                }
            }
        }
    }

    private func getContainer(_ blobClient: AZSCloudBlobClient, _ containerName: String, create: Bool) -> Promise<AZSCloudBlobContainer> {
        let container = blobClient.containerReference(fromName: containerName)

        if !create {
            return Promise.value(container)
        }

        return Promise { seal in
            container.createContainerIfNotExists(
                with: AZSContainerPublicAccessType.off,
                requestOptions: options,
                operationContext: opContext) { (error, _) in
                if let error = error {
                    seal.reject(error)
                } else {
                    seal.fulfill(container)
                }
            }
        }
    }
}
