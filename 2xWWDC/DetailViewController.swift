//
//  DetailViewController.swift
//  2xWWDC
//
//  Created by B Gay on 6/1/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import SafariServices

final class DetailViewController: UIViewController, StoryboardInitializable
{
    enum SearchState
    {
        case normal
        case searching
    }
    
    var observerContext = 8
    
    var session: Session?
    {
        didSet
        {
            title = session?.session
            fetchResources()
        }
    }
    
    var sessionResources: SessionResources?
    {
        didSet
        {
            resourcesTableView?.reloadData()
            transcriptTableView?.reloadData()
            if sessionResources?.transcript.sentences.isEmpty == true
            {
                UIView.animate(withDuration: 0.2)
                { [unowned self] in
                    self.transcriptButton?.isHidden = true
                }
                if let transcriptContainer = transcriptContainer
                {
                    scrollViewStackView?.removeArrangedSubview(transcriptContainer)
                    transcriptContainer.removeFromSuperview()

                }
            }
        }
    }
    
    let highLightColor = UIColor(white: 0.0, alpha: 1.0)
    let lowLightColor = UIColor(white: 0.0, alpha: 0.33)
    
    @IBOutlet weak var selectionIndicatorLeadinConstraint: NSLayoutConstraint!
    @IBOutlet weak var transcriptTableView: UITableView!
    @IBOutlet weak var resourcesTableView: UITableView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var transcriptButton: UIButton!
    @IBOutlet weak var indicatorView: UIView!
    @IBOutlet weak var transcriptContainer: UIView!
    @IBOutlet weak var scrollViewStackView: UIStackView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var toolbarBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressView: UIProgressView!
    
    var transcriptIndex = IndexPath(row: 0, section: 0)
    var searchString = ""
    
    lazy var avPlayerViewController: AVPlayerViewController =
    {
        let avPlayerViewController = AVPlayerViewController()
        self.addChildViewController(avPlayerViewController)
        avPlayerViewController.view.frame = self.videoContainerView.bounds
        self.videoContainerView.addSubview(avPlayerViewController.view)
        avPlayerViewController.didMove(toParentViewController: self)
        avPlayerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        avPlayerViewController.view.topAnchor.constraint(equalTo: self.videoContainerView.topAnchor).isActive = true
        avPlayerViewController.view.bottomAnchor.constraint(equalTo: self.videoContainerView.bottomAnchor).isActive = true
        avPlayerViewController.view.leadingAnchor.constraint(equalTo: self.videoContainerView.leadingAnchor).isActive = true
        avPlayerViewController.view.trailingAnchor.constraint(equalTo: self.videoContainerView.trailingAnchor).isActive = true
        avPlayerViewController.allowsPictureInPicturePlayback = true
        return avPlayerViewController
    }()
    
    lazy var searchController: UISearchController =
    {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.searchBar.barTintColor = UIColor(white: 0.95, alpha: 1.0)
        searchController.searchBar.tintColor = .black
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()
    
    var searchState: SearchState
    {
        if searchController.isActive && !searchString.isEmpty
        {
            return .searching
        }
        return .normal
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        toolbar.isTranslucent = true
        let searchBarItem = UIBarButtonItem(customView: searchController.searchBar)
        searchBarItem.width = 300.0
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          searchBarItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)], animated: false)
        
        stackView.isHidden = session == nil
        indicatorView.isHidden = session == nil
        toolbar.isHidden = session == nil
        
        textView.text = session?.description
        resourcesTableView.estimatedRowHeight = 55.0
        resourcesTableView.rowHeight = UITableViewAutomaticDimension
        transcriptTableView.estimatedRowHeight = 55.0
        transcriptTableView.rowHeight = UITableViewAutomaticDimension
        
        setupNotifications()
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
        guard session != nil else { return }
        avPlayerViewController.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        guard let session = session else { return }
        let url = FileManager.default.fileExists(atPath: FileStorage().url(for: session.videoURL).path) ? FileStorage().url(for: session.videoURL) : session.videoURL
        setPlayer(with: url)
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        avPlayerViewController.player?.pause()
        super.viewDidDisappear(animated)
    }
    
    func setupNotifications()
    {
        NotificationCenter.default.addObserver(for: keyboardWillShow, object: nil, queue: nil)
        { [weak self] (payload) in
            UIView.animate(withDuration: payload.animationDuration)
            {
                self?.toolbarBottomConstraint.constant = payload.endFrame.height
                self?.view.layoutIfNeeded()
            }
        }
        
        NotificationCenter.default.addObserver(for: keyboardWillHide, object: nil, queue: nil)
        { [weak self] (payload) in
            UIView.animate(withDuration: payload.animationDuration)
            {
                self?.toolbarBottomConstraint.constant = 0.0
                self?.view.layoutIfNeeded()
            }
        }
        
        NotificationCenter.default.addObserver(for: sessionDidFinishingDownloading, object: nil, queue: .main)
        { [weak self] (payload) in
            guard self?.sessionResources?.sessionResources.contains(where: { $0.link == payload.cloudURL}) == true else { return }
            self?.progressView?.isHidden = true
            self?.resourcesTableView?.reloadData()
        }
    }
    
    func setPlayer(with url: URL)
    {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        avPlayerViewController.player = AVPlayer(playerItem: item)
        avPlayerViewController.player?.play()
        addObservers()
        avPlayerViewController.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main)
        { [unowned self] (time) in
            guard self.transcriptIndex.row + 1 < (self.sessionResources?.transcript.sentences.count ?? 0) else { return }
            let nextSentence = self.sessionResources?.transcript.sentences[self.transcriptIndex.row + 1]
            if time.seconds > nextSentence?.startTime ?? 0.0
            {
                let newIndex = IndexPath(row: self.transcriptIndex.row + 1, section: 0)
                let lastCell = self.transcriptTableView.cellForRow(at: self.transcriptIndex)
                lastCell?.textLabel?.textColor = self.lowLightColor
                let newCell = self.transcriptTableView.cellForRow(at: newIndex)
                newCell?.textLabel?.textColor = self.highLightColor
                self.transcriptIndex = newIndex
                self.transcriptTableView.scrollToRow(at: newIndex, at: .top, animated: true)
            }
            
        }
    }
    
    func addObservers()
    {
        let options: NSKeyValueObservingOptions = [.new, .old, .initial]
        avPlayerViewController.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: options, context: &observerContext)
    }
    
    @IBAction func didChangeSegmentedControl(_ sender: UISegmentedControl)
    {
        switch sender.selectedSegmentIndex
        {
        case 0:
            avPlayerViewController.player?.rate = 1.0
        case 1:
            avPlayerViewController.player?.rate = 1.5
        case 2:
            avPlayerViewController.player?.rate = 2.0
        default:
            avPlayerViewController.player?.rate = 2.0
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard keyPath == #keyPath(AVPlayer.rate) else { return }
        switch avPlayerViewController.player?.rate ?? 0.0
        {
        case (0.0 ..< 1.1):
            if let player = avPlayerViewController.player,
               let item = avPlayerViewController.player?.currentItem,
               let session = self.session,
               item.forwardPlaybackEndTime.seconds - player.currentTime().seconds < 30.0
            {
                UserDefaults.standard.setHasSeen(session)
                NotificationCenter.default.post(name: .WWSessionDidFinishWatching, object: nil, userInfo: ["year": session.year, "session": session.dictionaryRep])
            }
            segmentedControl.selectedSegmentIndex = 0
        case (1.1 ..< 1.6):
            segmentedControl.selectedSegmentIndex = 1
        case (1.6 ... 2.1):
            segmentedControl.selectedSegmentIndex = 2
        default:
            segmentedControl.selectedSegmentIndex = 2
        }
    }
    
    func fetchResources()
    {
        guard let session = self.session,
              let resource = SessionResource.resource(for: session) else { return }
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        CachedWebservice.load(resource)
        { (response) in
            DispatchQueue.main.async
            {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                switch response
                {
                case .error(let error):
                    print(error)
                case .success(let resources):
                    if let resources = resources
                    {
                        self.sessionResources = resources
                    }
                }
            }
        }
    }
    
    @IBAction func didPressDescription(_ sender: UIButton)
    {
        scrollView.setContentOffset(.zero, animated: true)
    }
    
    @IBAction func didPressResources(_ sender: UIButton)
    {
        scrollView.setContentOffset(CGPoint(x: view.bounds.width, y: 0.0), animated: true)
    }
    
    @IBAction func didPressTranscript(_ sender: UIButton)
    {
        scrollView.setContentOffset(CGPoint(x: view.bounds.width * 2, y: 0.0), animated: true)
    }
}

extension DetailViewController: UITableViewDelegate, UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if tableView === resourcesTableView
        {
            switch searchState
            {
            case .normal:
                return sessionResources?.sessionResources.count ?? 0
            case .searching:
                return sessionResources?.sessionResources.filter { $0.title.lowercased().contains(searchString.lowercased()) }.count ?? 0
            }
        }
        switch searchState
        {
        case .normal:
            return sessionResources?.transcript.sentences.count ?? 0
        case .searching:
            return sessionResources?.transcript.sentences.filter { $0.text.lowercased().contains(searchString.lowercased()) }.count ?? 0
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if tableView === resourcesTableView
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ResourceCell", for: indexPath)
            let sessionResource: SessionResource?
            switch searchState
            {
            case .normal:
                sessionResource = sessionResources?.sessionResources[indexPath.row]
                cell.textLabel?.text = sessionResource?.title
            case .searching:
                sessionResource = sessionResources?.sessionResources.filter { $0.title.lowercased().contains(searchString.lowercased()) }[indexPath.row]
                let attribString = NSMutableAttributedString(string: sessionResource?.title ?? "", attributes: [NSForegroundColorAttributeName: UIColor.black])
                let range = ((sessionResource?.title.lowercased() ?? "") as NSString).range(of: searchString.lowercased())
                attribString.addAttributes([NSForegroundColorAttributeName: UIColor.orange], range: range)
                cell.textLabel?.attributedText = attribString
            }
            if sessionResource?.title.lowercased().contains("hd") == true || sessionResource?.title.lowercased().contains("sd") == true
            {
                let button = UIButton(type: .custom)
                if FileManager.default.fileExists(atPath: FileStorage().url(for: sessionResource!.link).path)
                {
                    button.frame = CGRect(x: 0, y: 0, width: #imageLiteral(resourceName: "trash").size.width * 0.75, height:  #imageLiteral(resourceName: "trash").size.width * 0.75)
                    button.addTarget(self, action: #selector(self.didPressTrash(sender:)), for: .touchUpInside)
                    button.setImage(#imageLiteral(resourceName: "trash"), for: .normal)
                    button.tintColor = .black
                }
                else
                {
                    button.frame = CGRect(x: 0, y: 0, width: #imageLiteral(resourceName: "download").size.width * 0.75, height:  #imageLiteral(resourceName: "download").size.width * 0.75)
                    button.addTarget(self, action: #selector(self.didPressDownload(sender:)), for: .touchUpInside)
                    button.setImage(#imageLiteral(resourceName: "download"), for: .normal)
                    button.tintColor = .black
                }
                
                cell.accessoryView = button
            }
            else
            {
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        }
        else
        {
            let sentence: Sentence?
            let cell = tableView.dequeueReusableCell(withIdentifier: "TranscriptCell", for: indexPath)
            switch searchState
            {
            case .normal:
                sentence = sessionResources?.transcript.sentences[indexPath.row]
                cell.textLabel?.text = sentence?.text
                cell.textLabel?.textColor = indexPath == transcriptIndex ? highLightColor : lowLightColor
            case .searching:
                sentence = sessionResources?.transcript.sentences.filter { $0.text.lowercased().contains(searchString.lowercased()) }[indexPath.row]
                let attribString = NSMutableAttributedString(string: sentence?.text ?? "", attributes: [NSForegroundColorAttributeName: indexPath == transcriptIndex ? highLightColor : lowLightColor])
                let range = ((sentence?.text.lowercased() ?? "") as NSString).range(of: searchString.lowercased())
                attribString.addAttributes([NSForegroundColorAttributeName: UIColor.orange], range: range)
                cell.textLabel?.attributedText = attribString
            }
            
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if tableView === resourcesTableView
        {
            let selectedResource: SessionResource?
            switch searchState
            {
            case .normal:
                selectedResource = sessionResources?.sessionResources[indexPath.row]
            case .searching:
                selectedResource = sessionResources?.sessionResources.filter { $0.title.lowercased().contains(searchString.lowercased()) }[indexPath.row]
                searchController.searchBar.resignFirstResponder()
            }
            guard let resource = selectedResource else { return }
            if resource.title.lowercased().contains("hd") || resource.title.lowercased().contains("sd")
            {
                avPlayerViewController.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
                if FileManager.default.fileExists(atPath: FileStorage().url(for: resource.link).path)
                {
                    let url = FileStorage().url(for: resource.link)
                    setPlayer(with: url)
                }
                else
                {
                    setPlayer(with: resource.link)
                }
                transcriptIndex = IndexPath(row: 0, section: 0)
            }
            else
            {
                let safariVC = SFSafariViewController(url: resource.link)
                safariVC.view.tintColor = .black
                safariVC.preferredControlTintColor = .black
                present(safariVC, animated: true)
            }
        }
        else
        {
            let selectedSentence: Sentence?
            switch searchState
            {
            case .normal:
                selectedSentence = sessionResources?.transcript.sentences[indexPath.row]
            case .searching:
                selectedSentence = sessionResources?.transcript.sentences.filter { $0.text.lowercased().contains(searchString.lowercased()) }[indexPath.row]
                searchController.searchBar.resignFirstResponder()
            }
            guard let sentence = selectedSentence else { return }
            let newTime = CMTime(seconds: sentence.startTime, preferredTimescale: 1)
            avPlayerViewController.player?.seek(to: newTime)
            transcriptIndex = indexPath
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    func didPressDownload(sender: UIButton)
    {
        sender.alpha = 0.5
        sender.isEnabled = false
        self.progressView.isHidden = false
        let location = sender.convert(sender.bounds.origin, to: resourcesTableView)
        guard let indexPath = resourcesTableView.indexPathForRow(at: location),
              let resource = sessionResources?.sessionResources[indexPath.row] else { return  }
        DownloadManager.shared.onProgress =
        { [weak self] progress in
            DispatchQueue.main.async
            {
                self?.progressView.progress = progress

            }
        }
        let task = DownloadManager.shared.activate().downloadTask(with: resource.link)
        task.resume()
    }
    
    func didPressTrash(sender: UIButton)
    {
        let location = sender.convert(sender.bounds.origin, to: resourcesTableView)
        guard let indexPath = resourcesTableView.indexPathForRow(at: location),
              let resource = sessionResources?.sessionResources[indexPath.row] else { return  }
        try? FileManager.default.removeItem(at: FileStorage().url(for: resource.link))
        resourcesTableView.reloadRows(at: [indexPath], with: .none)
    }
}

extension DetailViewController: UIScrollViewDelegate
{
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        guard scrollView === self.scrollView else { return }
        selectionIndicatorLeadinConstraint.constant = (scrollView.contentOffset.x / CGFloat(sessionResources?.transcript.sentences.isEmpty == true ? 2 : 3)) + 8.0
    }
}

extension DetailViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController)
    {
        guard let text = searchController.searchBar.text else { return }
        searchString = text
        resourcesTableView.reloadData()
        if sessionResources?.transcript.sentences.isEmpty == false
        {
            transcriptTableView.reloadData()
        }
        
        let range = ((session?.description.lowercased() ?? "") as NSString).range(of: searchString.lowercased())
        let attribDescription = NSMutableAttributedString(string: session?.description ?? "", attributes: [NSForegroundColorAttributeName: UIColor.black])
        attribDescription.addAttributes([NSForegroundColorAttributeName: UIColor.orange], range: range)
        
        textView.attributedText = attribDescription
    }
}

extension DetailViewController: UISearchControllerDelegate
{
    func willPresentSearchController(_ searchController: UISearchController)
    {
        avPlayerViewController.player?.pause()
    }
    
    func didDismissSearchController(_ searchController: UISearchController)
    {
        textView.text = session?.description
        avPlayerViewController.player?.play()
    }
}

