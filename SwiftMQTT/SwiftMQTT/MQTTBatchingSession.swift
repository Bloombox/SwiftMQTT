//
//  MQTTBatchingSession.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/20/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

public protocol MQTTBatchingSessionDelegate: class {
    func mqttDidReceive(messages: [MQTTMessage], from session: MQTTBatchingSession)
    func mqttConnectionFailed(session: MQTTBatchingSession, error: Error?)
    func mqttErrorOccurred(session: MQTTBatchingSession, error: Error?)
}

public struct MQTTConnectParams {
    public var host: String = "localhost"
    public var port: UInt16 = 1883
    public var clientID: String = ""
    public var cleanSession: Bool = true
    public var keepAlive: UInt16 = 15
    public var useSSL: Bool = false
    public var queueName: String
    public var retryCount: Int = 3
    public var retryTimeInterval: TimeInterval = 1.0
}

public extension MQTTSession {
    public convenience init(connectParams: MQTTConnectParams) {
        self.init(host: connectParams.host, port: connectParams.port, clientID: connectParams.clientID, cleanSession: connectParams.cleanSession, keepAlive: connectParams.keepAlive, useSSL: connectParams.useSSL)
    }
}

/*
    TODO: reconnects with retries
    TODO: batch sends
*/

public class MQTTBatchingSession: MQTTBroker {
	fileprivate var sessionQueue: DispatchQueue
    fileprivate let connectParams: MQTTConnectParams
    fileprivate let session: MQTTSession
    fileprivate let batchPredicate: ([MQTTMessage])->Bool
    
    open weak var delegate: MQTTBatchingSessionDelegate?
    
    public init(connectParams: MQTTConnectParams, batchPredicate: @escaping ([MQTTMessage])->Bool) {
        self.batchPredicate = batchPredicate
        self.sessionQueue = DispatchQueue(label: connectParams.queueName + ".session", qos: .background, target: nil)
        self.connectParams = connectParams
        self.session = MQTTSession(connectParams: connectParams)
        self.session.delegate = self
    }
    
    public func connect(completion: MQTTSessionCompletionBlock? = nil) {
        sessionQueue.async { [weak self] in
			let currentRunLoop = RunLoop.current
			self?.session.connect(completion: completion)
			currentRunLoop.run()
        }
    }
    
    public func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
        self.session.publish(data, in: topic, delivering: qos, retain: retain, completion: completion)
    }
    
    public func subscribe(to topics: [String: MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        self.session.subscribe(to: topics, completion: completion)
    }
    
    public func unSubscribe(from topics: [String], completion: MQTTSessionCompletionBlock?) {
        self.session.unSubscribe(from: topics, completion: completion)
    }
    
    public func disconnect() {
        self.session.disconnect()
    }
}

extension MQTTBatchingSession: MQTTSessionDelegate {

    public func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
        self.delegate?.mqttDidReceive(messages: [message], from: self)
    }

    public func mqttDidDisconnect(session: MQTTSession, error: Error?) {
        self.delegate?.mqttConnectionFailed(session: self, error: error)
    }

    public func mqttSocketErrorOccurred(session: MQTTSession, error: Error?) {
        self.delegate?.mqttErrorOccurred(session: self, error: error)
    }
}
