#if os(macOS)
import AppKit
import SwiftUI
import AudioToolbox
import CoreAudioKit

/// NSViewController wrapper providing the AudioUnit's custom view.
/// DAW hosts request this via `requestViewController(completionHandler:)`.
public final class MidiClawAUViewController: AUViewController {
    private var audioUnit: MidiClawAudioUnit?
    private var hostingView: NSView?

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 400, height: 440)

        if let au = audioUnit {
            embedSwiftUIView(audioUnit: au)
        }
    }

    /// Called by the host to provide the AudioUnit instance.
    public override var auAudioUnit: AUAudioUnit? {
        didSet {
            if let au = auAudioUnit as? MidiClawAudioUnit {
                audioUnit = au
                if isViewLoaded {
                    embedSwiftUIView(audioUnit: au)
                }
            }
        }
    }

    private func embedSwiftUIView(audioUnit: MidiClawAudioUnit) {
        hostingView?.removeFromSuperview()

        let swiftUIView = MidiClawAUView(audioUnit: audioUnit)
        let hostingController = NSHostingController(rootView: swiftUIView)

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hostingView = hostingController.view
    }
}
#endif
