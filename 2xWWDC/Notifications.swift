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
    static func when(_ name: Notification.Name, perform block: @escaping (Notification) -> ())
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

let keyboardWillShow = NotificationDescriptor(name: .UIKeyboardWillShow, parse: KeyboardShowPayload.init)
let keyboardWillHide = NotificationDescriptor(name: .UIKeyboardWillHide, parse: KeyboardShowPayload.init)

struct KeyboardShowPayload
{
    var beginFrame: CGRect
    let endFrame: CGRect
    let animationCurve: UIViewAnimationCurve
    let animationDuration: TimeInterval
    let isLocal: Bool
    
    init(userInfo: [AnyHashable: Any])
    {
        self.beginFrame = userInfo[UIKeyboardFrameBeginUserInfoKey] as! CGRect
        self.endFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as! CGRect
        let animationCurveRaw = userInfo[UIKeyboardAnimationCurveUserInfoKey] as! UIViewAnimationCurve.RawValue
        self.animationCurve = UIViewAnimationCurve(rawValue: animationCurveRaw)!
        self.animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
        self.isLocal = userInfo[UIKeyboardIsLocalUserInfoKey] as! Bool
    }
}

extension Notification.Name
{
    static let WWSessionDidFinishWatching = Notification.Name("WWSessionDidFinishWatching")
    static let WWSessionDidFinishDownloading = Notification.Name("WWSessionDidFinishDownloading")
}

let sessionDidFinishingWatching = NotificationDescriptor(name: .WWSessionDidFinishWatching, parse: WWSessionDidFinishWatchingPayload.init)
let sessionDidFinishingDownloading = NotificationDescriptor(name: .WWSessionDidFinishDownloading, parse: WWSessionDidFinishDownloadingPayload.init)

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
    
    init(userInfo: [AnyHashable: Any])
    {
        let urlString = userInfo["resourceURL"] as! String
        self.cloudURL = URL(string: urlString)!
    }
}
