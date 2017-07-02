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
import CoreData
import MobileCoreServices

protocol DetailViewControllerActionDelegate: class
{
    func didPress(sessionResource: SessionResource, in detailViewController: DetailViewController)
    func didForceTouch(sessionResource: SessionResource?, in detailViewController: DetailViewController) -> UIViewController?
    func didCommitPreview(context: UIViewControllerPreviewing, viewControllerToCommit: UIViewController, in detailViewController: DetailViewController)
    func showSession(for year: String, session: String)
}

final class DetailViewController: UIViewController, StoryboardInitializable
{
    // MARK: - Types
    enum SearchState
    {
        case normal
        case searching
    }
    
    enum ResourceSections
    {
        case downloads(downloads: [SessionResource])
        case documents(documents: [SessionResource])
        case videos(videos: [SessionResource])
        
        static func sections(for sessionResources: SessionResources) -> [ResourceSections]
        {
            var sections = [ResourceSections]()
            if !sessionResources.downloads.isEmpty
            {
                sections.append(.downloads(downloads: sessionResources.downloads))
            }
            if !sessionResources.documents.isEmpty
            {
                sections.append(.documents(documents: sessionResources.documents))
            }
            if !sessionResources.videos.isEmpty
            {
                sections.append(.videos(videos: sessionResources.videos))
            }
            return sections
        }
        
        var raw: Int
        {
            switch self
            {
            case .downloads: return 0
            case .documents: return 0
            case .videos: return 0
            }
        }
    }
    
    // MARK: - Properties
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
    
    var resourceLinks: Set<String>?
    var downloadInfo: DownloadInfo?
    
    let highLightColor = UIColor(white: 0.0, alpha: 1.0)
    let lowLightColor = UIColor(white: 0.0, alpha: 0.33)
    weak var actionDelegate: DetailViewControllerActionDelegate?
    
    // MARK: - Outlets
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
    
    // MARK: - Lazy Vars
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

        avPlayerViewController.delegate = self
        
        return avPlayerViewController
    }()
    
    lazy var searchController: UISearchController =
    {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.tintColor = .black
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()
    
    lazy var shareBarButton: UIBarButtonItem =
    {
        let shareBarButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.didPressShare))
        return shareBarButton
    }()
    
    // MARK: - Computed Properties
    var filteredSessionResources: [SessionResource]
    {
        return self.sessionResources?.sessionResources.filter { $0.title.lowercased().contains(self.searchString.lowercased()) } ?? []
    }
    
    var filteredTranscript: [Sentence]
    {
        return self.sessionResources?.transcript.sentences.filter { $0.text.lowercased().contains(self.searchString.lowercased()) } ?? []
    }
    
    var searchState: SearchState
    {
        if searchController.isActive && !searchString.isEmpty
        {
            return .searching
        }
        return .normal
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *)
        {
            navigationItem.largeTitleDisplayMode = .never
        }
        
        toolbar.isTranslucent = true
        let searchBarItem = UIBarButtonItem(customView: searchController.searchBar)
        searchBarItem.width = 200.0
        toolbar.setItems([shareBarButton, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
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
        
        if #available(iOS 11.0, *)
        {
            view.addInteraction(UIDropInteraction(delegate: self))
        }
        
        if traitCollection.forceTouchCapability == .available
        {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        guard let session = session else { return }
        let url = FileManager.default.fileExists(atPath: FileStorage().url(for: session.videoURL).path)
            ? FileStorage().url(for: session.videoURL)
            : session.videoURL
        
        checkForDownload()
        setPlayer(with: url)
        addQuickAction()
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
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        avPlayerViewController.player?.pause()
        if let item = avPlayerViewController.player?.currentItem,
           let session = self.session,
           let player = avPlayerViewController.player,
           item.duration.seconds - player.currentTime().seconds > 30.0
        {
            UserDefaults.standard.setVideoProgress(session, progress: item.currentTime().seconds)
        }
        super.viewDidDisappear(animated)
    }
    
    // MARK: - Helpers
    private func setupNotifications()
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
            guard self?.resourceLinks?.contains(payload.cloudURL.absoluteString) == true else { return }
            self?.progressView?.isHidden = true
            self?.downloadInfo = nil
            self?.resourcesTableView?.reloadData()
        }
        
        NotificationCenter.default.addObserver(for: sessionDidProgressDownloading, object: nil, queue: .main)
        { [weak self] (payload) in
            guard self?.resourceLinks?.contains(payload.downloadURLValue) == true else { return }
            self?.progressView.progress = payload.progress
        }
        
        NotificationCenter.when(.UIApplicationDidEnterBackground)
        { [weak self](_) in
            guard let item = self?.avPlayerViewController.player?.currentItem,
                  let player = self?.avPlayerViewController.player,
                  let session = self?.session else { return }
            if item.duration.seconds - player.currentTime().seconds > 30.0
            {
                UserDefaults.standard.setVideoProgress(session, progress: item.currentTime().seconds)
            }
            else
            {
                UserDefaults.standard.setVideoProgress(session, progress: 0.0)
            }
        }
    }
    
    fileprivate func setPlayer(with url: URL)
    {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        avPlayerViewController.player = AVPlayer(playerItem: item)
        avPlayerViewController.player?.seek(to: CMTime(seconds: UserDefaults.standard.progress(session), preferredTimescale: CMTimeScale(1.0)))
        avPlayerViewController.player?.play()
        addObservers()
        avPlayerViewController.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main)
        { [weak self] (time) in
            guard let strongSelf = self,
                  let sessionResources = strongSelf.sessionResources else { return }
            if let nextSentence = sessionResources.transcript.sentences.first(where: { strongSelf.avPlayerViewController.player?.currentTime().seconds ?? 0.0 > $0.startTime && strongSelf.avPlayerViewController.player?.currentTime().seconds ?? 0.0 < $0.endTime }),
               let nextIndex = sessionResources.transcript.sentences.index(of: nextSentence)
            {
                let newIndex = IndexPath(row: nextIndex, section: 0)
                let lastCell = strongSelf.transcriptTableView?.cellForRow(at: strongSelf.transcriptIndex)
                lastCell?.textLabel?.textColor = strongSelf.lowLightColor
                let newCell = strongSelf.transcriptTableView?.cellForRow(at: newIndex)
                newCell?.textLabel?.textColor = strongSelf.highLightColor
                strongSelf.transcriptIndex = newIndex
                strongSelf.transcriptTableView?.scrollToRow(at: newIndex, at: .top, animated: true)
            }
        }
    }
    
    fileprivate func checkForDownload()
    {
        guard let session = self.session else { return }
        let context = PersistenceManager.sharedContainer.viewContext
        let fetchRequest: NSFetchRequest<DownloadInfo> = DownloadInfo.fetchRequest()
        do
        {
            let downloads = try context.fetch(fetchRequest)
            guard let download = downloads.first(where: { $0.session?.id == session.id }),
                  let downloadStatus = download.status else { return }
            if (downloadStatus == .completed || downloadStatus == .failed)
            {
                self.downloadInfo = download
            }
            progressView.isHidden = (downloadStatus == .completed || downloadStatus == .failed)
        }
        catch
        {
            print(error.localizedDescription)
        }
    }
    
    private func addObservers()
    {
        let options: NSKeyValueObservingOptions = [.new, .old, .initial]
        avPlayerViewController.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: options, context: &observerContext)
    }
    
    private func addQuickAction()
    {
        var quickActions = UIApplication.shared.shortcutItems ?? [UIApplicationShortcutItem]()
        guard !quickActions.contains(where: { $0.localizedTitle == self.session?.title }),
              let session = self.session else { return }
        if quickActions.count >= 4
        {
            quickActions = Array(quickActions.dropFirst())
        }
        let shortcut = UIApplicationShortcutItem(type: "session", localizedTitle: session.title, localizedSubtitle: session.year, icon: nil, userInfo: ["year": session.year, "session": session.session])
        quickActions.append(shortcut)
        UIApplication.shared.shortcutItems = quickActions
    }
    
    // MARK: - Actions
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
    
    func didPressDownload(sender: UIButton)
    {
        sender.alpha = 0.5
        sender.isEnabled = false
        self.progressView.isHidden = false
        let location = sender.convert(sender.bounds.origin, to: resourcesTableView)
        guard let indexPath = resourcesTableView.indexPathForRow(at: location),
              let resource = sessionResources?.sessionResources[indexPath.row],
              let session = self.session else { return  }
        DownloadController.shared.download(session: session, videoURL: resource.link)
    }
    
    func didPressTrash(sender: UIButton)
    {
        let location = sender.convert(sender.bounds.origin, to: resourcesTableView)
        guard let indexPath = resourcesTableView.indexPathForRow(at: location),
            let resource = sessionResources?.sessionResources[indexPath.row] else { return  }
        let context = PersistenceManager.sharedContainer.viewContext
        
        let fetchRequest: NSFetchRequest<DownloadInfo> = DownloadInfo.fetchRequest()
        do
        {
            let downloads = try context.fetch(fetchRequest)
            let download = downloads.first { $0.session?.id == session?.id }
            if let downloadInfo = download
            {
                context.delete(downloadInfo)
                try PersistenceManager.save(context: context)
            }
            try FileManager.default.removeItem(at: FileStorage().url(for: resource.link))
            resourcesTableView.reloadData()
        }
        catch
        {
            print(error.localizedDescription)
        }
    }
    
    func didPressShare()
    {
        guard let session = self.session else { return }
        let activityVC = UIActivityViewController(activityItems: [session.website], applicationActivities: nil)
        if let popoverController = activityVC.popoverPresentationController
        {
            popoverController.barButtonItem = shareBarButton
        }
        present(activityVC, animated: true)
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard keyPath == #keyPath(AVPlayer.rate) else { return }
        switch avPlayerViewController.player?.rate ?? 0.0
        {
        case (0.0 ..< 1.1):
            if let player = avPlayerViewController.player,
               let item = avPlayerViewController.player?.currentItem,
               let session = self.session,
               item.duration.seconds - player.currentTime().seconds < 30.0
            {
                UserDefaults.standard.setHasSeen(session)
                UserDefaults.standard.setVideoProgress(session, progress: 0.0)
                NotificationCenter.default.post(name: .WWSessionDidFinishWatching, object: nil, userInfo: ["year": session.year, "session": session.dictionaryRep])
            }
            segmentedControl.selectedSegmentIndex = 0
        case (1.1 ..< 1.6):
            segmentedControl.selectedSegmentIndex = 1
        case (1.6 ... 2.1):
            segmentedControl.selectedSegmentIndex = 2
        default:
            segmentedControl.selectedSegmentIndex = 0
        }
    }
    
    // MARK: - Networking
    func fetchResources()
    {
        guard let session = self.session,
              let resource = SessionResource.resource(for: session) else { return }
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        CachedWebservice.load(resource)
        { [weak self] (response) in
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
                        self?.sessionResources = resources
                        self?.resourceLinks = Set(self?.sessionResources?.sessionResources.map { $0.link.absoluteString } ?? [String]())
                    }
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension DetailViewController: UITableViewDelegate, UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int
    {
        guard tableView === resourcesTableView else { return 1 }
        switch self.searchState
        {
        case .normal:
            guard let sessionResources = self.sessionResources else { return 1 }
            return ResourceSections.sections(for: sessionResources).count
        case .searching:
            return 1
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard tableView === resourcesTableView else { return nil }
        switch self.searchState
        {
        case .normal:
            guard let sessionResources = self.sessionResources else { return nil }
            let section = ResourceSections.sections(for: sessionResources)[section]
            switch section
            {
            case .documents: return "Documents"
            case .downloads: return "Downloads"
            case .videos: return "Related Videos"
            }
        case .searching:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if tableView === resourcesTableView
        {
            switch searchState
            {
            case .normal:
                guard let sessionResources = self.sessionResources else { return 0 }
                let section = ResourceSections.sections(for: sessionResources)[section]
                switch section
                {
                case .documents(let documents):
                    return documents.count
                case .videos(let videos):
                    return videos.count
                case .downloads(let downloads):
                    return downloads.count
                }
            case .searching:
                return filteredSessionResources.count
            }
        }
        switch searchState
        {
        case .normal:
            return sessionResources?.transcript.sentences.count ?? 0
        case .searching:
            return filteredTranscript.count
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
                guard let sessionResources = self.sessionResources else
                {
                    sessionResource = nil
                    break
                }
                let section = ResourceSections.sections(for: sessionResources)[indexPath.section]
                switch section
                {
                case .documents(let documents):
                    sessionResource = documents[indexPath.row]
                case .videos(let videos):
                    sessionResource = videos[indexPath.row]
                case .downloads(let downloads):
                    sessionResource = downloads[indexPath.row]
                }
                
                cell.textLabel?.text = sessionResource?.title
            case .searching:
                sessionResource = filteredSessionResources[indexPath.row]
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
                    if downloadInfo != nil
                    {
                        button.alpha = 0.5
                        button.isEnabled = false
                    }
                }
                cell.accessoryType = .none
                cell.accessoryView = button
            }
            else
            {
                cell.accessoryView = nil
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
                sentence = filteredTranscript[indexPath.row]
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
                guard let sessionResources = self.sessionResources else
                {
                    selectedResource = nil
                    break
                }
                let section = ResourceSections.sections(for: sessionResources)[indexPath.section]
                switch section
                {
                case .documents(let documents):
                    selectedResource = documents[indexPath.row]
                case .videos(let videos):
                    let video = videos[indexPath.row]
                    let yearAndSession = self.yearAndSession(for: video.link)
                    switch yearAndSession
                    {
                    case (.some(let year), .some(let sessionString)):
                        self.actionDelegate?.showSession(for: year, session: sessionString)
                        return
                    default:
                        return
                    }
                case .downloads(let downloads):
                    selectedResource = downloads[indexPath.row]
                }
            case .searching:
                selectedResource = filteredSessionResources[indexPath.row]
                searchController.searchBar.resignFirstResponder()
            }
            guard let resource = selectedResource else { return }
            if resource.title.lowercased().contains("hd") || resource.title.lowercased().contains("sd")
            {
                UserDefaults.standard.setVideoProgress(session, progress: avPlayerViewController.player?.currentItem?.currentTime().seconds ?? 0.0)
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
                guard !resource.isRelativePath else { return }
                actionDelegate?.didPress(sessionResource: resource, in: self)
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
                selectedSentence = filteredTranscript[indexPath.row]
                searchController.searchBar.resignFirstResponder()
            }
            guard let sentence = selectedSentence else { return }
            let newTime = CMTime(seconds: sentence.startTime, preferredTimescale: 1)
            avPlayerViewController.player?.seek(to: newTime)
            transcriptIndex = indexPath
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    func yearAndSession(for url: URL) -> (year: String?, session: String?)
    {
        guard let sessionNumber = url.pathComponents.last else { return (nil, nil) }
        let sessionString = "Session \(sessionNumber)"
        let yearString = url.pathComponents.first(where: { $0.hasPrefix("wwdc") })
        guard let year = yearString?.components(separatedBy: "wwdc").last else { return (nil, sessionString) }
        return (year, sessionString)
    }
}

// MARK: - UIScrollViewDelegate
extension DetailViewController: UIScrollViewDelegate
{
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        guard scrollView === self.scrollView else { return }
        let factor: CGFloat = sessionResources?.transcript.sentences.isEmpty == true ? 2 : 3
        let offset = scrollView.contentOffset.x / view.bounds.width
        selectionIndicatorLeadinConstraint.constant = (scrollView.contentOffset.x + 8.0 - (8.0 * offset)) / factor
    }
}

// MARK: - UISearchResultsUpdating
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

// MARK: - UISearchControllerDelegate
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

// MARK: - AVPlayerViewControllerDelegate
extension DetailViewController: AVPlayerViewControllerDelegate
{
    func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error)
    {
        print(error)
    }
}

extension DetailViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard let indexPath = resourcesTableView.indexPathForRow(at: view.convert(location, to: resourcesTableView)) else { return nil }
        let resource: SessionResource?
        switch searchState
        {
        case .normal:
            resource = sessionResources?.sessionResources[indexPath.row]
        case .searching:
            resource = filteredSessionResources[indexPath.row]
        }
        return actionDelegate?.didForceTouch(sessionResource: resource, in: self)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        actionDelegate?.didCommitPreview(context: previewingContext, viewControllerToCommit: viewControllerToCommit, in: self)
    }
}

@available(iOS 11.0, *)
extension DetailViewController: UIDropInteractionDelegate
{
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool
    {
        return session.hasItemsConforming(toTypeIdentifiers: [kUTTypeURL as String])
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal
    {
        if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeURL as String])
        {
            return UIDropProposal(operation: .copy)
        }
        return UIDropProposal(operation: .forbidden)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession)
    {
        session.loadObjects(ofClass: NSURL.self)
        { (itemProviders) in
            guard let itemProvider = itemProviders.first as? NSURL else { return }
            let yearAndSession = self.yearAndSession(for: itemProvider as URL)
            DispatchQueue.main.async
            {
                guard yearAndSession.year != nil, yearAndSession.session != nil else
                {
                    
                    (UIApplication.shared.delegate as? AppDelegate)?.appCoordinator?.didPress(sessionResource: SessionResource(title: "", link: itemProvider as URL), in: self)
                    return
                }
                guard let actionDelegate = self.actionDelegate else
                {
                    (UIApplication.shared.delegate as? AppDelegate)?.appCoordinator?.showSession(for: yearAndSession.year!, session: yearAndSession.session!)
                    return
                }
                actionDelegate.showSession(for: yearAndSession.year!, session: yearAndSession.session!)
            }
        }
    }
}
