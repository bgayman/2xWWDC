//
//  AppCoordinator.swift
//  2xWWDC
//
//  Created by App Partner on 6/5/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit
import AVKit
import SafariServices

final class AppCoordinator: MasterViewControllerActionDelegate, DetailViewControllerActionDelegate
{
    let splitViewController: UISplitViewController
    
    init(splitViewController: UISplitViewController)
    {
        self.splitViewController = splitViewController
        start()
    }
    
    func start()
    {
        guard let navigationController = splitViewController.viewControllers.first as? UINavigationController, let masterViewController = navigationController.topViewController as? MasterViewController else { return }
        masterViewController.actionDelegate = self
    }
    
    func showSession(for year: String, session: String)
    {
        switch splitViewController.viewControllers.count
        {
        case 1:
            guard let navController = splitViewController.viewControllers.first as? UINavigationController else { return }
            if let embededNav = navController.topViewController as? UINavigationController,
               let detailVC = embededNav.topViewController as? DetailViewController
            {
                guard !(detailVC.session?.session == session && detailVC.session?.year == year) else { return }
                navController.popToRootViewController(animated: true)
            }
        case 2:
            guard let navController = splitViewController.viewControllers.last as? UINavigationController else { return }
            if let detailVC = navController.topViewController as? DetailViewController
            {
                guard !(detailVC.session?.session == session && detailVC.session?.year == year) else { return }
                break
            }
        default:
            break
        }
        var hasShownSession = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        CachedWebservice.load(Year.all)
        { (response) in
            DispatchQueue.main.async
            {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                switch response
                {
                case .success(let returnYears):
                    if let year = returnYears?.first(where: { $0.year == year }),
                       let session = year.sessions.first(where: { $0.session == session })
                    {
                        if hasShownSession == false
                        {
                            hasShownSession = true
                            let detail = DetailViewController.makeFromStoryboard()
                            detail.session = session
                            detail.actionDelegate = self
                            let nav = UINavigationController(rootViewController: detail)
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5)
                            {
                                self.splitViewController.showDetailViewController(nav, sender: self)
                            }
                        }
                    }
                case .error(let error):
                    print(error)
                }
            }
        }
    }
    
    func didSelection(session: Session, in masterViewController: MasterViewController)
    {
        let detail = DetailViewController.makeFromStoryboard()
        detail.session = session
        detail.actionDelegate = self
        let nav = UINavigationController(rootViewController: detail)
        splitViewController.showDetailViewController(nav, sender: self)
    }
    
    func didForceTouch(session: Session, in masterViewController: MasterViewController) -> UIViewController?
    {
        let detail = DetailViewController.makeFromStoryboard()
        detail.session = session
        detail.actionDelegate = self
        return detail
    }
    
    func didCommitPreview(context: UIViewControllerPreviewing, viewControllerToCommit: UIViewController, in masterViewController: MasterViewController)
    {
        let nav = UINavigationController(rootViewController: viewControllerToCommit)
        splitViewController.showDetailViewController(nav, sender: self)
    }
    
    func didPress(sessionResource: SessionResource, in detailViewController: DetailViewController)
    {
        let safariVC = SFSafariViewController(url: sessionResource.link)
        safariVC.view.tintColor = .black
        safariVC.preferredControlTintColor = .black
        detailViewController.present(safariVC, animated: true)
    }
    
    func didForceTouch(sessionResource: SessionResource?, in detailViewController: DetailViewController) -> UIViewController?
    {
        guard let sessionResource = sessionResource else { return nil }
        let safariVC = SFSafariViewController(url: sessionResource.link)
        safariVC.view.tintColor = .black
        safariVC.preferredControlTintColor = .black
        return safariVC
    }
    
    func didCommitPreview(context: UIViewControllerPreviewing, viewControllerToCommit: UIViewController, in detailViewController: DetailViewController)
    {
        detailViewController.present(viewControllerToCommit, animated: true)
    }
}

