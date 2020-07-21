//
//  SimpleStreamHandler.swift
//  flutter_uploader
//
//  Created by Sebastian Roth on 21/07/2020.
//

import Foundation

class SimpleStreamHandler : NSObject, FlutterStreamHandler {
    var cache: [Any?] = []
    
    var eventSink: FlutterEventSink? = nil
    
    func add(_ value: Any?) {
        guard let sink = eventSink else {
            cache.append(value)
            return
        }
        
        sink(value)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if !cache.isEmpty {
            for value in cache {
                events(value)
            }
            cache.removeAll()
        }
        
        self.eventSink = events
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        
        return nil
    }
}
