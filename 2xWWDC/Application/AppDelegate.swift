//
//  AppDelegate.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate
{

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let container = NSPersistentContainer(name: "Model")
        PersistenceManager.sharedContainer = container
        container.loadPersistentStores
        { (storeDescription, error) in
            container.viewContext.automaticallyMergesChangesFromParent = true
            try! container.viewContext.setQueryGenerationFrom(.current)
            
            if let e = error
            {
                print("Error setting up Core Data: \(e)")
            }
            else
            {
                print("Loaded store at: \(storeDescription.url?.absoluteString ?? "")")
            }
        }
        
        
        let splitViewController = window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        appCoordinator = AppCoordinator(splitViewController: splitViewController)
        appCoordinator?.start()
        
        let store = NSUbiquitousKeyValueStore.default
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateKVStoreItems(notification:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
        
        let audioSession = AVAudioSession.sharedInstance()
        do
        {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch
        {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: - Split view

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.session == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
    {
        completionHandler()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void)
    {
        guard let userInfo = shortcutItem.userInfo,
              let year = userInfo["year"] as? String,
              let session = userInfo["session"] as? String
        else
        {
            completionHandler(false)
            return
        }
        appCoordinator?.showSession(for: year, session: session)
        completionHandler(true)
    }

}

// MARK: - UKVStore Update
extension AppDelegate
{
    @objc func updateKVStoreItems(notification: Notification)
    {
        let userInfo = notification.userInfo
        guard let reasonForChange = userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber else { return }
        let reason = reasonForChange.intValue
        if reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange
        {
            if let changedKeys = userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            {
                let store = NSUbiquitousKeyValueStore.default
                let userDefaults = UserDefaults.standard
                for key in changedKeys
                {
                    let value = store.object(forKey: key)
                    userDefaults.set(value, forKey: key)
                }
            }
        }
    }
}

