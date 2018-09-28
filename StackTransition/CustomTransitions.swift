import UIKit


class FirstViewController: UIViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.modalPresentationStyle = .custom
        segue.destination.modalPresentationCapturesStatusBarAppearance = true
        segue.destination.transitioningDelegate = slideTransition
    }
    
    @IBAction func unwindToFirst(_ segue: UIStoryboardSegue) {}
    
    let slideTransition = VerticalSlideTransition()
}


class SecondViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.modalPresentationCapturesStatusBarAppearance = true
    }
    
    @IBAction func pan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began, let slideTransition = transitioningDelegate as? VerticalSlideTransition {
            slideTransition.panGesture = gesture
            print( gesture.location(in: self.view) )
            dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func unwindToSecond(_ segue: UIStoryboardSegue) {}
}


class VerticalSlideTransition: UIPercentDrivenInteractiveTransition {
    
    enum Mode {
        case present, dismiss
    }
    var mode = Mode.present
    
    var isPresenting: Bool { return mode == .present }
    
    var panGesture: UIPanGestureRecognizer? {
        didSet {
            print("true")
            isInteractive = true
            panGesture?.addTarget(self, action: #selector(handlePanGesture(_:)))
         }
    }
    
    var isInteractive = false
    
    fileprivate var transitionContext: UIViewControllerContextTransitioning?
}

 extension VerticalSlideTransition: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        guard let view = transitionContext.view(forKey: isPresenting ? .to : .from)
            , let viewController = transitionContext.viewController(forKey: isPresenting ? .to : .from)
            else { fatalError() }
        
         transitionContext.containerView.addSubview(view)
       
        let frame = isPresenting ?
            transitionContext.finalFrame(for: viewController) :
            transitionContext.initialFrame(for: viewController)
        
        // Starting frame
        if isPresenting {
            view.frame = frame.offsetBy(dx: 0, dy: frame.height) // start offscreen
        } else {
            view.frame = frame // start onscreen
        }
        
        // End frame
        let animations = {
            if self.isPresenting {
                view.frame = frame // end onscreen
            } else {
                view.frame = frame.offsetBy(dx: 0, dy: frame.height) // end offscreen
            }
        }
        
        let completion: ((Bool) -> Void) = { _ in
            let success = !transitionContext.transitionWasCancelled
            
            
            if !success && self.isPresenting || success && !self.isPresenting {
                view.removeFromSuperview()
            }
            
           
            transitionContext.completeTransition(success)
        }
        
        let duration = transitionDuration(using: transitionContext)
        
        UIView.animate(withDuration: duration, delay: 0, options: [], animations: animations, completion: completion)
    }
}

extension VerticalSlideTransition: UIViewControllerTransitioningDelegate {
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CustomPresentation(presentedViewController: presented, presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        mode = .present
        print("presnt")
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        mode = .dismiss
        return self
    }
    
    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if isInteractive {
            return self
        }
        return nil
    }
}

// MARK: Interactive transition
extension VerticalSlideTransition {
    
    override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
        super.startInteractiveTransition(transitionContext)
    }
    
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {

        guard let transitionContext = transitionContext else { return }
        let translation = gesture.translation(in: transitionContext.containerView)  
        print(translation)
        let percentage = translation.y / transitionContext.containerView.bounds.height
        let threshold: CGFloat = 0.2 // 20% down
        
        switch gesture.state {
        case .began: break // Handeled by view controller
        case .changed: update(percentage)
        case .ended:
            if percentage < threshold { fallthrough } // cancel
            
            finish()
            isInteractive = false
        default:
            cancel()
            isInteractive = false
        }
    }
}

class MyNavigationController: UINavigationController {
    
    let transition = GrowTransition()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = transition
    }
}

class GrowTransition: NSObject, UIViewControllerAnimatedTransitioning, UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.operation = operation
        return self
    }
    
    private var operation: UINavigationControllerOperation!
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController = transitionContext.viewController(forKey: .from)
            , let toViewController = transitionContext.viewController(forKey: .to)
            , let fromView = transitionContext.view(forKey: .from)
            , let toView = transitionContext.view(forKey: .to)
            else { fatalError() }
        
        
        // Setup required frames
        fromView.frame = transitionContext.initialFrame(for: fromViewController)
        toView.frame = transitionContext.finalFrame(for: toViewController)
        
        // Use transform for animations
        let zeroScale = CGAffineTransform(scaleX: 0.01, y: 0.01)
        
        // Start scale
        if self.operation == .push {
            toView.transform = zeroScale // grow from center
            transitionContext.containerView.addSubview(toView)
        } else {
            fromView.transform = .identity // shrink from fullscreen
            transitionContext.containerView.insertSubview(toView, belowSubview: fromView)
        }
        
        // End scale
        let animations = {
            if self.operation == .push {
                toView.transform = .identity // grow to fullscreen
            } else {
                fromView.transform = zeroScale // shrink to center
            }
        }
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: [], animations: animations, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
        })
    }
}
 
class MyTabBarController: UITabBarController {
    
    let transition = HorizonalSlideTransition()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        delegate = transition
    }
}

class HorizonalSlideTransition: NSObject, UIViewControllerAnimatedTransitioning, UITabBarControllerDelegate {
    
    enum Direction {
        case forward, backwards
    }
    var direction = Direction.forward
    
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        guard let fromIndex = tabBarController.viewControllers?.index(of: fromVC)
            , let toIndex = tabBarController.viewControllers?.index(of: toVC)
            else { fatalError() }
        
        if toIndex > fromIndex { direction = .forward }
        else { direction = .backwards }
        
        return self
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController = transitionContext.viewController(forKey: .from)
            , let toViewController = transitionContext.viewController(forKey: .to)
            , let fromView = transitionContext.view(forKey: .from)
            , let toView = transitionContext.view(forKey: .to)
            else { fatalError() }
        
        transitionContext.containerView.addSubview(toView)
        
        // Setup required frames
        fromView.frame = transitionContext.initialFrame(for: fromViewController)
        toView.frame = transitionContext.finalFrame(for: toViewController)
        
        let width = transitionContext.containerView.bounds.width + 10
        let transform: CGAffineTransform
        
         if direction == .forward {
            transform = CGAffineTransform(translationX: -width, y: 0)
            
        } else {
            transform = CGAffineTransform(translationX: width, y: 0)
        }
        
         toView.transform = transform.inverted() // start offscreen
        fromView.transform = .identity // start onscreen
        
         let animations = {
            toView.transform = .identity // end onscreen
            fromView.transform = transform // end offscreen
        }
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: [], animations: animations, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
            fromView.transform = .identity
        })
    }
}
