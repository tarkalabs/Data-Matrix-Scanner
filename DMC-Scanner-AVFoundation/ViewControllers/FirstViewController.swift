//
//  FirstViewController.swift
//  DMC-Scanner-AVFoundation
//
//  Created by Ibrahim Hassan on 31/03/23.
//

import UIKit

class FirstViewController: UIViewController {
    @IBOutlet weak var scannedCodeLbl: UILabel!

    @IBAction func tryWithAVFoundation(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if let vc = storyboard.instantiateViewController(withIdentifier: "ScannerAVFoundationVC") as? ScannerAVFoundationVC {
            scannedCodeLbl.text = ""
            vc.delegate = self

            self.present(vc, animated: true)
        }
    }

    @IBAction func tryVision(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if let vc = storyboard.instantiateViewController(withIdentifier: "ScannerVisionVC") as? ScannerVisionVC {
            scannedCodeLbl.text = ""
            vc.delegate = self

            self.present(vc, animated: true)
        }
    }

    @IBAction func tryVisionWithPreProcessing(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if let vc = storyboard.instantiateViewController(withIdentifier: "ScannerVisionVC") as? ScannerVisionVC {
            scannedCodeLbl.text = ""
            vc.usePreprocessing = true
            vc.delegate = self

            self.present(vc, animated: true)
        }
    }
}

extension FirstViewController: ScannerDelegate {
    func dataMatrixCodeRead(_ code: String) {
        self.scannedCodeLbl.text = code
    }
}
