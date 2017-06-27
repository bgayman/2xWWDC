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

