import UIKit

class ObservableViewController: BaseViewController {
    func updateUI() {
        // Subclasses override this to bind @Observable state to UI
    }

    func startObserving() {
        withObservationTracking {
            self.updateUI()
        } onChange: {
            Task { @MainActor [weak self] in
                self?.startObserving()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startObserving()
    }
}
