//
//  ViewController.swift
//  gumletSampleApp
//
//  Created by Martina on 22/04/22.
//

import UIKit
import Foundation
import AVKit
import AVFoundation
import Firebase
import FirebaseStorage


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    

    @IBOutlet var uploadButton: UIButton!
    
    // loading screen
    var loadingLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.numberOfLines = 0
        let w = UIScreen.main.bounds.width - 30
        l.frame = CGRect(x: 0,
                         y: 200,
                         width: UIScreen.main.bounds.width,
                         height: 100)
        l.textAlignment = .center
        l.text = "loading..."
        return l
    }()
    
    // blur view behind loading scren
    lazy var blurry: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .regular)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.alpha = 0
        blurEffectView.frame = self.view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return blurEffectView
    }()

    // AVPlayer objects
    private var player: AVPlayer!
    private var playerVC: AVPlayerViewController!
    private var playerLayer: AVPlayerLayer!
    
    // video url
    var videoUrl: URL!
    
    
// MARK: - View Did Load
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        uploadButton.layer.cornerRadius = uploadButton.frame.height / 2
        uploadButton.isUserInteractionEnabled = true
        
    }
    
    

// MARK: - Image Picker Controller
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        // handle media type
        guard let mediaInfo = info[.mediaType] else { return }
        picker.sourceType = .savedPhotosAlbum
        let mediaType = "\(mediaInfo)"
        if mediaType == "public.movie" {
            
            // export as mp4
            if let videoURL = info[.mediaURL] as? URL {
                
                AVURLAsset(url: videoURL).exportVideo { url in
                    
                    // save to storage
                    if url != nil, let url = url {
                        
                        // loading screen while video is exported
                        self.loadingScreen(animating: true)
                        
                        // get video orientation from frame
                        let video = AVAsset(url: url)
                        let generator = AVAssetImageGenerator.init(asset: video)
                        let cgImage = try! generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        print("Frames width \(image.size.width) x height \(image.size.height)")
                        
                        // option 1: direct upload on Gumlet
                        self.directUpload(url: url, profileID: "-string-", tag: "my tag", title: "my title", description: "my desc")
                        
                        // option 2: upload on another storage first
                        //self.saveToStorage(url: url)
                        
                    }
                    
                }
                
                self.dismiss(animated: true, completion: nil)
                
            }
            
        }
        
    }
    
    
// MARK: - Direct Upload (Gumlet)
    
    func directUpload(url: URL, profileID: String, tag: String, title: String, description: String) {
        
        let headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer -string-"
        ]
        
        let parameters: [String : Any] = [
            "collection_id": "-string-",
            "format": "MP4",
            "profile_id": "\(profileID)",
            "tag": "\(tag)",
            "title": "\(title)",
            "description": "\(description)"
            
        ]
    
        // define a request
        let postData = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        let request = NSMutableURLRequest(url: NSURL(string: "https://api.gumlet.com/v1/video/assets/upload")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData as Data?
        
        // start a session
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            
            // error
            if error != nil, let error = error {
                print("error: \(error)")
                
            // success
            } else if let httpResponse = response as? HTTPURLResponse, let data = data {
                print("status code: \(httpResponse.statusCode)")
                
                // get upload url
                let j = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let dictionary = j as [String: Any]?, let uploadURL = dictionary["upload_url"] as? String {
                    print("upload url: \(uploadURL)")
                    
                    // get asset ID to check upload status
                    if let a = dictionary["asset_id"] as? String {
                          print("Asset ID: \(a)")
                          self.checkStatus(assetID: a) }
                    
                    // start upload url request
                    if let playbackURL = URL(string: uploadURL) {
                        self.uploadURL(url: url, playbackURL: playbackURL)
                    
                    }
                }
            }
        })
        
        dataTask.resume()
        
    }
    
    
    
    
    func uploadURL(url: URL, playbackURL: URL) {
        
        let headers = [
          "Content-Type": "video/mp4"
        ]
        
        // define a request
        let request = NSMutableURLRequest(url: playbackURL,
                                                  cachePolicy: .useProtocolCachePolicy,
                                                  timeoutInterval: 10.0)
        request.httpMethod = "PUT"
        request.allHTTPHeaderFields = headers
        
        // start a URL session
        let session = URLSession.shared
        let dataTask = session.uploadTask(with: request as URLRequest, fromFile: url) { (responseData, response, error) in
            
            // error
            if error != nil, let error = error {
                print("error: \(error)")
            
            // success
            } else if let httpResponse = response as? HTTPURLResponse {
                
                // get status code (200 is successful upload)
                print("status code: \(httpResponse.statusCode)")
            }
        
        }
        
        dataTask.resume()
    
    }
    

// MARK: - Web Proxy (Gumlet)
    
    func uploadOnGumlet(url: URL, profileID: String, tag: String, title: String, description: String) {
        
        let headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer -string-"
        ]
        
        let parameters: [String : Any] = [
            "format": "MP4",
            "collection_id": "-string-",
            "input": "\(url)",
            "profile_id": "\(profileID)",
            "tag": "\(tag)",
            "title": "\(title)",
            "description": "\(description)"
        ]
        
        // create the asset's json data with parametrs
        let postData = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        
        // crate request
        let request = NSMutableURLRequest(url: NSURL(string: "https://api.gumlet.com/v1/video/assets")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData as Data?
        
        // start the session
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            
            // handle errors
            if error != nil, let error = error {
              
                print("error: \(error)")
                self.alert(title: "Unable to upload video", message: "\(error.localizedDescription)")
                self.loadingScreen(animating: false)
              
            // handle success respons
            } else if let httpResponse = response as? HTTPURLResponse, let data = data {
              
                print("httpResponse: \(httpResponse)")
              
              let j = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
              
              if let aid = j as [String: Any]?, let a = aid["asset_id"] as? String {
                  
                    print("Asset ID: \(a)")
                    self.checkStatus(assetID: a)
                  
                }
              
            }
            
        })
        
        dataTask.resume()
        
    }
    

// MARK: - Check Upload Status (Gumlet)
    
    func checkStatus(assetID: String) {
        
        let headers = [
          "Accept": "application/json",
          "Authorization": "Bearer -string-"
        ]
        let url = "https://api.gumlet.com/v1/video/assets/\(assetID)"

        // create request
        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        // start session
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            
            // error handling
            if let error = error {
                
                print("error: \(error)")
                self.alert(title: "Unable to check video status", message: "\(error)")
            
            // success
            } else if let data = data {
                
                // get asset status
                let j = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let aid = j as [String: Any]?, let s = aid["status"] as? String {
                    
                    print("Status: \(s)")
                    
                    // if ready
                    if s != "ready" {
                      
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
                            self.loadingLabel.text = "\(s)"
                            self.checkStatus(assetID: assetID)
                      })
                    
                    // if not ready
                    } else {
                        
                        DispatchQueue.main.async {
                          self.loadingScreen(animating: false)
                          self.playVideo(url: self.videoUrl)
                        }
                    }
                
                }
            
            }
        
        })

        dataTask.resume()
        
    }
    
    
    
    func playVideo(url: URL) {
        
        // set the video url and duration
        let videoURL = url as URL
        let duration = Int64(((Float64(CMTimeGetSeconds(AVAsset(url: videoURL).duration)) *  10.0) - 1) / 10.0)

        
        // option 1: play your video from AVPlayerLayer
//        player = AVPlayer(url: videoURL.absoluteURL)
//        playerLayer = AVPlayerLayer(player: player)
//        playerLayer.frame = self.view.bounds
//        view.layer.insertSublayer(playerLayer, at: 1)
//        player.play()
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(duration)) + .seconds(1)) {
//            self.playerLayer.removeFromSuperlayer()
//        }
        
        // option 2: play your video from AVPlayerViewController
        player = AVPlayer(url: videoURL.absoluteURL)
        playerVC = AVPlayerViewController()
        playerVC.player = player
        self.present(playerVC, animated: true)
        self.playerVC.player!.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(duration)) + .seconds(1)) {
            self.playerVC.dismiss(animated: true)
        }
        
    }
    
    
    
    func saveToStorage(url: URL) {
    
        // loading screen while video is exported
        loadingScreen(animating: true)
        
        // set firebase storage reference
        let videoName = NSUUID().uuidString
        let storageRef = Storage.storage().reference().child("videos/\(videoName)")
        storageRef.putFile(from: url, metadata: nil) { (metaData, error) in
        
            // in case of errors
            if error != nil {
                print("error uploading video: \(error!.localizedDescription)")
                self.loadingScreen(animating: false)
                
            // if there are no errors
            } else {
            
                // get the video's URL
                storageRef.downloadURL { (url, error) in
                
                    // if no download url
                    if error != nil {
                        self.loadingScreen(animating: false)
                        print("error downloading uploaded videos Url: \(error!.localizedDescription)")
                        
                    // get download url
                    } else if let vurl = url {
                        self.videoUrl = vurl
                        print("vurl \(vurl)")
                        self.uploadOnGumlet(url: vurl, profileID: "-string-", tag: "my tag", title: "my title", description: "my description")
                            
                        }
                    }
                }
            }
        }
    
    
    
// MARK: - Misc
    
    func alert(title: String, message: String) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let OK = UIAlertAction(title: "OK", style: .cancel)
        alert.addAction(OK)
        alert.view.tintColor = .label
        self.present(alert, animated: true)
        
    }

    
    func blurView(completion: @escaping (_ success: Bool) -> ()) {
        
        // check that users settings allow blur view
        if !UIAccessibility.isReduceTransparencyEnabled {
            
            // add subview and bring to front
            self.view.addSubview(blurry)
            self.view.bringSubviewToFront(blurry)
            
            // animate the view
            UIView.animate(withDuration: 1) {
                self.blurry.alpha = 0.75
                completion(true)
                }
            }
        }
    
    
    func loadingScreen(animating: Bool) {
        
        // if loading screen is on
        if animating == true {
            
            // use system circle hexagon grid images as circles
            let img1 = UIImage(systemName: "circle.hexagongrid")
            let img2 = UIImage(systemName: "circle.hexagongrid.fill")
            
            DispatchQueue.main.async {
            
                self.view.addSubview(self.loadingLabel)
                let iv1 = UIImageView(image: img1)
                let iv2 = UIImageView(image: img2)
                let images = [iv1, iv2]
                var i = 100
                iv1.alpha = 0
                
                // set up both images at once
                for image in images {
                    
                    // give a tag to the image view so you can find it and remove it later
                    i += 1
                    image.tag = i
                    
                    // set the circles position
                    let hw: CGFloat = 100
                    image.frame = CGRect(x: UIScreen.main.bounds.width/2 - hw/2,
                                         y: 100,
                                         width: hw,
                                         height: hw)
                    image.contentMode = .scaleAspectFill
                    
                    // set the circles colors
                    if #available(iOS 15.0, *) {
                        image.tintColor = (image.image == img1 ? .systemCyan : .systemIndigo)
                    } else {
                        image.tintColor = (image.image == img1 ? .systemBlue : .systemPink)
                    }
                    
                    // add to the view
                    self.view.addSubview(image)
                    
                    // rotation animation
                    UIView.animate(withDuration: 2, delay: 0, options: [.repeat, .curveLinear]) {
                        image.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                    }
                    
                    
                    
                }
                
                // add blur view
                self.blurView { success in
                    
                    // bring the circles in front of the blurred view
                    self.view.bringSubviewToFront(iv1)
                    self.view.bringSubviewToFront(iv2)
                    self.view.bringSubviewToFront(self.loadingLabel)
                    
                    // switch views
                    UIView.animate(withDuration: 1, delay: 0, options: [.repeat, .autoreverse]) {
                        iv2.alpha = 0
                        iv1.alpha = 1
                    }
                    UIView.animate(withDuration: 1, delay: 1, options: [.repeat, .autoreverse]) {
                        iv1.alpha = 0
                        iv2.alpha = 1
                    }
                }
            }
            
        // if loading screen is off
        } else {
            
            // remove blur view and image views
            UIView.animate(withDuration: 1, delay: 0) {
                
                // find image views by tag
                let views = [self.view.viewWithTag(101), self.view.viewWithTag(102), self.blurry, self.loadingLabel]
                for view in views {
                    view?.alpha = 0
                    view?.removeFromSuperview()
                    
                }
            }

        }
        
    }
    
    
// MARK: - Upload video button
    
    @IBAction func uploadVideoButton(_ sender: Any) {
            
            let imagePickerController = UIImagePickerController()
            imagePickerController.sourceType = .photoLibrary
            imagePickerController.delegate = self
            imagePickerController.mediaTypes = ["public.movie"]
            imagePickerController.allowsEditing = false
            self.present(imagePickerController, animated: true, completion: nil)
        
    }
    

}


// MARK: - Compress the video

extension AVURLAsset {
    
    func exportVideo(presetName: String = AVAssetExportPresetHighestQuality,
                     outputFileType: AVFileType = .mp4,
                     fileExtension: String = "mp4",
                     then completion: @escaping (URL?) -> Void) {
        
        // replace MOV with MP4
        let filename = url.deletingPathExtension().appendingPathExtension(fileExtension).lastPathComponent
        
        // save url to temp directory
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        // start the export session
        if let session = AVAssetExportSession(asset: self, presetName: presetName) {
            
            session.outputURL = outputURL
            session.outputFileType = outputFileType
            let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 0)
            let range = CMTimeRangeMake(start: start, duration: duration)
            session.timeRange = range
            session.shouldOptimizeForNetworkUse = true
            
            // error handling
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    completion(outputURL)
                case .cancelled:
                    debugPrint("Video url export cancelled.")
                    completion(nil)
                case .failed:
                    let errorMessage = session.error?.localizedDescription ?? "n/a"
                    debugPrint("Video url export failed with error: \(errorMessage)")
                    completion(nil)
                default:
                    break
                }
            }
            
        // if session fails
        } else {
            print("video url session failed to start")
            completion(nil)
        }
    }
}
