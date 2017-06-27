//
//  DownloadInfo.swift
//  2xWWDC
//
//  Created by B Gay on 6/20/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation
import CoreData

enum DownloadStatus: String
{
    case pending
    case downloading
    case paused
    case failed
    case completed
}

@objc(DownloadInfo)
class DownloadInfo: NSManagedObject
{
    var status: DownloadStatus?
    {
        get
        {
            guard let value = statusValue else { return nil }
            return DownloadStatus(rawValue: value)
        }
        
        set
        {
            statusValue = newValue?.rawValue
        }
    }

}
