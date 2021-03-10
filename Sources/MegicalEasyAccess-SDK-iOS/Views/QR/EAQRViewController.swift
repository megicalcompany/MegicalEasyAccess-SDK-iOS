//
//  EAQRViewController.swift
//  
//
//  Created by Antti Köliö on 5.3.2021.
//

import UIKit
import SwiftyBeaver

@objc
public class EAQRViewController: UIViewController {
    let log = SwiftyBeaver.self
    
    @objc public var loginCode: String = ""
    @objc public var authCallback: String = ""
    @objc public var onError: ((_ error: Error) -> Void)?
    @objc public var onCloseTouchedHandler: (() -> Void)?
    
    let backgroundLayer = CAGradientLayer()
    lazy var qrImageView = UIImageView()
    let bLoginCode = UIButton(type: .custom)
    let bClose = UIButton(type: .close)
    
    public override func viewDidLoad() {
        let eaQRMessage = EAURL.eaAppPath(loginCode: self.loginCode)
        
        let cCenter = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let cEdge = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.4)
        
        self.backgroundLayer.frame = self.view.bounds
        self.backgroundLayer.colors = [cEdge.cgColor, cCenter.cgColor, cCenter.cgColor, cEdge.cgColor]
        self.backgroundLayer.locations = [0, 0.1, 0.9, 1]
        self.view.layer.addSublayer(backgroundLayer)
        
        self.qrImageView.image = generateQRCode(eaQRMessage)
        self.qrImageView.contentMode = .scaleToFill
        self.view.addSubview(self.qrImageView)
        self.qrImageView.translatesAutoresizingMaskIntoConstraints = false
        self.qrImageView.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
        self.qrImageView.heightAnchor.constraint(equalToConstant: 200.0).isActive = true
        self.qrImageView.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        self.qrImageView.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        
        self.bLoginCode.setTitle(self.loginCode, for: .normal)
        self.bLoginCode.setTitleColor(.systemBlue, for: .normal)
        self.bLoginCode.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        self.bLoginCode.addTarget(self, action: #selector(self.onLoginButtonPressed(sender:)), for: .touchUpInside)
        self.view.addSubview(self.bLoginCode)
        self.bLoginCode.translatesAutoresizingMaskIntoConstraints = false
        self.bLoginCode.topAnchor.constraint(equalTo: self.qrImageView.bottomAnchor, constant: 30).isActive = true
        self.bLoginCode.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        
        self.view.addSubview(self.bClose)
        self.bClose.addTarget(self, action: #selector(self.onCloseButtonPressed(sender:)), for: .touchUpInside)
        self.bClose.translatesAutoresizingMaskIntoConstraints = false
        self.bClose.bottomAnchor.constraint(equalTo: self.qrImageView.topAnchor, constant: -40).isActive = true
        self.bClose.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor, constant: -self.view.safeAreaLayoutGuide.layoutFrame.width * 0.2).isActive = true
    }
    
    @objc public func presentOnController(parentVC: UIViewController, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            self.modalPresentationStyle = .overFullScreen
            self.modalTransitionStyle = .crossDissolve
            parentVC.present(self, animated: true, completion: completion)
        }
    }

    func generateQRCode(_ string: String) -> UIImage? {
        
        guard
            let qrFilter = CIFilter(name: "CIQRCodeGenerator"),
            let data = string.data(using: .isoLatin1, allowLossyConversion: false) else {
            return nil
        }
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")

        let scaleTransform = CGAffineTransform(scaleX: 12, y: 12)
        guard let ciImage = qrFilter.outputImage?.transformed(by: scaleTransform) else {
            return nil
        }

        let img = UIImage(ciImage: ciImage, scale: 1.0, orientation: .up)
        return img
    }
    
    @objc func onLoginButtonPressed(sender: UIButton) {
        guard let eaUrl = URL(string: EAURL.eaAppPath(loginCode: self.loginCode, authCallback: self.authCallback)) else {
            log.error("Failed to switch to easy access")
            self.onError?(EAErrorUtil.error(domain: "MegAuthFlow", code: -1, underlyingError: nil, description: "Failed to switch to easy access"))
            return
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(eaUrl)
        }
    }
    
    @objc func onCloseButtonPressed(sender: UIButton) {
        if self.onCloseTouchedHandler != nil {
            self.onCloseTouchedHandler!()
        } else {
            self.dismiss(animated: true)
        }
    }
}
