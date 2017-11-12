/*
See LICENSE folder for this sample’s licensing information.

Abstract:
UI Actions for the main view controller.
*/

import UIKit
import SceneKit
import ARKit
import CoreML
import Vision
import ImageIO

extension ViewController: UIGestureRecognizerDelegate {
    
    enum SegueIdentifier: String {
        case showObjects
    }
    
    // MARK: - Interface Actions
    
    /// Displays the `VirtualObjectSelectionViewController` from the `addObjectButton` or in response to a tap gesture in the `sceneView`.
    @IBAction func showVirtualObjectSelectionViewController() {
        // Ensure adding objects is an available action and we are not loading another object (to avoid concurrent modifications of the scene).
        guard !addObjectButton.isHidden && !virtualObjectLoader.isLoading else { return }
        
        statusViewController.cancelScheduledMessage(for: .contentPlacement)
        performSegue(withIdentifier: SegueIdentifier.showObjects.rawValue, sender: addObjectButton)
        
        //isHidden/isEnabled Code
        periodicAddObject.isHidden = true
        periodicAddObject.isEnabled = false
        coreMLTriggerButton.isHidden = true
        coreMLTriggerButton.isEnabled = false
        
    }
    
    @IBAction func showPeriodicTable() {
        guard !addObjectButton.isHidden && !virtualObjectLoader.isLoading else { return }
        
        statusViewController.cancelScheduledMessage(for: .contentPlacement)
        performSegue(withIdentifier: SegueIdentifier.showObjects.rawValue, sender: periodicAddObject)
        
        //isHidden/isEnabled Code
        addObjectButton.isHidden = true
        addObjectButton.isEnabled = false
        elementTextField.isHidden = false
        elementTextField.isEnabled = true
        elementSendButton.isHidden = false
        elementSendButton.isEnabled = true
        coreMLTriggerButton.isHidden = true
        coreMLTriggerButton.isEnabled = false
        
    }
        
    @IBAction func showElement() {
        //guard !addObjectButton.isHidden && !virtualObjectLoader.isLoading else { return }
        
        statusViewController.cancelScheduledMessage(for: .contentPlacement)
        virtualObjectLoader.removeAllVirtualObjects()
        var object = VirtualObject()
        for virtualElementObject in VirtualObject.elements {
            if virtualElementObject.modelName == elementDictionary[elementTextField.text!] {
                object = virtualElementObject
            }
        }
        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            DispatchQueue.main.async {
                self.hideObjectLoadingUI()
                self.placeVirtualObject(loadedObject)
            }
        })
        elementTextField.text! = ""
       
        //isHidden/isEnabled Code
        periodicAddObject.isHidden = true
        periodicAddObject.isEnabled = false
        
    }
    
    @IBAction func coreMLActivate() {
        
        coreMLTriggerButton.isHidden = true
        coreMLTriggerButton.isEnabled = false
        coreMLPictureButton.isHidden = false
        coreMLPictureButton.isEnabled = true
        periodicAddObject.isHidden = true
        periodicAddObject.isEnabled = false
        addObjectButton.isHidden = true
        addObjectButton.isEnabled = false
        
        
        
    }
    
    @IBAction func coreMLProcess () {
        
        
        let pixbuff : CVPixelBuffer? = sceneView.session.currentFrame?.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([self.classificationRequest])
        } catch {
            print("Bad request")
        }
        
        statusViewController.cancelScheduledMessage(for: .contentPlacement)
        virtualObjectLoader.removeAllVirtualObjects()
        var object = VirtualObject()
        
        for virtualElementObject in VirtualObject.MLecules {
            print("NewestTop:", newestTop2)
            if (newestTop2["water bottle"] != nil)  && (newestTop2["water bottle"]! > Double(0.3)) {
            object = virtualElementObject
            }
        }
        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            DispatchQueue.main.async {
                self.hideObjectLoadingUI()
                self.placeVirtualObject(loadedObject)
            }
        })
        
    }

    
    
    /// Determines if the tap gesture for presenting the `VirtualObjectSelectionViewController` should be used.
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return virtualObjectLoader.loadedObjects.isEmpty
    }
    
    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /// - Tag: restartExperience
    func restartExperience() {
        guard isRestartAvailable, !virtualObjectLoader.isLoading else { return }
        isRestartAvailable = false

        statusViewController.cancelAllScheduledMessages()

        virtualObjectLoader.removeAllVirtualObjects()
        addObjectButton.setImage(UIImage(named: "ellipsis"), for: [])
        addObjectButton.setImage(UIImage(named: "ellipsisPressed"), for: [.highlighted])
        periodicAddObject.setImage(UIImage(named: "pImage"), for: [])
        periodicAddObject.setImage(UIImage(named: "pImagePressed"), for: [.highlighted])

        resetTracking()
        
        //isHidden/isEnabled Code
        addObjectButton.isHidden = false
        addObjectButton.isEnabled = true
        periodicAddObject.isHidden = false
        periodicAddObject.isEnabled = true
        elementTextField.isHidden = true
        elementTextField.isEnabled = false
        elementSendButton.isHidden = true
        elementSendButton.isEnabled = false
        coreMLTriggerButton.isHidden = false
        coreMLTriggerButton.isEnabled = true
        coreMLPictureButton.isHidden = true
        coreMLPictureButton.isEnabled = false

        // Disable restart for a while in order to give the session time to restart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isRestartAvailable = true
        }
    }
}

extension ViewController: UIPopoverPresentationControllerDelegate {
    
    // MARK: - UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // All menus should be popovers (even on iPhone).
        if let popoverController = segue.destination.popoverPresentationController, let button = sender as? UIButton {
            popoverController.delegate = self
            popoverController.sourceView = button
            popoverController.sourceRect = button.bounds
        }
        
        guard let identifier = segue.identifier,
              let segueIdentifer = SegueIdentifier(rawValue: identifier),
              segueIdentifer == .showObjects else { return }
        
        let objectsViewController = segue.destination as! VirtualObjectSelectionViewController
        if periodicAddObject == (sender as! UIButton) {
            objectsViewController.virtualObjects = VirtualObject.periodicTables
        }
        else {
            objectsViewController.virtualObjects = VirtualObject.misc
        }
        objectsViewController.delegate = self
        
        // Set all rows of currently placed objects to selected.
        for object in virtualObjectLoader.loadedObjects {
            guard let index = VirtualObject.availableObjects.index(of: object) else { continue }
            objectsViewController.selectedVirtualObjectRows.insert(index)
        }
    }
    
}
