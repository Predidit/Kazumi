import UIKit
import Flutter
import Darwin

/// Wait for UIKit's initial root appearance before changing containment.
/// The superclass remains responsible for Flutter's surface and scene lifecycle.
@objc(KazumiFlutterViewController)
final class KazumiFlutterViewController: FlutterViewController {
    private(set) var hasAppeared = false
    private(set) var appearanceTarget: Bool?
    var onFirstAppearance: (() -> Void)?

    override func viewWillAppear(_ animated: Bool) {
        appearanceTarget = true
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        appearanceTarget = false
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appearanceTarget = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearanceTarget = nil
        hasAppeared = true
        if let callback = onFirstAppearance {
            onFirstAppearance = nil
            DispatchQueue.main.async(execute: callback)
        }
    }
}

/// Native container bars, rather than a Flutter-drawn imitation, let UIKit
/// choose the correct axis and reserved region for every iPhone Duo pose.
@available(iOS 27.1, *)
final class DuoNavigationBridge {
    private let channel: FlutterMethodChannel
    private var controller: DuoNavigationHost?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.predidit.kazumi/duo_navigation", binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(false) }
            switch call.method {
            case "enable":
                self.enable(result)
            case "chrome":
                guard let args = call.arguments as? [String: Any] else {
                    return result(FlutterError(code: "arguments", message: "Invalid page chrome", details: nil))
                }
                self.controller?.applyChrome(args)
                result(nil)
            case "update":
                guard let args = call.arguments as? [String: Any],
                      let index = args["index"] as? Int,
                      (0..<4).contains(index),
                      let visible = args["visible"] as? Bool,
                      let dark = args["dark"] as? Bool else {
                    return result(FlutterError(code: "arguments", message: "Invalid navigation state", details: nil))
                }
                self.controller?.selectedIndex = index
                self.controller?.setTabBarHidden(!visible, animated: false)
                if visible {
                    self.controller?.overrideUserInterfaceStyle = dark ? .dark : .light
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func enable(_ result: @escaping FlutterResult) {
        guard Self.isDuo else { return result(false) }
        if controller != nil { return result(true) }
        // Dart initializes this after startup, before building its navigation widgets.
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }),
              let flutter = window.rootViewController as? FlutterViewController else {
            return result(false)
        }
        if let source = flutter as? KazumiFlutterViewController, !source.hasAppeared {
            source.onFirstAppearance = { [weak self] in
                guard let self else { return result(false) }
                self.enable(result)
            }
            return
        }
        // Detach the old window root before child containment; UIKit forbids
        // adding a window root as a child of another controller.
        // Do not reinstall a launch placeholder when UIKit reattaches the
        // Flutter view inside the adaptive native containers.
        flutter.splashScreenView = nil
        window.rootViewController = nil
        flutter.view.removeFromSuperview()
        // Finish removal of the old window root before beginning the shared
        // container's appearance transition on the next main-queue turn.
        DispatchQueue.main.async { [self] in
            let tabs = DuoNavigationHost(flutter: flutter)
            tabs.onSelected = { [weak self] index in
                self?.channel.invokeMethod("select", arguments: index)
            }
            tabs.onChromeAction = { [weak self] owner, identifier in
                self?.channel.invokeMethod("chromeAction", arguments: ["owner": owner, "id": identifier])
            }
            window.rootViewController = tabs
            controller = tabs
            result(true)
        }
    }

    private static var isDuo: Bool {
        // Deliberately an allowlist: no other iPhone, iPad, or future model
        // changes navigation. The simulator supplies the represented model.
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone19,4"
        #else
        var system = utsname()
        uname(&system)
        let identifier = withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return identifier == "iPhone19,4"
        #endif
    }
}

// Empty native content must pass touches through to Flutter beneath it.
private final class DuoChromeOverlay: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        var candidate: UIView? = hit
        while let current = candidate, current !== self {
            if current is UIControl || current is UINavigationBar || current is UITabBar {
                return hit
            }
            candidate = current.superview
        }
        return nil
    }
}

@available(iOS 27.1, *)
private final class DuoNavigationHost: UIViewController, UITabBarControllerDelegate {
    private let flutter: FlutterViewController
    private let tabs = UITabBarController()
    private let overlay = DuoChromeOverlay()
    private var immersive = false
    private var requestedTabBarHidden = true
    private lazy var navigation = UINavigationController(rootViewController: tabs)
    var onChromeAction: ((Int, String) -> Void)?
    var onSelected: ((Int) -> Void)?

    var selectedIndex: Int {
        get { tabs.selectedIndex }
        set { tabs.selectedIndex = newValue }
    }

    func setTabBarHidden(_ hidden: Bool, animated: Bool) {
        requestedTabBarHidden = hidden
        tabs.setTabBarHidden(hidden || immersive, animated: animated)
        view.setNeedsLayout()
    }

    init(flutter: FlutterViewController) {
        self.flutter = flutter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabs.delegate = self
        tabs.mode = .tabBar
        tabs.tabBarMinimizeBehavior = .never
        let items = [("推荐", "house"), ("时间表", "calendar"),
                     ("追番", "heart"), ("我的", "gearshape")]
        tabs.viewControllers = items.enumerated().map { index, item in
            let page = UIViewController()
            page.tabBarItem = UITabBarItem(
                title: item.0, image: UIImage(systemName: item.1), tag: index
            )
            return page
        }
        tabs.setTabBarHidden(true, animated: false)
        navigation.setNavigationBarHidden(true, animated: false)
        addChild(navigation)
        navigation.view.translatesAutoresizingMaskIntoConstraints = false
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
        overlay.addSubview(navigation.view)
        navigation.view.backgroundColor = .clear
        tabs.view.backgroundColor = .clear
        NSLayoutConstraint.activate([
            navigation.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigation.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigation.view.topAnchor.constraint(equalTo: view.topAnchor),
            navigation.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        navigation.didMove(toParent: self)

        // Sibling containment keeps one Flutter engine/router mounted across
        // native tab switches. Adding Flutter to the tab controller itself
        // would make UIKit treat it as an additional, untitled tab.
        addChild(flutter)
        flutter.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        flutter.view.frame = view.bounds
        view.insertSubview(flutter.view, belowSubview: overlay)
        flutter.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        navigation.view.layoutIfNeeded()
        overlay.isHidden = immersive
        if immersive {
            flutter.view.frame = view.bounds
            return
        }
        // UINavigationController attaches its root lazily. Read the native
        // content guide after layout, rather than constraining across a view
        // hierarchy that may not yet contain the tab controller.
        if tabs.viewIfLoaded?.superview != nil {
            var frame = tabs.view.convert(tabs.contentLayoutGuide.layoutFrame, to: view)
            // Keep actual bottom bars out of the viewport, but let Flutter
            // paint through the home-indicator safe area. Flutter receives
            // that inset itself for positioning its interactive controls.
            if frame.maxY >= view.bounds.maxY - view.safeAreaInsets.bottom - 1 {
                frame.size.height = view.bounds.maxY - frame.minY
            }
            // Vertical controls reserve a side column, not a top band. The
            // content guide may still include top safe-area/layout margins;
            // let Flutter paint those rather than cropping the entire view.
            if !occupiesTop(navigation.navigationBar, hidden: navigation.isNavigationBarHidden)
                && !occupiesTop(tabs.tabBar, hidden: tabs.isTabBarHidden) {
                let bottom = frame.maxY
                frame.origin.y = view.bounds.minY
                frame.size.height = bottom - frame.minY
            }
            // Paint backgrounds beneath the adaptive side controls. Flutter's
            // safe-area insets keep foreground controls out of that region.
            frame.origin.x = view.bounds.minX
            frame.size.width = view.bounds.width
            if !frame.isEmpty { flutter.view.frame = frame }
        }
    }

    private func occupiesTop(_ bar: UIView, hidden: Bool) -> Bool {
        let rect = bar.convert(bar.bounds, to: view)
        return !hidden && rect.height > 1 && rect.width > rect.height
            && rect.intersects(view.bounds) && rect.midY < view.bounds.midY
    }

    func applyChrome(_ args: [String: Any]) {
        loadViewIfNeeded()
        immersive = args["immersive"] as? Bool ?? false
        let visible = (args["visible"] as? Bool ?? false) && !immersive
        let owner = args["owner"] as? Int ?? 0
        // Page titles remain in Flutter content; only navigation controls
        // belong to the adaptive native bar. A UIKit title creates a second
        // horizontal title region above the Flutter viewport on Duo.
        tabs.navigationItem.title = nil
        tabs.navigationItem.largeTitleDisplayMode = .never
        navigation.navigationBar.prefersLargeTitles = false
        if visible {
            overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
        }
        let leading = args["leading"] as? [String: Any]
        tabs.navigationItem.leftBarButtonItem = leading.map { barItem($0, owner: owner) }
        let actions = args["actions"] as? [[String: Any]] ?? []
        // UIKit's trailing items are supplied from the outer edge inward.
        tabs.navigationItem.rightBarButtonItems = actions.reversed().map { barItem($0, owner: owner) }
        navigation.setNavigationBarHidden(!visible, animated: false)
        tabs.setTabBarHidden(requestedTabBarHidden || immersive, animated: false)
        view.setNeedsLayout()
    }

    private func barItem(_ spec: [String: Any], owner: Int) -> UIBarButtonItem {
        let title = spec["label"] as? String ?? ""
        let image = (spec["symbol"] as? String).flatMap { UIImage(systemName: $0) }
        let menu = (spec["menu"] as? [[String: Any]]).map { menuItems($0, owner: owner) }
        let item = UIBarButtonItem(title: title, image: image,
                                   primaryAction: menu == nil ? action(spec, owner: owner) : nil,
                                   menu: menu)
        item.isEnabled = spec["enabled"] as? Bool ?? false
        item.accessibilityLabel = title
        return item
    }

    private func action(_ spec: [String: Any], owner: Int) -> UIAction {
        let identifier = spec["id"] as? String ?? ""
        var attributes: UIMenuElement.Attributes = []
        if !(spec["enabled"] as? Bool ?? false) { attributes.insert(.disabled) }
        if spec["destructive"] as? Bool == true { attributes.insert(.destructive) }
        return UIAction(
            title: spec["label"] as? String ?? "",
            image: (spec["symbol"] as? String).flatMap { UIImage(systemName: $0) },
            attributes: attributes,
            state: spec["selected"] as? Bool == true ? .on : .off
        ) { [weak self] _ in self?.onChromeAction?(owner, identifier) }
    }

    private func menuItems(_ specs: [[String: Any]], owner: Int) -> UIMenu {
        UIMenu(children: specs.map { spec -> UIMenuElement in
            if let children = spec["menu"] as? [[String: Any]] {
                return UIMenu(title: spec["label"] as? String ?? "",
                              children: menuItems(children, owner: owner).children)
            }
            return action(spec, owner: owner)
        })
    }

    // Forward explicitly: Flutter's surface lifecycle must follow this shared
    // container rather than the empty controller selected by UIKit's tabs.
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigation.beginAppearanceTransition(true, animated: animated)
        beginFlutterAppearance(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigation.endAppearanceTransition()
        endFlutterAppearance(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigation.beginAppearanceTransition(false, animated: animated)
        beginFlutterAppearance(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigation.endAppearanceTransition()
        endFlutterAppearance(false)
    }

    private func beginFlutterAppearance(_ appearing: Bool, animated: Bool) {
        if let source = flutter as? KazumiFlutterViewController,
           let pending = source.appearanceTarget {
            if pending == appearing { return }
            flutter.endAppearanceTransition()
        }
        flutter.beginAppearanceTransition(appearing, animated: animated)
    }

    private func endFlutterAppearance(_ appearing: Bool) {
        if let source = flutter as? KazumiFlutterViewController,
           source.appearanceTarget != appearing { return }
        flutter.endAppearanceTransition()
    }

    override var childForStatusBarStyle: UIViewController? { flutter }
    override var childForStatusBarHidden: UIViewController? { flutter }
    override var childForHomeIndicatorAutoHidden: UIViewController? { flutter }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? { flutter }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        flutter.supportedInterfaceOrientations
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          didSelect viewController: UIViewController) {
        onSelected?(tabs.selectedIndex)
    }
}
