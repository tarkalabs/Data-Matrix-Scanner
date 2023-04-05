//
//  ScannerDelegate.swift
//  DMC-Scanner-AVFoundation
//
//  Created by Ibrahim Hassan on 05/04/23.
//

protocol ScannerDelegate: AnyObject {
    func dataMatrixCodeRead(_ code: String)
}
