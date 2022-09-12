//
//  ViewController.swift
//  SimpleWebRTC
//
//  Created by n0 on 2019/01/05.
//  Copyright © 2019年 n0. All rights reserved.
//

import UIKit
import Starscream
import WebRTC
import UIKit

struct VStreamInfo: Codable {
    var applicationName: String?
    var streamName: String?
    var sessionId: String?
}

struct VSdp: Codable {
    var type: String?
    var sdp: String?
}

struct VIceCandidate: Codable {
    var candidate: String?
    var sdpMid: String?
    var sdpMLineIndex: Int?
}

struct VResponse: Codable {
    var status: Int?
    var statusDescription: String?
    var direction: String?
    var command: String?
    var streamInfo: VStreamInfo?
    var sdp: VSdp?
    var iceCandidates: [VIceCandidate]?
}

struct VRequest: Codable {
    var direction: String?
    var command: String?
    var streamInfo: VStreamInfo?
    var sdp: VSdp?
}

class ViewController: UIViewController, WebSocketDelegate, WebRTCClientDelegate, CameraSessionDelegate {
    
    enum messageType {
        case greet
        case introduce
        
        func text() -> String {
            switch self {
            case .greet:
                return "Hello!"
            case .introduce:
                return "I'm " + UIDevice.modelName
            }
        }
    }
    
    //MARK: - Properties
    var webRTCClient: WebRTCClient!
    var socket: WebSocket!
    var streamInfo: VStreamInfo!
    var tryToConnectWebSocket: Timer!
    var cameraSession: CameraSession?
    
    // You can create video source from CMSampleBuffer :)
    var useCustomCapturer: Bool = false
    var cameraFilter: CameraFilter?
    
    // Constants
    // MARK: Change this ip address in your case
    let ipAddress: String = "192.168.1.189"
    let wsStatusMessageBase = "WebSocket: "
    let webRTCStatusMesasgeBase = "WebRTC: "
    let likeStr: String = "Like"
    
    // UI
    var wsStatusLabel: UILabel!
    var webRTCStatusLabel: UILabel!
    var webRTCMessageLabel: UILabel!
    var likeImage: UIImage!
    var likeImageViewRect: CGRect!
    var code: String = ""
    
    //MARK: - ViewController Override Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        #if targetEnvironment(simulator)
        // simulator does not have camera
        self.useCustomCapturer = false
        #endif
        
        webRTCClient = WebRTCClient()
        webRTCClient.delegate = self
        webRTCClient.setup(videoTrack: true, audioTrack: true, dataChannel: true, customFrameCapturer: useCustomCapturer)
        
        if useCustomCapturer {
            print("--- use custom capturer ---")
            self.cameraSession = CameraSession()
            self.cameraSession?.delegate = self
            self.cameraSession?.setupSession()
            
            self.cameraFilter = CameraFilter()
        }

        // socket = WebSocket(url: URL(string: "ws://" + ipAddress + ":8080/")!)
        // socket = WebSocket(url: URL(string: "ws://webrtc.staging.geniebook.dev:8080/")!)
        socket = WebSocket(url: URL(string: "wss://stream-vm.dev.geniebook.dev:444/webrtc-session.json")!)
        socket.delegate = self

        streamInfo = VStreamInfo(
                applicationName: "online_lesson",
                streamName: "2048300000006196",
                sessionId: "[empty]"
        )

        tryToConnectWebSocket = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
            if self.webRTCClient.isConnected || self.socket.isConnected {
                return
            }
            
            self.socket.connect()
        })
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.setupUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UI
    private func setupUI(){
        let remoteVideoViewContainter = UIView(frame: CGRect(x: 0, y: 0, width: ScreenSizeUtil.width(), height: ScreenSizeUtil.height()*0.7))
        remoteVideoViewContainter.backgroundColor = .gray
        self.view.addSubview(remoteVideoViewContainter)
        
        let remoteVideoView = webRTCClient.remoteVideoView()
        webRTCClient.setupRemoteViewFrame(frame: CGRect(x: 0, y: 0, width: ScreenSizeUtil.width()*0.7, height: ScreenSizeUtil.height()*0.7))
        remoteVideoView.center = remoteVideoViewContainter.center
        remoteVideoViewContainter.addSubview(remoteVideoView)
        
        let localVideoView = webRTCClient.localVideoView()
        webRTCClient.setupLocalViewFrame(frame: CGRect(x: 0, y: 0, width: ScreenSizeUtil.width()/3, height: ScreenSizeUtil.height()/3))
        localVideoView.center.y = self.view.center.y
        localVideoView.subviews.last?.isUserInteractionEnabled = true
        self.view.addSubview(localVideoView)
        
        let localVideoViewButton = UIButton(frame: CGRect(x: 0, y: 0, width: localVideoView.frame.width, height: localVideoView.frame.height))
        localVideoViewButton.backgroundColor = UIColor.clear
        localVideoViewButton.addTarget(self, action: #selector(self.localVideoViewTapped(_:)), for: .touchUpInside)
        localVideoView.addSubview(localVideoViewButton)
        
        let likeButton = UIButton(frame: CGRect(x: remoteVideoViewContainter.right - 50, y: remoteVideoViewContainter.bottom - 50, width: 40, height: 40))
        likeButton.backgroundColor = UIColor.clear
        likeButton.addTarget(self, action: #selector(self.likeButtonTapped(_:)), for: .touchUpInside)
        self.view.addSubview(likeButton)
        likeButton.setImage(UIImage(named: "like_border.png"), for: .normal)
        
        likeImage = UIImage(named: "like_filled.png")
        likeImageViewRect = CGRect(x: remoteVideoViewContainter.right - 70, y: likeButton.top - 70, width: 60, height: 60)
        
        let messageButton = UIButton(frame: CGRect(x: likeButton.left - 220, y: remoteVideoViewContainter.bottom - 50, width: 210, height: 40))
        messageButton.setBackgroundImage(UIColor.green.rectImage(width: messageButton.frame.width, height: messageButton.frame.height), for: .normal)
        messageButton.addTarget(self, action: #selector(self.sendMessageButtonTapped(_:)), for: .touchUpInside)
        messageButton.titleLabel?.adjustsFontSizeToFitWidth = true
        messageButton.setTitle(messageType.greet.text(), for: .normal)
        messageButton.layer.cornerRadius = 20
        messageButton.layer.masksToBounds = true
        self.view.addSubview(messageButton)
        
        wsStatusLabel = UILabel(frame: CGRect(x: 0, y: remoteVideoViewContainter.bottom, width: ScreenSizeUtil.width(), height: 30))
        wsStatusLabel.textAlignment = .center
        self.view.addSubview(wsStatusLabel)
        webRTCStatusLabel = UILabel(frame: CGRect(x: 0, y: wsStatusLabel.bottom, width: ScreenSizeUtil.width(), height: 30))
        webRTCStatusLabel.textAlignment = .center
        webRTCStatusLabel.text = webRTCStatusMesasgeBase + "initialized"
        self.view.addSubview(webRTCStatusLabel)
        webRTCMessageLabel = UILabel(frame: CGRect(x: 0, y: webRTCStatusLabel.bottom, width: ScreenSizeUtil.width(), height: 30))
        webRTCMessageLabel.textAlignment = .center
        webRTCMessageLabel.textColor = .black
        self.view.addSubview(webRTCMessageLabel)
        
        let buttonWidth = ScreenSizeUtil.width()*0.4
        let buttonHeight: CGFloat = 60
        let buttonRadius: CGFloat = 30
        let callButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
        callButton.setBackgroundImage(UIColor.blue.rectImage(width: callButton.frame.width, height: callButton.frame.height), for: .normal)
        callButton.layer.cornerRadius = buttonRadius
        callButton.layer.masksToBounds = true
        callButton.center.x = ScreenSizeUtil.width()/4
        callButton.center.y = webRTCStatusLabel.bottom + (ScreenSizeUtil.height() - webRTCStatusLabel.bottom)/2
        callButton.setTitle("Call", for: .normal)
        callButton.titleLabel?.font = UIFont.systemFont(ofSize: 23)
        callButton.addTarget(self, action: #selector(self.callButtonTapped(_:)), for: .touchUpInside)
        self.view.addSubview(callButton)
        
        let hangupButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
        hangupButton.setBackgroundImage(UIColor.red.rectImage(width: hangupButton.frame.width, height: hangupButton.frame.height), for: .normal)
        hangupButton.layer.cornerRadius = buttonRadius
        hangupButton.layer.masksToBounds = true
        hangupButton.center.x = ScreenSizeUtil.width()/4 * 3
        hangupButton.center.y = callButton.center.y
        hangupButton.setTitle("hang up" , for: .normal)
        hangupButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        hangupButton.addTarget(self, action: #selector(self.hangupButtonTapped(_:)), for: .touchUpInside)
        self.view.addSubview(hangupButton)
    }
    
    // MARK: - UI Events
    @objc func callButtonTapped(_ sender: UIButton){
        if !webRTCClient.isConnected {
            code = randomString(length: 10)
            webRTCClient.connect(onSuccess: { (offerSDP: RTCSessionDescription) -> Void in
                self.offerSdp()
            })
        }
    }
    
    @objc func hangupButtonTapped(_ sender: UIButton){
        if webRTCClient.isConnected {
            webRTCClient.disconnect()
        }
    }
    
    @objc func sendMessageButtonTapped(_ sender: UIButton){
        webRTCClient.sendMessge(message: (sender.titleLabel?.text!)!)
        if sender.titleLabel?.text == messageType.greet.text() {
            sender.setTitle(messageType.introduce.text(), for: .normal)
        }else if sender.titleLabel?.text == messageType.introduce.text() {
            sender.setTitle(messageType.greet.text(), for: .normal)
        }
    }
    
    @objc func likeButtonTapped(_ sender: UIButton){
        let data = likeStr.data(using: String.Encoding.utf8)
        webRTCClient.sendData(data: data!)
    }
    
    @objc func localVideoViewTapped(_ sender: UITapGestureRecognizer) {
//        if let filter = self.cameraFilter {
//            filter.changeFilter(filter.filterType.next())
//        }
        webRTCClient.switchCameraPosition()
    }
    
    private func startLikeAnimation(){
        let likeImageView = UIImageView(frame: likeImageViewRect)
        likeImageView.backgroundColor = UIColor.clear
        likeImageView.contentMode = .scaleAspectFit
        likeImageView.image = likeImage
        likeImageView.alpha = 1.0
        self.view.addSubview(likeImageView)
        UIView.animate(withDuration: 0.5, animations: {
            likeImageView.alpha = 0.0
        }) { (reuslt) in
            likeImageView.removeFromSuperview()
        }
    }
    
    // MARK: - WebRTC Signaling
    func offerSdp() {
        let request = VRequest(
                direction: "play",
                command: "getOffer",
                streamInfo: streamInfo,
                sdp: nil
        )
        do {
            let data = try JSONEncoder().encode(request)
            let message = String(data: data, encoding: String.Encoding.utf8)!

            if self.socket.isConnected {
                print("CurrentLog - sendSdp - \(message)")
                self.socket.write(string: message)
            }
        }catch{
            print(error)
        }
    }

    func answerSdp(answerSDP: RTCSessionDescription) {
        let request = VRequest(
                direction: "play",
                command: "sendResponse",
                streamInfo: streamInfo,
                sdp: VSdp(type: "answer", sdp: answerSDP.sdp)
        )
        do {
            let data = try JSONEncoder().encode(request)
            let message = String(data: data, encoding: String.Encoding.utf8)!

            if self.socket.isConnected {
                print("CurrentLog - sendSdp - \(message)")
                self.socket.write(string: message)
            }
        }catch{
            print(error)
        }
    }
    
}

// MARK: - WebSocket Delegate
extension ViewController {
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("-- websocket did connect --")
        wsStatusLabel.text = wsStatusMessageBase + "connected"
        wsStatusLabel.textColor = .green
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("-- websocket did disconnect --")
        wsStatusLabel.text = wsStatusMessageBase + "disconnected"
        wsStatusLabel.textColor = .red
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("CurrentLog - websocketDidReceiveMessage - \(text) - \(socket)")
        
        do{
            let msgJSON = try JSONDecoder().decode(VResponse.self, from: text.data(using: .utf8)!)

            let msgStatus = msgJSON.status
            let msgCommand = msgJSON.command
            if msgStatus == 514 {
            } else if msgStatus != 200 {
            } else {
                let streamInfoResponse = msgJSON.streamInfo
                if let streamInfoResponse = streamInfoResponse {
                    streamInfo = streamInfoResponse
                }

                let sdpData = msgJSON.sdp
                if let sdpData = sdpData {
                    webRTCClient.receiveOffer(
                            offerSDP: RTCSessionDescription(type: .offer, sdp: sdpData.sdp!),
                            onCreateAnswer: {(answerSDP: RTCSessionDescription) -> Void in
                                self.answerSdp(answerSDP:answerSDP)
                            })
                }

                let icCandidates = msgJSON.iceCandidates
                if let icCandidates = icCandidates {
                    for icCandidate in icCandidates {
                        webRTCClient.receiveCandidate(candidate: RTCIceCandidate(sdp: icCandidate.candidate ?? "", sdpMLineIndex: Int32(icCandidate.sdpMLineIndex ?? 0), sdpMid: icCandidate.sdpMid))
                    }
                }
            }

        }
        catch{
            print(error)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) { }
}

// MARK: - WebRTCClient Delegate
extension ViewController {
    func didGenerateCandidate(iceCandidate: RTCIceCandidate) {
        // self.sendCandidate(iceCandidate: iceCandidate)
    }
    
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState) {
        var state = ""
        
        switch iceConnectionState {
        case .checking:
            state = "checking..."
        case .closed:
            state = "closed"
        case .completed:
            state = "completed"
        case .connected:
            state = "connected"
        case .count:
            state = "count..."
        case .disconnected:
            state = "disconnected"
        case .failed:
            state = "failed"
        case .new:
            state = "new..."
        }
        self.webRTCStatusLabel.text = self.webRTCStatusMesasgeBase + state
    }
    
    func didConnectWebRTC() {
        self.webRTCStatusLabel.textColor = .green
        // MARK: Disconnect websocket
        self.socket.disconnect()
    }
    
    func didDisconnectWebRTC() {
        self.webRTCStatusLabel.textColor = .red
    }
    
    func didOpenDataChannel() {
        print("did open data channel")
    }
    
    func didReceiveData(data: Data) {
        if data == likeStr.data(using: String.Encoding.utf8) {
            self.startLikeAnimation()
        }
    }
    
    func didReceiveMessage(message: String) {
        self.webRTCMessageLabel.text = message
    }
}

// MARK: - CameraSessionDelegate
extension ViewController {
    func didOutput(_ sampleBuffer: CMSampleBuffer) {
        if self.useCustomCapturer {
            if let cvpixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
                if let buffer = self.cameraFilter?.apply(cvpixelBuffer){
                    self.webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
                }else{
                    print("no applied image")
                }
            }else{
                print("no pixelbuffer")
            }
            //            self.webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
        }
    }
}

func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map{ _ in letters.randomElement()! })
}
