//
//  SimpleStreamHandler.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

class CachingStreamHandler<T>: NSObject, FlutterStreamHandler {
    var cache: [String:T] = [:]

    var eventSink: FlutterEventSink?

    func add(_ id: String, _ value: T) {
        cache[id] = value
        
        if let sink = eventSink {
            sink(value)
        }
    }
    
    func clear() {
        cache.removeAll()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        for cacheEntry in cache {
            events(cacheEntry.value)
        }

        self.eventSink = events

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil

        return nil
    }
}
