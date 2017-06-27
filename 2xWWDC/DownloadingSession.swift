//
//  DownloadingSession.swift
//  2xWWDC
//
//  Created by B Gay on 6/20/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation
import CoreData

@objc(DownloadingSession)
class DownloadingSession: NSManagedObject
{
    var id: Int?
    {
        return videoURLValue?.hashValue
    }
}

