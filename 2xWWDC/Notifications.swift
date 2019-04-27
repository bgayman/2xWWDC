//
//  Notifications.swift
//  2xWWDC
//
//  Created by B Gay on 6/7/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit

extension NotificationCenter
{
    @objc static func when(_ name: Notification.Name, perform block: @escaping (Notification) -> ())
    {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: block)
    }
}

extension NotificationCenter
{
    @discardableResult
    func addObserver<A>(for descriptor: NotificationDescriptor<A>, object obj: Any?, queue: OperationQueue?, using block: @escaping (A) -> Void) -> NSObjectProtocol
    {
        return addObserver(forName: descriptor.name, object: obj, queue: queue)
        { (note) in
            block(descriptor.parse(note.userInfo!))
        }
    }
}

struct NotificationDescriptor<A>
{
    let name: Notification.Name
    let parse: ([AnyHashable: Any]) -> A
}

let keyboardWillShow = NotificationDescriptor(name: UIResponder.keyboardWillShowNotification, parse: KeyboardShowPayload.init)
let keyboardWillHide = NotificationDescriptor(name: UIResponder.keyboardWillHideNotification, parse: KeyboardShowPayload.init)

struct KeyboardShowPayload
{
    var beginFrame: CGRect
    let endFrame: CGRect
    let animationCurve: UIView.AnimationCurve
    let animationDuration: TimeInterval
    let isLocal: Bool
    
    init(userInfo: [AnyHashable: Any])
    {
        self.beginFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! CGRect
        self.endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        let animationCurveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! UIView.AnimationCurve.RawValue
        self.animationCurve = UIView.AnimationCurve(rawValue: animationCurveRaw)!
        self.animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        self.isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as! Bool
    }
}

extension Notification.Name
{
    static let WWSessionDidFinishWatching = Notification.Name("WWSessionDidFinishWatching")
    static let WWSessionDidFinishDownloading = Notification.Name("WWSessionDidFinishDownloading")
    static let WWSessionDidProgressDownloading = Notification.Name("WWSessionDidProgressDownloading")
}

let sessionDidFinishingWatching = NotificationDescriptor(name: .WWSessionDidFinishWatching, parse: WWSessionDidFinishWatchingPayload.init)
let sessionDidFinishingDownloading = NotificationDescriptor(name: .WWSessionDidFinishDownloading, parse: WWSessionDidFinishDownloadingPayload.init)
let sessionDidProgressDownloading = NotificationDescriptor(name: .WWSessionDidProgressDownloading, parse: WWSessionDidProgressDownloadingPayload.init)

struct WWSessionDidFinishWatchingPayload
{
    let session: Session
    
    init(userInfo: [AnyHashable: Any])
    {
        let year = userInfo["year"] as! String
        let sessionDict = userInfo["session"] as! [String: Any]
        self.session = Session(json: sessionDict, year: year)!
    }
}

struct WWSessionDidFinishDownloadingPayload
{
    let cloudURL: URL
    let sessionID: Int
    
    init(userInfo: [AnyHashable: Any])
    {
        let urlString = userInfo["resourceURL"] as! String
        self.cloudURL = URL(string: urlString)!
        self.sessionID = userInfo["sessionID"] as! Int
    }
}

struct WWSessionDidProgressDownloadingPayload
{
    let downloadURLValue: String
    let progress: Float
    let totalBytesWritten: Int64
    let totalBytesExpectedToWrite: Int64
    
    init(userInfo: [AnyHashable: Any])
    {
        self.downloadURLValue = userInfo["downloadURL"] as! String
        self.progress = userInfo["progress"] as! Float
        self.totalBytesWritten = userInfo["totalBytesWritten"] as! Int64
        self.totalBytesExpectedToWrite = userInfo["totalBytesExpectedToWrite"] as! Int64
    }
}
