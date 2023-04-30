//
//  SimpleStreamHandler.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

class CachingStreamHandler<T>: NSObject, FlutterStreamHandler {
    var cache: [String: T] = [:]

    var eventSink: FlutterEventSink?

    private let cacheSemaphore = DispatchSemaphore(value: 1)

    func add(_ taskId: String, _ value: T) {
        if let sink = eventSink {
            sink(value)
        } else {
            cacheSemaphore.wait()
            cache[taskId] = value
            cacheSemaphore.signal()
        }
    }

    func clear() {
        cacheSemaphore.wait()
        cache.removeAll()
        cacheSemaphore.signal()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        cacheSemaphore.wait()
        for cacheEntry in cache {
            events(cacheEntry.value)
        }
        cache = [:]
        cacheSemaphore.signal()

        self.eventSink = events

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil

        return nil
    }
}
