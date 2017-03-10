//
//  JKHBezierMenuContainerViewController.swift
//  JKHBezierMenu
//
//  Created by Joon Ki Hong on 2/21/17.
//  Copyright © 2017 Joon Ki Hong. All rights reserved.
//

import UIKit

extension UIView {
    func dg_center(usePresentationLayerIfPossible: Bool) -> CGPoint {
        if usePresentationLayerIfPossible, let presentationLayer = layer.presentation() {
            return presentationLayer.position
        }
        return center
    } 
}

extension Notification.Name {
    static let JKHBezierMenuToggleMenu = Notification.Name("JKHBezierMenuToggleNotification")
    static let JKHBezierMenuWillOpen = Notification.Name("JKHBezierMenuWillOpenNotification")
    static let JKHBezierMenuWillClose = Notification.Name("JKHBezierMenuWillCloseNotification")
    static let JKHBezierMenuDidOpen = Notification.Name("JKHBezierMenuDidOpenNotification")
    static let JKHBezierMenuDidClose = Notification.Name("JKHBezierMenuDidCloseNotification")
}

struct JKHBezierMenuConfiguration {
    var width: CGFloat
    var animSpringDamping: CGFloat
    var animDuration: TimeInterval
    var shouldShowControlPoints: Bool
    var innerControlPointRatio: CGFloat
    var outerControlPointDistance: CGFloat

    init(width: CGFloat, animSpringDamping: CGFloat=0.53, animDuration: TimeInterval=1.0, innerControlPointRatio: CGFloat=0.70, outerControlPointDistance: CGFloat=75, shouldShowControlPoints: Bool=true) {
        
        self.width = width
        self.animSpringDamping = animSpringDamping
        self.animDuration = animDuration
        self.shouldShowControlPoints = shouldShowControlPoints
        self.innerControlPointRatio = innerControlPointRatio
        self.outerControlPointDistance = outerControlPointDistance
        
    }
}

class JKHBezierMenuContainerViewController: UIViewController {
    
    fileprivate let menuBezierPathMaxWidth: CGFloat = 100
    fileprivate let u3ControlPointView = UIView()
    fileprivate let u2ControlPointView = UIView()
    fileprivate let u1ControlPointView = UIView()
    fileprivate let cControlPointView = UIView()
    fileprivate let l1ControlPointView = UIView()
    fileprivate let l2ControlPointView = UIView()
    fileprivate let l3ControlPointView = UIView()
    
    var menuViewController: UIViewController!
    var centerViewController: UIViewController!
    
    fileprivate var config: JKHBezierMenuConfiguration!
    fileprivate var tapToHideView: UIView!
    fileprivate var isMenuShowing = false
    fileprivate var menuShapeLayer = CAShapeLayer()
    fileprivate var menuMaskShapeLayer = CAShapeLayer()
    fileprivate var menuBezierPath = UIBezierPath()
    fileprivate var displayLink: CADisplayLink!
    
    fileprivate var isAnimating = false {
        didSet {
            view.isUserInteractionEnabled = !isAnimating
            displayLink.isPaused = !isAnimating
        }
    }
    
    convenience init(withCenterVC centerVC: UIViewController, menuVC: UIViewController, config: JKHBezierMenuConfiguration? = nil) {
        self.init(nibName:nil, bundle:nil)
        
        menuViewController = menuVC
        centerViewController = centerVC
        
        self.config = config ?? JKHBezierMenuConfiguration(width: 280)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupViews()
        setupNotifications()
        setupGestureRecognizers()
        updateViewConstraints()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        var constraints = [NSLayoutConstraint]()
        
        centerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        menuViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        constraints.append(NSLayoutConstraint(item: centerViewController.view, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0))
        constraints.append(NSLayoutConstraint(item: centerViewController.view, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0))
        constraints.append(NSLayoutConstraint(item: centerViewController.view, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: 0))
        constraints.append(NSLayoutConstraint(item: centerViewController.view, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0))
        
        constraints.append(NSLayoutConstraint(item: menuViewController.view, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0))
        constraints.append(NSLayoutConstraint(item: menuViewController.view, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0))
        constraints.append(NSLayoutConstraint(item: menuViewController.view, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: config.width))
        constraints.append(NSLayoutConstraint(item: menuViewController.view, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 0))

        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: - Setup
    
    fileprivate func setupGestureRecognizers() {
        
        let tapToHideGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureDetected))
        let panGR = UIPanGestureRecognizer(target: self, action: #selector(panGestureDetected))
        
        panGR.delegate = self
        
        tapToHideView = UIView(frame: centerViewController.view.frame)
        tapToHideView.backgroundColor = UIColor.black
        tapToHideView.alpha = 0.5
        
        tapToHideView.addGestureRecognizer(tapToHideGestureRecognizer)
        centerViewController.view.addGestureRecognizer(panGR)
        
    }
    
    fileprivate func setupViews() {
        
        let controlPointColor: UIColor = config.shouldShowControlPoints ? .red : .clear
        
        menuViewController.view.layer.mask = menuMaskShapeLayer
        view.addSubview(menuViewController.view)
        addChildViewController(menuViewController)
        menuViewController.didMove(toParentViewController: self)

        view.addSubview(centerViewController.view)
        addChildViewController(centerViewController)
        centerViewController.didMove(toParentViewController: self)
        
        menuShapeLayer.frame = CGRect(x: 0, y: 0, width: self.config.width, height: UIScreen.main.bounds.height)
        menuMaskShapeLayer.frame = CGRect(x: 0, y: 0, width: self.config.width, height: UIScreen.main.bounds.height)
        menuShapeLayer.actions = ["position": NSNull(), "bounds" : NSNull(), "path" : NSNull()]
        menuShapeLayer.fillColor = menuViewController.view.backgroundColor?.cgColor
        view.layer.insertSublayer(menuShapeLayer, above: centerViewController.view.layer)
        
        l3ControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        l2ControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        l1ControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        cControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        u1ControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        u2ControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        u3ControlPointView.frame = CGRect(x: 0, y: 0, width: 3, height: 3)
        
        l3ControlPointView.backgroundColor = controlPointColor
        l2ControlPointView.backgroundColor = controlPointColor
        l1ControlPointView.backgroundColor = controlPointColor
        cControlPointView.backgroundColor = controlPointColor
        u1ControlPointView.backgroundColor = controlPointColor
        u2ControlPointView.backgroundColor = controlPointColor
        u3ControlPointView.backgroundColor = controlPointColor
        
        view.addSubview(l3ControlPointView)
        view.addSubview(l2ControlPointView)
        view.addSubview(l1ControlPointView)
        view.addSubview(cControlPointView)
        view.addSubview(u1ControlPointView)
        view.addSubview(u2ControlPointView)
        view.addSubview(u3ControlPointView)
        
        layoutControlPoints(baseWidth: 0, waveWidth: 0, locationY: view.bounds.height / 2.0)
        updateShapeLayers()
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateShapeLayers))
        displayLink.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        displayLink.isPaused = true
    }
    
    fileprivate func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(toggleMenu), name: .JKHBezierMenuToggleMenu, object: nil)
    }
    
    // MARK: - Gestures
    
    func tapGestureDetected(gesture:UITapGestureRecognizer) {
        animateMenu()
    }
    
    func panGestureDetected(gesture:UIPanGestureRecognizer) {
        
        let touch = gesture.location(in: view)
        let translation = gesture.translation(in: view)
        
        if gesture.state == .ended || gesture.state == .failed || gesture.state == .cancelled {
            if isMenuShowing {
                if translation.x < 0 && touch.x < 2.0 * config.width / 3.0 {
                    animateMenu()
                    return
                }
            } else {
                if touch.x > view.bounds.maxX / 3.0 {
                    animateMenu()
                    return
                }
            }
            returnMenuShapeLayerToNormalState()
        } else {
            let additionalWidth = !isMenuShowing ? max(gesture.translation(in: view).x, 0) : gesture.translation(in: view).x
            let waveWidth = min(additionalWidth * 0.6, menuBezierPathMaxWidth)
            let baseWidth = !isMenuShowing ? additionalWidth - waveWidth : config.width + waveWidth
            let locationY = gesture.location(in: gesture.view).y
            
            layoutControlPoints(baseWidth: baseWidth, waveWidth: waveWidth, locationY: locationY)
            
            updateShapeLayers()
        }
    }
    
    // MARK: - Menu
    
    fileprivate func animateMenu() {
        guard !isAnimating else { return }
        
        isAnimating = true

        if isMenuShowing {
            menuViewController.viewWillDisappear(true)
            NotificationCenter.default.post(name: .JKHBezierMenuWillClose, object: self)
            self.view.sendSubview(toBack: self.menuViewController.view)
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: self.config.animDuration, delay: 0.0, usingSpringWithDamping: self.config.animSpringDamping, initialSpringVelocity: 0.0, options: [], animations: { () -> Void in
                    
                    self.u3ControlPointView.center.x = 0
                    self.u2ControlPointView.center.x = 0
                    self.u1ControlPointView.center.x = 0
                    self.cControlPointView.center.x = 0
                    self.l1ControlPointView.center.x = 0
                    self.l2ControlPointView.center.x = 0
                    self.l3ControlPointView.center.x = 0
                    self.tapToHideView.alpha = 0.0
                    
                }, completion: { _ in
                    self.isAnimating = false
                    self.tapToHideView.removeFromSuperview()
                    self.menuViewController.viewDidDisappear(true)
                    NotificationCenter.default.post(name: .JKHBezierMenuDidClose, object: self)
                })
            }
            
        } else {

            menuViewController.viewWillAppear(true)
            NotificationCenter.default.post(name: .JKHBezierMenuWillOpen, object: self)
            
            tapToHideView.frame = self.centerViewController.view.frame
            tapToHideView.removeFromSuperview()
            centerViewController.view.addSubview(tapToHideView)
            
            DispatchQueue.main.async {
                self.view.bringSubview(toFront: self.menuViewController.view)
                UIView.animate(withDuration: self.config.animDuration, delay: 0.0, usingSpringWithDamping: self.config.animSpringDamping, initialSpringVelocity: 0.0, options: [], animations: { () -> Void in
                    
                    self.u3ControlPointView.center.x = self.config.width
                    self.u2ControlPointView.center.x = self.config.width
                    self.u1ControlPointView.center.x = self.config.width
                    self.cControlPointView.center.x = self.config.width
                    self.l1ControlPointView.center.x = self.config.width
                    self.l2ControlPointView.center.x = self.config.width
                    self.l3ControlPointView.center.x = self.config.width
                    self.tapToHideView.alpha = 0.5
                    
                }, completion: { _ in
                    self.isAnimating = false
                    self.menuViewController.viewDidAppear(true)
                    NotificationCenter.default.post(name: .JKHBezierMenuDidOpen, object: self)
                })
            }
        }
        
        isMenuShowing = !isMenuShowing
    }
}

// MARK: - UIGestureRecognizerDelegate

extension JKHBezierMenuContainerViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let panGR = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        
        let touch = panGR.location(in: centerViewController.view)
        let translation = panGR.translation(in: centerViewController.view)
        let screenWidth = view.bounds.width
        
        if touch.x < screenWidth / 4.0 && !isMenuShowing {
            return true
        } else if touch.x > config.width && translation.x < 0 && isMenuShowing {
            return true
        }
        
        return false
    }
    
}

// MARK: - Menu Layer Helpers

extension JKHBezierMenuContainerViewController {
    
    func updateShapeLayers() {
        menuShapeLayer.path = currentBezierPath()
        menuMaskShapeLayer.path = currentBezierPath()
    }
    
    fileprivate func currentBezierPath() -> CGPath {
        let height = view.bounds.height
        let bezierPath = UIBezierPath()
        
        bezierPath.move(to: .zero)
        bezierPath.addLine(to: CGPoint(x: u3ControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating).x, y: 0))
        bezierPath.addCurve(to: cControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating), controlPoint1: u2ControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating), controlPoint2: u1ControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating))
        bezierPath.addCurve(to: l3ControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating), controlPoint1: l1ControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating), controlPoint2: l2ControlPointView.dg_center(usePresentationLayerIfPossible: isAnimating))
        bezierPath.addLine(to: CGPoint(x: 0, y: height))
        
        bezierPath.close()
        
        return bezierPath.cgPath 
    }
    
    fileprivate func layoutControlPoints(baseWidth: CGFloat, waveWidth: CGFloat, locationY: CGFloat) {
        let minUpperY: CGFloat = 0
        let maxLowerY = view.bounds.height
        let endPointX = isMenuShowing ? config.width : 0.0
        
        u3ControlPointView.center = CGPoint(x: endPointX, y: minUpperY)
        u2ControlPointView.center = CGPoint(x: baseWidth, y: locationY * config.innerControlPointRatio)
        u1ControlPointView.center = CGPoint(x: baseWidth + waveWidth, y: locationY - config.outerControlPointDistance)
        cControlPointView.center  = CGPoint(x: baseWidth + waveWidth, y: locationY)
        l1ControlPointView.center = CGPoint(x: baseWidth + waveWidth, y: locationY + config.outerControlPointDistance)
        l2ControlPointView.center = CGPoint(x: baseWidth, y: locationY + (maxLowerY - locationY) * (1.0 - config.innerControlPointRatio))
        l3ControlPointView.center = CGPoint(x: endPointX, y: maxLowerY)
    }
    
    fileprivate func returnMenuShapeLayerToNormalState() {
        guard !isAnimating else { return }
        isAnimating = true
        UIView.animate(withDuration: self.config.animDuration, delay: 0.0, usingSpringWithDamping: self.config.animSpringDamping, initialSpringVelocity: 0.0, options: [], animations: { () -> Void in
            
            self.u3ControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            self.u2ControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            self.u1ControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            self.cControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            self.l1ControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            self.l2ControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            self.l3ControlPointView.center.x = self.isMenuShowing ? self.config.width : 0
            
        }, completion: { _ in
            self.isAnimating = false
        })

    }
    
}

// MARK: - Public API

extension JKHBezierMenuContainerViewController {
    
    func toggleMenu() {
        animateMenu()
    }
    
}
