//
//  DownloadController.swift
//  2xWWDC
//
//  Created by B Gay on 6/20/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation
import CoreData

final class DownloadController
{
    let downloadQueue = OperationQueue()
    
    static let shared = DownloadController()
    
    func download(session: Session, videoURL: URL)
    {
        let context = PersistenceManager.sharedContainer.viewContext
        let downloadInfo = DownloadInfo(context: context)
        downloadInfo.downloadedAt = NSDate()
        downloadInfo.status = .pending
        let downloadingSession = DownloadingSession(context: context)
        downloadingSession.videoURLValue = session.videoURL.absoluteString
        downloadInfo.session = downloadingSession
        downloadInfo.progress = 0.0
        do
        {
            try context.save()
        }
        catch
        {
            print(error.localizedDescription)
        }
        
        let operation = DownloadOperation(url: videoURL, sessionID: session.id)
        downloadQueue.addOperation(operation)
    }
    
}
