//
//  DownloadOperation.swift
//  2xWWDC
//
//  Created by B Gay on 6/20/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation
import CoreData

final class DownloadOperation: BaseOperation, URLSessionDownloadDelegate
{
    @objc let url: URL
    @objc let sessionID: Int
    
    @objc lazy var context: NSManagedObjectContext = PersistenceManager.sharedContainer.newBackgroundContext()
    
    @objc let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
    
    @objc lazy var downloadInfo: DownloadInfo! =
    {
        let fetchRequest: NSFetchRequest<DownloadInfo> = DownloadInfo.fetchRequest()
        do
        {
            let downloads = try self.context.fetch(fetchRequest)
            return downloads.first { $0.session?.id == self.sessionID }
        }
        catch
        {
            print("ERROR: \(error.localizedDescription)")
            return nil
        }
    }()
    
    @objc lazy var session: URLSession =
    {
        let session = URLSession(configuration: self.config, delegate: self, delegateQueue: nil)
        return session
    }()
    
    @objc var downloadTask: URLSessionDownloadTask?
    
    @objc init(url: URL, sessionID: Int)
    {
        self.url = url
        self.sessionID = sessionID
    }
    
    override func execute()
    {
        downloadInfo.status = .downloading
        try! PersistenceManager.save(context: context)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    override func cancel()
    {
        try! PersistenceManager.save(context: context)
        downloadTask?.cancel()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        let downloadURLValue = downloadTask.originalRequest?.url?.absoluteString ?? ""
        let userInfo: [String: Any] =
        [
            "downloadURL": downloadURLValue,
            "progress": progress,
            "totalBytesWritten": totalBytesWritten,
            "totalBytesExpectedToWrite": totalBytesExpectedToWrite
        ]
        
        downloadInfo.progress = progress
        downloadInfo.sizeInBytes = totalBytesWritten
        
        DispatchQueue.main.async
        {
            NotificationCenter.default.post(name: .WWSessionDidProgressDownloading, object: self, userInfo: userInfo)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        guard let url = downloadTask.originalRequest?.url else { return }
        let newURL = FileStorage.shared.url(for: url)
        try? FileManager.default.moveItem(at: location, to: newURL)
        NotificationCenter.default.post(name: .WWSessionDidFinishDownloading, object: nil, userInfo: ["resourceURL": url.absoluteString, "sessionID": downloadInfo.session?.id ?? 0])
        downloadInfo.progress = 1.0
        downloadInfo.path = newURL.path
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if let e = error as NSError?
        {
            if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled
            {
                downloadInfo.status = .paused
            }
            else
            {
                downloadInfo.status = .failed
            }
        }
        else
        {
            downloadInfo.status = .completed
        }
        downloadInfo.session?.downloadInfo = downloadInfo
        do
        {
            try PersistenceManager.save(context: context)
        }
        catch
        {
            print(error.localizedDescription)
        }
        finish()
    }
}








