//
//  ViewController.swift
//  LockSearch
//
//  Created by [Andy Ron](https://github.com/andyRon)  on 2018/12/4.
//  Copyright © 2018 [Andy Ron](https://github.com/andyRon) . All rights reserved.
//


// image by NASA: https://www.flickr.com/photos/nasacommons/29193068676/

import UIKit

class LockScreenViewController: UIViewController {

  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var dateTopConstraint: NSLayoutConstraint!

  let blurView = UIVisualEffectView(effect: nil)

  var settingsController: SettingsViewController!
  
  var startFrame: CGRect?
  var previewView: UIView?
  var previewAnimator: UIViewPropertyAnimator?
  
  let previewEffectView = IconEffectView(blur: .extraLight)
  
  // 转场
  let presentTransition = PresentTransition()
  
  // 手势
  var isDragging = false
  var isPresentingSettings = false
  
  var touchesStartPointY: CGFloat?

  override func viewDidLoad() {
    super.viewDidLoad()

    view.bringSubview(toFront: searchBar)
//    blurView.effect = UIBlurEffect(style: .dark)
//    blurView.alpha = 0
    blurView.isUserInteractionEnabled = false
    view.insertSubview(blurView, belowSubview: searchBar)

    tableView.estimatedRowHeight = 130.0
    tableView.rowHeight = UITableViewAutomaticDimension
    

  }

  override func viewWillLayoutSubviews() {
    blurView.frame = view.bounds
    
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  override func viewWillAppear(_ animated: Bool) {
    tableView.transform = CGAffineTransform(scaleX: 0.67, y: 0.67)
    tableView.alpha = 0
    
    dateTopConstraint.constant -= 100
    view.layoutIfNeeded()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    AnimatorFactory.scaleUp(view: tableView).startAnimation()
    
    AnimatorFactory.animateConstraint(view: view, constraint: dateTopConstraint, by: 150).startAnimation()
  }

  @IBAction func presentSettings(_ sender: Any? = nil) {
    //present the view controller
    presentTransition.auxAnimations = blurAnimations(true)
    presentTransition.auxAnimationsCancel = blurAnimations(false)
    
    settingsController = storyboard?.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
    settingsController.transitioningDelegate = self
    
    settingsController.didDismiss = { [unowned self] in
      self.toggleBlur(false)
    }
    
    present(settingsController, animated: true, completion: nil)
  }
  
  func toggleBlur(_ blurred: Bool) {
//    AnimatorFactory.fade(view: blurView, visible: blurred)
//    UIViewPropertyAnimator(duration: 0.55, curve: .easeIn, animations: blurAnimations(blurred)).startAnimation()
    UIViewPropertyAnimator(duration: 0.55, controlPoint1: CGPoint(x: 0.57, y: -0.4), controlPoint2: CGPoint(x: 0.96, y: 0.87), animations: blurAnimations(blurred)).startAnimation()
  }
  
  func blurAnimations(_ blured: Bool) -> () -> Void {
    return {
      self.blurView.effect = blured ? UIBlurEffect(style: .dark) : nil
      self.tableView.transform = blured ? CGAffineTransform(scaleX: 0.75, y: 0.75) : .identity
      self.tableView.alpha = blured ? 0.33 : 1.0
    }
  }
  
  func addEffectView(below forView: UIView) {
    previewEffectView.removeFromSuperview()
    previewEffectView.frame = forView.frame
    
    forView.superview?.insertSubview(previewEffectView, belowSubview: forView)
  }
  
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard presentTransition.wantsInteractiveStart == false, presentTransition.animator != nil else {
      return
    }
    
    touchesStartPointY = touches.first!.location(in: view).y
    presentTransition.interruptTransition()
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let startY = touchesStartPointY else { return }
    
    let currentPoint = touches.first!.location(in: view).y
    if currentPoint < startY - 40 {
      touchesStartPointY = nil
      presentTransition.animator?.addCompletion({ (_) in
        self.blurView.effect = nil
      })
      presentTransition.cancel()
      
    } else if currentPoint > startY + 40 {
      touchesStartPointY = nil
      presentTransition.finish()
    }
  }
}

// MARK: - WidgetsOwnerProtocol
extension LockScreenViewController: WidgetsOwnerProtocol {
  
  func startPreview(for forView: UIView) {
    previewView?.removeFromSuperview()
    previewView = forView.snapshotView(afterScreenUpdates: false)
    view.insertSubview(previewView!, aboveSubview: blurView)
    
    previewView?.frame = forView.convert(forView.bounds, to: view)
    startFrame = previewView?.frame
    addEffectView(below: previewView!)
    
    previewAnimator = AnimatorFactory.grow(view: previewEffectView, blurView: blurView)
  }
  
  func updatePreview(percent: CGFloat) {
    previewAnimator?.fractionComplete = max(0.01, min(0.99, percent))
  }
  
  func cancelPreview() {
    if let previewAnimator = previewAnimator {
      previewAnimator.isReversed = true
      previewAnimator.startAnimation()
      
      previewAnimator.addCompletion { (position) in
        switch position {
        case .start:
          self.previewView?.removeFromSuperview()
          self.previewEffectView.removeFromSuperview()
        default:
          break
        }
      }
      
    }
  }
  
  func finishPreview() {
    
    previewAnimator?.stopAnimation(false)
    
    previewAnimator?.finishAnimation(at: .end)
    
    previewAnimator = nil
    
    AnimatorFactory.complete(view: previewEffectView).startAnimation()
    
    blurView.effect = UIBlurEffect(style: .dark)
    blurView.isUserInteractionEnabled = true
    blurView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissMenu)))
  }
  
  @objc func dismissMenu() {
    let reset = AnimatorFactory.reset(frame: startFrame!, view: previewEffectView, blurView: blurView)
    reset.addCompletion { (_) in
      self.previewEffectView.removeFromSuperview()
      self.previewView?.removeFromSuperview()
      self.blurView.isUserInteractionEnabled = false
    }
    reset.startAnimation()
  }
  
}

// MARK: - UITableViewDataSource
extension LockScreenViewController: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 2
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.row == 1 {
      let cell = tableView.dequeueReusableCell(withIdentifier: "Footer") as! FooterCell
      cell.didPressEdit = {[unowned self] in
        self.presentTransition.wantsInteractiveStart = false
        self.presentSettings()
      }
      return cell
    } else {
      let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! WidgetCell
      cell.tableView = tableView
      cell.owner = self
      return cell
    }
  }
}

// MARK: - UISearchBarDelegate
extension LockScreenViewController: UISearchBarDelegate {
  
  func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
    toggleBlur(true)
  }
  
  func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    toggleBlur(false)
  }
  
  func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
    searchBar.resignFirstResponder()
  }
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    if searchText.isEmpty{
      searchBar.resignFirstResponder()
    }
  }
}

// MARK: - UIViewControllerTransitioningDelegate
extension LockScreenViewController: UIViewControllerTransitioningDelegate {
  
  func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return presentTransition
  }
  // 让UIKit知道在视图控制器演示期间计划一些有趣的交互性
  func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return presentTransition
  }
}

// MARK: -
extension LockScreenViewController: UIScrollViewDelegate {
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    isDragging = true
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard isDragging else { return }
    
    if !isPresentingSettings && scrollView.contentOffset.y < -30 {
      isPresentingSettings = true
      presentTransition.wantsInteractiveStart = true
      presentSettings()
      return
    }
    
    if isPresentingSettings {
      let progess = max(0.0, min(1.0, ((-scrollView.contentOffset.y) - 30) / 90.0))
      presentTransition.update(progess)
    }
  }
  
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    let progress = max(0.0, min(1.0, ((-scrollView.contentOffset.y) - 30) / 90.0))
    
    if progress > 0.5 {
      presentTransition.finish()
    } else {
      presentTransition.cancel()
    }
    
    isPresentingSettings = false
    isDragging = false
  }
}
