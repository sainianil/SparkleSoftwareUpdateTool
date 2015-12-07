//
//  ViewController.swift
//  SparkleSoftwareUpdateTool
//
//  Created by Anil Saini on 12/6/15.
//  Copyright © 2015 Anil Saini. All rights reserved.
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
    
    var cacheDirectoryURL: NSURL!
    var serverDirectoryURL: NSURL!
    var mainBundle: NSBundle!
    var webServer:SUTestWebServer!
    
    override func awakeFromNib()
    {
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
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        //set background color to white
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.whiteColor().CGColor
    }

    override var representedObject: AnyObject?
    {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func initialize()
    {
        self.mainBundle = NSBundle.mainBundle()
        let fileManager = NSFileManager.defaultManager()
        
        //Create cache directory
        if let tmpURL = try? fileManager.URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        {
            self.cacheDirectoryURL = tmpURL
            let bundleIdentifier = self.mainBundle.bundleIdentifier
            assert(bundleIdentifier != nil)
            //append bundle identifier with cacheDirectoryURL
            self.serverDirectoryURL = self.cacheDirectoryURL.URLByAppendingPathComponent(bundleIdentifier!)
            
            //If you want to delete directory each time
            //            if ((serverDirectoryURL?.checkResourceIsReachableAndReturnError(nil)) == true) {
            //
            //                if ((try? fileManager.removeItemAtURL(serverDirectoryURL)) == nil) {
            //                    print("Error: Failed to remove server directory!")
            //                    assert(false)
            //                }
            //            }
            
            //Create server directory
            if (try? fileManager.createDirectoryAtURL(self.serverDirectoryURL, withIntermediateDirectories: true, attributes: nil)) == nil
            {
                self.showError("Failed to create server directory!", info: "Failed to create server directory at - \(self.serverDirectoryURL). Please try again.")
                print("Error: Failed to create server directory!")
            }
        }
        else
        {
            self.showError("Failed to create cache directory!", info: "Failed to create cache directory. Please try again.")
            print("Error: Failed to create cache directory!")
        }
    }
    
    @IBAction func appPath(sender: NSButton)
    {
        let openPanel = self.openPanel()
        openPanel.beginWithCompletionHandler { (result) -> Void in
            if result == NSFileHandlingPanelOKButton
            {
                //user selected app path
                self.txtAppPath.stringValue = (openPanel.URLs.first?.path)!
            }
        }
    }
    
    @IBAction func dSAPrivateKey(sender: NSButton)
    {
        let openPanel = self.openPanel()
        openPanel.beginWithCompletionHandler { (result) -> Void in
            if result == NSFileHandlingPanelOKButton
            {
                //user selected DSA private key file path
                self.txtDSAPrivKey.stringValue = (openPanel.URLs.first?.path)!
            }
        }
    }
    
    @IBAction func generateUpdateFiles(sender: NSButton)
    {
        if self.txtUpdateVersion.stringValue.isEmpty || self.txtAppPath.stringValue.isEmpty || self.txtDSAPrivKey.stringValue.isEmpty || self.txtServerURL.stringValue.isEmpty
        {
            self.showError("Fill the required fields!", info: "All or any of the field is empty, please enter a value in the field and try again.")
        }
        else
        {
            let bundleURL = NSURL.fileURLWithPath(self.txtAppPath.stringValue)
            let destinationBundleURL = serverDirectoryURL.URLByAppendingPathComponent(bundleURL.lastPathComponent!)
            let fileManager = NSFileManager.defaultManager()
            
            //copy app to server directory
            if (try? fileManager.copyItemAtURL(bundleURL, toURL: destinationBundleURL)) != nil
            {
                //append path to info.plist
                let infoURL = destinationBundleURL.URLByAppendingPathComponent("Contents").URLByAppendingPathComponent("info.plist")
                
                if infoURL.checkResourceIsReachableAndReturnError(nil)
                {
                    let infoDic = NSMutableDictionary.init(contentsOfURL: infoURL)
                    //set version info
                    infoDic?.setValue(self.txtUpdateVersion.stringValue, forKey: kCFBundleVersionKey as String)
                    infoDic?.setValue(self.txtUpdateVersion.stringValue, forKey: "CFBundleShortVersionString")
                    
                    if infoDic?.writeToURL(infoURL, atomically:false) == true
                    {
                        var zipName = (self.txtAppPath.stringValue as NSString).stringByDeletingPathExtension
                        zipName = (zipName as NSString).lastPathComponent + self.txtUpdateVersion.stringValue + ".zip"
                        
                        let dittoTask = NSTask()
                        dittoTask.launchPath = "/usr/bin/ditto"
                        dittoTask.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", (destinationBundleURL.path! as NSString).lastPathComponent, zipName]
                        dittoTask.currentDirectoryPath = serverDirectoryURL.path!
                        dittoTask.launch()
                        dittoTask.waitUntilExit()
                        
                        if (try? fileManager.removeItemAtURL(destinationBundleURL)) != nil
                        {
                            let privateKeyPath = String(self.txtDSAPrivKey.stringValue)
                            //sign in the updated app with sign_update tool
                            let signUpdateTask = NSTask()
                            signUpdateTask.launchPath = self.mainBundle.pathForResource("sign_update", ofType: "")
                            let archiveURL = serverDirectoryURL.URLByAppendingPathComponent(zipName)
                            signUpdateTask.arguments = [archiveURL.path!, privateKeyPath]
                            
                            let outputPipe = NSPipe()
                            signUpdateTask.standardOutput = outputPipe
                            
                            signUpdateTask.launch()
                            signUpdateTask.waitUntilExit()
                            
                            //generate signature
                            let signatureData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                            if let signature = (NSString(data: signatureData, encoding: NSUTF8StringEncoding)?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
                            {
                                self.createAppcast(archiveURL, signature: signature, zipName: zipName)
                            }
                            NSWorkspace.sharedWorkspace().activateFileViewerSelectingURLs([self.serverDirectoryURL])
                        }
                        else
                        {
                            self.showError("Failed to remove file!", info: "Failed to remove - \(destinationBundleURL) file. Please try again.")
                            print("Error: Failed to remove - \(destinationBundleURL)")
                        }
                    }
                    else
                    {
                        self.showError("Failed to update file!", info: "Failed to update - \(destinationBundleURL) file. Please try again.")
                        print("Error: Failed to update - \(infoURL)")
                    }
                }
                else
                {
                    self.showError("Resouce not found!", info: "File - \(destinationBundleURL) not found. Please try again.")
                    print("Error: Resouce not found - \(infoURL)")
                }
            }
            else
            {
                self.showError("Failed to copy files!", info: "Failed to copy main bundle - \(bundleURL) into server directory - \(destinationBundleURL). Please try again.")
                print("Error: Failed to copy main bundle - \(bundleURL) into server directory - \(destinationBundleURL)")
            }
        }
    }
    
    @IBAction func startWebServer(sender: NSButton)
    {
        if (sender.title.compare("Start Web Server")) ==  .OrderedSame
        {
            self.webServer = SUTestWebServer(port: 1337, workingDirectory: self.serverDirectoryURL.path!)
            btnStartServer.title = "Stop Web Server"
        }
        else
        {
            self.webServer.close()
            btnStartServer.title = "Start Web Server"
        }
    }
    
/* **************** Helper methods **************** */

    func createAppcast(archiveURL: NSURL, signature: String, zipName: String)
    {
        let fileManager = NSFileManager.defaultManager()
        let archiveFileAttributes: NSDictionary = try! fileManager.attributesOfItemAtPath(archiveURL.path!)
        let appcastName = "Appcast"
        let appcastExt = "xml"
        let appcastDestinationURL = serverDirectoryURL.URLByAppendingPathComponent(appcastName).URLByAppendingPathExtension(appcastExt)
        
        //Remove app cast file if already exists
        if fileManager.fileExistsAtPath(appcastDestinationURL.path!) && (try? fileManager.removeItemAtPath(appcastDestinationURL.path!)) != nil
        {
            //copy Appcast.xml from tool resources to server directory
            if (try? fileManager.copyItemAtURL(self.mainBundle.URLForResource(appcastName, withExtension: appcastExt)!, toURL: appcastDestinationURL)) != nil
            {
                //extract appcast.xml contents
                if let appcastContents = try? NSMutableString(contentsOfURL: appcastDestinationURL, encoding: NSUTF8StringEncoding)
                {
                    var warningMessage: String = ""
                    let numberOfUpdateVersionReplacements = appcastContents.replaceOccurrencesOfString("$UPDATE_VERSION", withString: self.txtUpdateVersion.stringValue, options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfUpdateVersionReplacements != 2
                    {
                        warningMessage = "$UPDATE_VERSION\n"
                    }
                    
                    let numberOfLengthReplacements = appcastContents.replaceOccurrencesOfString("$INSERT_ARCHIVE_LENGTH", withString: NSString(format: "%llu", archiveFileAttributes.fileSize()) as String, options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfLengthReplacements != 1
                    {
                        warningMessage = warningMessage + "$INSERT_ARCHIVE_LENGTH\n"
                    }
                    
                    let numberOfSignatureReplacements = appcastContents.replaceOccurrencesOfString("$INSERT_DSA_SIGNATURE", withString:signature, options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfSignatureReplacements != 1
                    {
                        warningMessage = warningMessage + "$INSERT_DSA_SIGNATURE\n"
                    }
                    
                    let numberOfPublishDateReplacements = appcastContents.replaceOccurrencesOfString("$PUBLISH_DATE", withString: self.currentDate(), options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfPublishDateReplacements != 1
                    {
                        warningMessage = warningMessage + "$PUBLISH_DATE\n"
                    }
                    
                    var serverURL = self.txtServerURL.stringValue
                    if serverURL.hasSuffix("/")
                    {
                        serverURL = serverURL.substringToIndex(serverURL.endIndex.predecessor())
                    }
                    
                    let numberOfServerURLReplacements = appcastContents.replaceOccurrencesOfString("$SERVER_URL", withString: serverURL, options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfServerURLReplacements != 1
                    {
                        warningMessage = warningMessage + "$SERVER_URL\n"
                    }
                    
                    let numberOfZipNameReplacements = appcastContents.replaceOccurrencesOfString("$ZIP_NAME", withString: zipName, options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfZipNameReplacements != 1
                    {
                        warningMessage = warningMessage + "$ZIP_NAME\n"
                    }
                    
                    let numberOfVersionDetailsReplacements = appcastContents.replaceOccurrencesOfString("$VERSION_DETAILS", withString: self.txtVersionDetails.string!, options:NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, (appcastContents.length)))
                    if numberOfVersionDetailsReplacements != 1
                    {
                        warningMessage = warningMessage + "$VERSION_DETAILS\n"
                    }
                    
                    if (try? appcastContents.writeToURL(appcastDestinationURL, atomically: false, encoding: NSUTF8StringEncoding)) == nil
                    {
                        self.showError("Failed to write file!", info: "Failed to write updated appcast - \(appcastDestinationURL) file. Please try again.")
                        print("Error: Failed to write updated appcast!")
                    }
                    
                    if !warningMessage.isEmpty
                    {
                        self.showError("Failed to replace following strings in Appcast.xml file!", info: "Please verify Appcast.xml before deploying " + warningMessage)
                    }
                }
                else
                {
                    self.showError("Failed to load appcast file!", info: "Failed to load appcast \(appcastDestinationURL) file. Please try again.")
                    print("Error: Failed to load appcast contents")
                }
            }
            else
            {
                self.showError("Failed to copy file!", info: "Failed to copy \(appcastName).\(appcastExt) at \(appcastDestinationURL). Please try again.")
                print("Error: Failed to copy appcast into cache directory")
            }
        }
        else
        {
            self.showError("Failed to remove file!", info: "Failed to remove \(appcastDestinationURL). Please try again.")
            print("Error: Failed to remove \(appcastDestinationURL)")
        }
    }
    
    func openPanel() -> NSOpenPanel
    {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        return openPanel
    }
    
    func currentDate() -> String
    {
        let dateFormatter:NSDateFormatter = NSDateFormatter()
        //        Sat, 26 Jul 2014 15:20:11 +0000
        dateFormatter.dateFormat = "E, dd MMM yyyy HH:mm:ss Z"
        //        print(dateFormatter.stringFromDate(NSDate()))
        return dateFormatter.stringFromDate(NSDate())
    }
    
    func showError(message: String, info: String)
    {
        let alert:NSAlert = NSAlert()
        alert.alertStyle = NSAlertStyle.CriticalAlertStyle
        alert.messageText = message
        alert.informativeText = info
        alert.runModal();
    }

}

