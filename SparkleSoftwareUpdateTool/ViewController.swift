//
//  ViewController.swift
//  SparkleSoftwareUpdateTool
//
//  Created by Anil Saini on 12/6/15.
//  Copyright © 2015 Anil Saini. All rights reserved.
//
//
//  Modified by Tyler Hostager on 1/14/18 after updating the code to modern Swift 4 syntax
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var txtAppPath: NSTextField!
    @IBOutlet weak var txtUpdateVersion: NSTextField!
    @IBOutlet weak var txtDSAPrivKey: NSTextField!
    @IBOutlet weak var txtServerURL: NSTextField!
    @IBOutlet weak var btnStartServer: NSButton!
    @IBOutlet var txtVersionDetails: NSTextView!
    @IBOutlet weak var btnGenSoftUpdateFiles: NSButton!
    
    var cacheDirectoryURL: URL!
    var serverDirectoryURL: URL!
    var mainBundle: Bundle!
    var webServer: SUTestWebServer!
    
    override func awakeFromNib() {
        
        //Fill placeholder and tooltip value
        self.txtServerURL.placeholderString = "Server URL such as http://127.0.0.1:1337/"
        self.txtServerURL.toolTip = "Server URL where you deploy your auto-upgrade package"
        self.txtAppPath.placeholderString = "Application with path"
        self.txtAppPath.toolTip = "Application file with fully qualified path"
        self.txtUpdateVersion.placeholderString = "Auto-upgrade version such as 0.0.3"
        self.txtUpdateVersion.toolTip = "Auto-upgrade app version"
        self.txtDSAPrivKey.placeholderString = "Sparkle private key file with path"
        self.txtDSAPrivKey.toolTip = "Sparkle private key file with fully qualified path"
        self.btnStartServer.toolTip = "Test server deploys app on URL - http://127.0.0.1:1337/Appcast.xml i.e. localhost"
        self.btnGenSoftUpdateFiles.toolTip = "Generate software update files i.e. app.zip and Appcast.xml"
        
        //Initialize
        self.initialize()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //set background color to white
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = .white
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    func initialize() {
        self.mainBundle = Bundle.main
        let fileManager = FileManager.default
        
        //Create cache directory
        if let tmpURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            self.cacheDirectoryURL = tmpURL
            let bundleIdentifier = self.mainBundle.bundleIdentifier
            assert(bundleIdentifier != nil)
            //append bundle identifier with cacheDirectoryURL
            self.serverDirectoryURL = self.cacheDirectoryURL.appendingPathComponent(bundleIdentifier!)
            
            //If you want to delete directory each time
            //            if ((serverDirectoryURL?.checkResourceIsReachableAndReturnError(nil)) == true) {
            //
            //                if ((try? fileManager.removeItemAtURL(serverDirectoryURL)) == nil) {
            //                    print("Error: Failed to remove server directory!")
            //                    assert(false)
            //                }
            //            }
            
            //Create server directory
            if (try? fileManager.createDirectory(at: self.serverDirectoryURL, withIntermediateDirectories: true, attributes: nil)) == nil {
                self.showError(message: "Failed to create server directory!", info: "Failed to create server directory at - \(self.serverDirectoryURL). Please try again.")
                print("Error: Failed to create server directory!")
            }
        } else {
            self.showError(message: "Failed to create cache directory!", info: "Failed to create cache directory. Please try again.")
            print("Error: Failed to create cache directory!")
        }
    }
    
    @IBAction func appPath(sender: NSButton) {
        let openPanel = self.openPanel()
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                //user selected app path
                self.txtAppPath.stringValue = (openPanel.urls.first?.path)!
            }
        }
    }
    
    @IBAction func dSAPrivateKey(sender: NSButton) {
        let openPanel = self.openPanel()
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSFileHandlingPanelOKButton {
                //user selected DSA private key file path
                self.txtDSAPrivKey.stringValue = (openPanel.urls.first?.path)!
            }
        }
    }
    
    @IBAction func generateUpdateFiles(sender: NSButton) {
        if self.txtUpdateVersion.stringValue.isEmpty || self.txtAppPath.stringValue.isEmpty || self.txtDSAPrivKey.stringValue.isEmpty || self.txtServerURL.stringValue.isEmpty {
            self.showError(message: "Fill the required fields!", info: "All or any of the field is empty, please enter a value in the field and try again.")
        } else {
            let bundleURL = NSURL.fileURL(withPath: self.txtAppPath.stringValue)
            let destinationBundleURL = serverDirectoryURL.appendingPathComponent(bundleURL.lastPathComponent)
            let fileManager = FileManager.default
            
            //copy app to server directory
            if (try? fileManager.copyItem(at: bundleURL, to: destinationBundleURL)) != nil {
                
                //append path to info.plist
                let infoURL = destinationBundleURL.appendingPathComponent("Contents").appendingPathComponent("Info.plist")
                
                if (infoURL as NSURL).checkResourceIsReachableAndReturnError(nil) {
                    let infoDic = NSMutableDictionary(contentsOf: infoURL)
                    //set version info
                    infoDic?.setValue(self.txtUpdateVersion.stringValue, forKey: kCFBundleVersionKey as String)
                    infoDic?.setValue(self.txtUpdateVersion.stringValue, forKey: "CFBundleShortVersionString")
                    
                    if infoDic?.write(to: infoURL, atomically:false) == true {
                        var zipName = (self.txtAppPath.stringValue as NSString).deletingPathExtension
                        zipName = (zipName as NSString).lastPathComponent + self.txtUpdateVersion.stringValue + ".zip"
                        
                        let dittoTask = Process()
                        dittoTask.launchPath = "/usr/bin/ditto"
                        dittoTask.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", (destinationBundleURL.path as NSString).lastPathComponent, zipName]
                        dittoTask.currentDirectoryPath = serverDirectoryURL.path
                        dittoTask.launch()
                        dittoTask.waitUntilExit()
                        
                        if (try? fileManager.removeItem(at: destinationBundleURL)) != nil {
                            let privateKeyPath = String(self.txtDSAPrivKey.stringValue)
                            //sign in the updated app with sign_update tool
                            let signUpdateTask = Process()
                            signUpdateTask.launchPath = self.mainBundle.path(forResource: "sign_update", ofType: "")
                            
                            let archiveURL = serverDirectoryURL.appendingPathComponent(zipName)
                            signUpdateTask.arguments = [archiveURL.path, privateKeyPath]
                            
                            let outputPipe = Pipe()
                            signUpdateTask.standardOutput = outputPipe
                            signUpdateTask.launch()
                            signUpdateTask.waitUntilExit()
                            
                            //generate signature
                            let signatureData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                            if let signature = (NSString(data: signatureData, encoding: String.Encoding.utf8.rawValue)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                                self.createAppcast(archiveURL: archiveURL as NSURL, signature: signature, zipName: zipName)
                            }
                            
                            NSWorkspace.shared.activateFileViewerSelecting([self.serverDirectoryURL])
                        } else {
                            self.showError(message: "Failed to remove file!", info: "Failed to remove - \(destinationBundleURL) file. Please try again.")
                            print("Error: Failed to remove - \(destinationBundleURL)")
                        }
                    } else {
                        self.showError(message: "Failed to update file!", info: "Failed to update - \(destinationBundleURL) file. Please try again.")
                        print("Error: Failed to update - \(infoURL)")
                    }
                } else {
                    self.showError(message: "Resouce not found!", info: "File - \(destinationBundleURL) not found. Please try again.")
                    print("Error: Resouce not found - \(infoURL)")
                }
            } else {
                self.showError(message: "Failed to copy files!", info: "Failed to copy main bundle - \(bundleURL) into server directory - \(destinationBundleURL). Please try again.")
                print("Error: Failed to copy main bundle - \(bundleURL) into server directory - \(destinationBundleURL)")
            }
        }
    }
    
    @IBAction func startWebServer(sender: NSButton) {
        if (sender.title.compare("Start Web Server")) == .orderedSame {
            self.webServer = SUTestWebServer(port: 1337, workingDirectory: self.serverDirectoryURL.path)
            btnStartServer.title = "Stop Web Server"
        } else {
            self.webServer.close()
            btnStartServer.title = "Start Web Server"
        }
    }
    
/* **************** Helper methods **************** */

    func createAppcast(archiveURL: NSURL, signature: String, zipName: String) {
        let fileManager = FileManager.default
        
        
        
        let archiveFileAttributes: Dictionary = try! fileManager.attributesOfItem(atPath: archiveURL.path!)
        let appcastName = "Appcast"
        let appcastExt = "xml"
        let appcastDestinationURL = serverDirectoryURL.appendingPathComponent(appcastName).appendingPathComponent(appcastExt)
        
        //Remove app cast file if already exists
        if fileManager.fileExists(atPath: appcastDestinationURL.path) && (try?
            fileManager.removeItem(at: appcastDestinationURL)) != nil {
            
            //copy Appcast.xml from tool resources to server directory
            if (try? fileManager.copyItem(at: self.mainBundle.url(forResource: appcastName, withExtension: appcastExt)!, to: appcastDestinationURL)) != nil {
                //extract appcast.xml contents
                
                let utf8Val = String.Encoding.utf8.rawValue
                
                if let appcastContents = try? NSMutableString(contentsOf: appcastDestinationURL, encoding: utf8Val) {
                    
                    let appContentsRange = NSRange(0..<appcastContents.length)
                    var warningMessage: String = ""
                    
                    var archFileAttrSize : UInt64!
                    if let attrSize = archiveFileAttributes[FileAttributeKey.size] as? NSNumber {
                        archFileAttrSize = attrSize.uint64Value
                    }
                    
                    let numberOfUpdateVersionReplacements = appcastContents.replaceOccurrences(
                        of: "$UPDATE_VERSION",
                        with: self.txtUpdateVersion.stringValue,
                        options: .literal,
                        range: appContentsRange
                    )
                    
                    if numberOfUpdateVersionReplacements != 2 {
                        warningMessage = "$UPDATE_VERSION\n"
                    }
                    
                    let numberOfLengthReplacements = appcastContents.replaceOccurrences(of: "$INSERT_ARCHIVE_LENGTH", with: String(format: "%llu", archFileAttrSize), options: .literal, range: appContentsRange)
                    
                    warningMessage += numberOfLengthReplacements == 1 ? "" : "$INSERT_ARCHIVE_LENGTH\n"
                    
                    let numberOfSignatureReplacements = appcastContents.replaceOccurrences(of: "$INSERT_DSA_SIGNATURE", with: signature, options: .literal, range: appContentsRange)
                    if numberOfSignatureReplacements != 1 {
                        warningMessage += "$INSERT_DSA_SIGNATURE\n"
                    }
                    
                    let numberOfPublishDateReplacements = appcastContents.replaceOccurrences(of: "$PUBLISH_DATE", with: self.currentDate(), options: .literal, range: appContentsRange)
                    if numberOfPublishDateReplacements != 1 {
                        warningMessage += "$PUBLISH_DATE\n"
                    }
                    
                    let txtServerURLStr = self.txtServerURL.stringValue
                    let serverURL = txtServerURLStr.hasSuffix("/") ? String(txtServerURLStr[..<txtServerURLStr.endIndex]) : self.txtServerURL.stringValue
                    
                    let numberOfServerURLReplacements = appcastContents.replaceOccurrences(of: "$SERVER_URL", with: serverURL, options: .literal, range: appContentsRange)
                    if numberOfServerURLReplacements != 1 {
                        warningMessage += "$SERVER_URL\n"
                    }
                    
                    let numberOfZipNameReplacements = appcastContents.replaceOccurrences(
                        of: "$ZIP_NAME",
                        with: zipName,
                        options: .literal,
                        range: appContentsRange
                    )
                    
                    if numberOfZipNameReplacements != 1 {
                        warningMessage += "$ZIP_NAME\n"
                    }
                    
                    let numberOfVersionDetailsReplacements = appcastContents.replaceOccurrences(of: "$VERSION_DETAILS", with: self.txtVersionDetails.string, options: .literal, range: appContentsRange)
                    
                    if numberOfVersionDetailsReplacements != 1 {
                        warningMessage += "$VERSION_DETAILS\n"
                    }
                    
                    if (try? appcastContents.write(to: appcastDestinationURL, atomically: false, encoding: String.Encoding.utf8.rawValue)) == nil {
                        self.showError(message: "Failed to write file!", info: "Failed to write updated appcast - \(appcastDestinationURL) file. Please try again.")
                        print("Error: Failed to write updated appcast!")
                    }
                    
                    if !warningMessage.isEmpty {
                        self.showError(message: "Failed to replace following strings in Appcast.xml file!", info: "Please verify Appcast.xml before deploying " + warningMessage)
                    }
                } else {
                    self.showError(message: "Failed to load appcast file!", info: "Failed to load appcast \(appcastDestinationURL) file. Please try again.")
                    print("Error: Failed to load appcast contents")
                }
 
            } else {
                self.showError(message: "Failed to copy file!", info: "Failed to copy \(appcastName).\(appcastExt) at \(appcastDestinationURL). Please try again.")
                print("Error: Failed to copy appcast into cache directory")
            }
        } else {
            self.showError(message: "Failed to remove file!", info: "Failed to remove \(appcastDestinationURL). Please try again.")
            print("Error: Failed to remove \(appcastDestinationURL)")
        }
    }
    
    func openPanel() -> NSOpenPanel {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        return openPanel
    }
    
    func currentDate() -> String {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, dd MMM yyyy HH:mm:ss Z"
        return dateFormatter.string(from: Date())
    }
    
    func showError(message: String, info: String) {
        let alert:NSAlert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = info
        alert.runModal();
    }

}

