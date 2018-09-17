//
//  AppDelegate.swift
//  FileUploader
//
//  Created by Adam Nagy on 17/09/2014.
//  Copyright (c) 2014 Adam Nagy. All rights reserved.
//

import Cocoa

class AppDelegate:
NSObject, NSApplicationDelegate, NSComboBoxDelegate {
  
  // List of Forge API URL's
  
  let forgeUrl = "https://developer.api.autodesk.com"
  
  func postAuthenticatePath() -> String {
    return String(
      format:
      "%@/authentication/v1/authenticate",
      forgeUrl);
  }
  
  func postBucketsPath() -> String {
    return String(
      format:
      "%@/oss/v2/buckets",
      forgeUrl);
  }
  
  func putObjectPath(_ bucketName: String, _ fileName: String) -> String {
    return String(
      format:
      "%@/oss/v2/buckets/%@/objects/%@",
      forgeUrl,
      bucketName,
      fileName);
  }
  
  func postTranslatePath() -> String {
    return String(
      format:
      "%@/modelderivative/v2/designdata/job",
      forgeUrl);
  }
  
  func getThumbnailPath(_ fileUrn64: String) -> String {
    return String(
      format:
      "%@/modelderivative/v2/designdata/%@/thumbnail",
      forgeUrl,
      fileUrn64);
  }
  
  func getManifestPath(_ fileUrn64: String) -> String {
    return String(
      format:
      "%@/modelderivative/v2/designdata/%@/manifest",
      forgeUrl,
      fileUrn64);
  }
  
  // Functions calling Forge API's
  
  func postBuckets(_ bucketName: String, completion: @escaping (Any?) -> Void) {
    let body = String(
      format:
      "{ \"bucketKey\":\"%@\"" +
        ",\"policyKey\":\"transient\"," +
      "\"servicesAllowed\":{}}",
      bucketName)
    
    httpTo(
      postBucketsPath(),
      data: body.data(using: String.Encoding.utf8)!,
      contentType: "application/json",
      method: "POST", getJson: true, completion: completion)
  }
  
  func putObject(_ bucketName: String, _ fileName: String, _ fileData: Data, completion: @escaping (Any?) -> Void) {
    httpTo(
      putObjectPath(bucketName, fileName),
      data: fileData,
      contentType: "application/stream",
      method: "PUT", getJson: true, completion: completion)
  }
  
  func postTranslate(_ fileUrn64: String, completion: @escaping (Any?) -> Void) {
    let body = String(
      format:
      "{" +
        "\"input\": {" +
        "\"urn\": \"%@\"" +
        "}," +
        "\"output\": {" +
        "\"formats\": [{" +
        "\"type\": \"svf\"," +
        "\"views\": [" +
        "\"2d\"," +
        "\"3d\"" +
        "]" +
        "}]" +
        "}" +
      "}",
      fileUrn64)
    
    httpTo(
      postTranslatePath(),
      data: body.data(using: String.Encoding.utf8)!,
      contentType:"application/json; charset=utf-8",
      method:"POST", getJson: true, completion: completion)
  }
  
  func getThumbnail(_ fileUrn64: String, completion: @escaping (Any?) -> Void) {
    httpTo(
      getThumbnailPath(fileUrn64),
      data: nil,
      contentType:"application/json; charset=utf-8",
      method:"GET", getJson: false, completion: completion)
  }
  
  func getManifest(_ fileUrn64: String, completion: @escaping (Any?) -> Void) {
    httpTo(
      getManifestPath(fileUrn64),
      data: nil,
      contentType:"application/json; charset=utf-8",
      method:"GET", getJson: true, completion: completion)
  }
  
  // Dialog related functions
  
  @IBOutlet weak var infoLabel: NSTextField!
  @IBOutlet weak var progressBar: NSProgressIndicator!
  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var consumerKey: NSTextField!
  @IBOutlet weak var consumerSecret: NSTextField!
  @IBOutlet weak var bucketName: NSTextField!
  @IBOutlet weak var accessToken: NSTextField!
  @IBOutlet weak var fileUrn: NSComboBox!
  @IBOutlet weak var fileThumbnail: NSImageView!
  
  @IBAction func generateToken(_ sender: Any) {
    logIn();
  }
  
  func setInfoLabelText(_ text: String) {
    DispatchQueue.main.async(execute: { () -> Void in
      self.infoLabel.stringValue = text
    })
  }
  
  func setAccessTokenText(_ text: String) {
    DispatchQueue.main.async(execute: { () -> Void in
      self.accessToken.stringValue = text
    })
  }
  
  func setFileThumbnailImage(_ data: Data?) {
    DispatchQueue.main.async(execute: { () -> Void in
      if (data != nil) {
        self.fileThumbnail.image = NSImage(data: data!)
      }
    })
  }
  
  func setProgressBarPosition(_ position: Double) {
    DispatchQueue.main.async(execute: { () -> Void in
      self.progressBar.doubleValue = position
    })
  }
  
  @objc func checkProgress(timer: Timer) {
    let fileUrn64: String = timer.userInfo as! String
    getManifest(fileUrn64, completion: {
      data in
      
      let json = data as! NSDictionary
      let status = json["status"] as! String
      let progress = json["progress"] as! String
      
      if status == "failed" {
        self.setInfoLabelText("Failed")
        self.setProgressBarPosition(0)
      } else {
        self.setInfoLabelText(progress)
      
        let parts: [String] = progress.components(separatedBy: "%")
        if (parts.count > 1) {
          self.setProgressBarPosition(Double(parts[0])!)
        } else {
          self.setProgressBarPosition(100)
        }
      }
      
      if progress == "complete" || status == "failed" {
        timer.invalidate()
      }
    })
  }
  
  func keepCheckingProgress(_ fileUrn64: String) {
    DispatchQueue.main.async(execute: { () -> Void in
      Timer.scheduledTimer(
        timeInterval: 1, target: self,
        selector: #selector(self.checkProgress),
        userInfo: fileUrn64, repeats: true)
    })
  }
  
  @IBAction func uploadFile(_ sender: Any) {
    // Select a file first
    let filePath = openFileDialog(
      "File Upload", message: "Select file to upload")
    
    if filePath == "" {
      return
    }
    
    do {
      let fileData = try Data(contentsOf: URL(string: filePath)!)
      let filePathUrl = URL(fileURLWithPath: filePath)
      var fileName = filePathUrl.lastPathComponent
      
      // Get rid of spaces in the file name
      fileName = fileName.replacingOccurrences(of: "%20", with: "", options: NSString.CompareOptions.caseInsensitive, range: nil)
      
      // Now we can try to create a bucket
      setInfoLabelText("Uploading file...")
      postBuckets(bucketName.stringValue, completion: {
        data in
        
        // Now we try to upload the file
        self.putObject(self.bucketName.stringValue, fileName, fileData, completion: {
          data in
          
          let json = data as! NSDictionary
          let fileKey = json["objectKey"]
          let fileSha1 = json["sha1"]
          let fileId = json["objectId"] as? String
          
          print("fileKey = \(fileKey ?? "No fileKey")");
          print("fileSha1 = \(fileSha1 ?? "No fileSha1")");
          print("fileId = \(fileId ?? "No fileId")");
          
          let data = fileId!.data(using: String.Encoding.utf8)
          var fileUrn64 = data!.base64EncodedString()
          fileUrn64 = fileUrn64.replacingOccurrences(of: "=", with: "")
          print("fileUrn64 = \(fileUrn64)")
          
          self.fileUrn.addItem(withObjectValue: fileUrn64)
          
          // Send for translation
          self.setInfoLabelText("Translating file...")
          self.postTranslate(fileUrn64, completion: {
            data in
            
            let json = data as! NSDictionary
            let diagnostic: String? = json["diagnostic"] as! String?
            if diagnostic != nil {
              self.setInfoLabelText(diagnostic!)
            } else {
              // Starting monitoring the translation progress
              self.keepCheckingProgress(fileUrn64)
            }
          });
        });
      })
    } catch let err as NSError {
      setInfoLabelText(err.localizedDescription)
    }
  }
  
  func comboBoxSelectionDidChange(_ notification: Notification) {
    let str: String = fileUrn.objectValues[fileUrn.indexOfSelectedItem] as! String;
    getThumbnail(str, completion: {
      data in
      
      self.setFileThumbnailImage(data as! Data?)
    });
  }
  
  func openFileDialog(_ title: String, message: String) -> String {
    let myFileDialog: NSOpenPanel = NSOpenPanel()
    
    myFileDialog.prompt = "Open"
    myFileDialog.worksWhenModal = true
    myFileDialog.allowsMultipleSelection = false
    myFileDialog.canChooseDirectories = false
    myFileDialog.resolvesAliases = true
    myFileDialog.title = title
    myFileDialog.message = message
    myFileDialog.runModal()
    let chosenfile = myFileDialog.url
    if (chosenfile != nil) {
      let theFile = chosenfile?.absoluteString
      return (theFile)!
    } else {
      return ("")
    }
  }
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application
    setInfoLabelText("")
    
    // Load Consumer Key, Consumer Secret, urn
    let prefs = UserDefaults.standard
    let cKey: Any? = prefs.value(forKey: "ConsumerKey")
    let cSecret: Any? = prefs.value(forKey: "ConsumerSecret")
    let fUrn: Any? = prefs.value(forKey: "urn")
    let fUrns: Any? = prefs.value(forKey: "urns")
    let cBucket: Any? = prefs.value(forKey: "BucketName")
    if (cKey != nil) {
      consumerKey.stringValue = cKey! as! String
    }
    if (cSecret != nil) {
      consumerSecret.stringValue = cSecret! as! String
    }
    if (fUrn != nil) {
      fileUrn.stringValue = fUrn! as! String
    }
    if (fUrns != nil) {
      deserializeUrns(fUrns! as! String as NSString)
    }
    if (cBucket != nil) {
      bucketName.stringValue = cBucket! as! String
    }
  }
  
  func serializeUrns() -> NSString {
    var urns = ""
    let values = fileUrn.objectValues
    for urn in values {
      urns += urn as! String + ";"
    }
    
    return urns as NSString
  }
  
  func deserializeUrns(_ urnsText: NSString) {
    var urns = urnsText.components(separatedBy: ";")
    urns.removeLast()
    fileUrn.addItems(withObjectValues: urns)
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
    
    // Save Consumer Key, Consumer Secret, urn
    // By default it's stored in:
    // ~/Library/Preferences/com.autodesk.MacViewStarter.plist
    // Might be here too:
    // ~/Library/SyncedPreferences/com.autodesk.MacViewStarter.plist
    let prefs = UserDefaults.standard
    prefs.set(consumerKey.stringValue, forKey:"ConsumerKey")
    prefs.set(
      consumerSecret.stringValue, forKey:"ConsumerSecret")
    prefs.set(fileUrn.stringValue, forKey:"urn")
    prefs.set(serializeUrns(), forKey:"urns")
    prefs.set(bucketName.stringValue, forKey:"BucketName")
    prefs.synchronize()
  }
  
  // Log in to Forge
  func logIn() {
    let body = String(
      format:
      "client_id=%@&client_secret=%@" +
      "&grant_type=client_credentials&scope=%@",
      consumerKey.stringValue,
      consumerSecret.stringValue,
      "data:read data:write data:create data:search " +
      "bucket:create bucket:read bucket:update bucket:delete")
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    
    httpTo(
      postAuthenticatePath(),
      data: body!.data(using: String.Encoding.utf8)!,
      contentType: "application/x-www-form-urlencoded",
      method: "POST", getJson: true, completion: {
        data in
        
        let json = data as! NSDictionary
        self.setAccessTokenText(json["access_token"] as! String)
      }
    )
  }
  
  // Send http requests
  func httpTo(_ url: String, data: Data?, contentType: String,
              method: String, getJson: Bool,
              completion: @escaping (Any?) -> Void) {
    
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.httpAdditionalHeaders = [
      "Authorization":"Bearer " + accessToken.stringValue,
      "Content-Type":contentType
    ]
    
    var req = URLRequest(url: URL(string: url as String)!)
    req.httpMethod = method as String
    if (data != nil) {
      req.httpBody = data!
    }
    
    let urlSession = URLSession(configuration: sessionConfig)
    urlSession.dataTask(with: req, completionHandler: {
      data, response, error in
      
      if error == nil && data != nil {
        if (!getJson) {
          completion(data as Any?);
        } else {
          do {
            let json = try JSONSerialization.jsonObject(
              with: data!,
              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary;
            completion(json);
          } catch let err as NSError {
            let responseString = String(data: data!, encoding: .utf8)
            print(responseString ?? "No response string");
            print(err.localizedDescription);
          }
        }
      }
    }).resume()
  }
}


