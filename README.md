# SparkleSoftwareUpdateTool
Welcome to the SparkleSoftwareUpdateTool wiki!

Sparkle software update tool generate application zip and Appcast.xml files which you can deploy on your auto-upgrade server. Tool is written in swift 2.0. It also provide test web server so that you can test your auto-upgrade package locally.

![Sparkle Software Update Tool screen shot](https://github.com/sainianil/SparkleSoftwareUpdateTool/blob/master/AutoUpgradeSoftwareTool.png)

## How to use
Download zip or clone the repository and start using it. If you have some extra customization requirement, you can easily modify the code. Following are the steps to use the tool:

1. **Application path:**
Either fill in application with absolute path or select application through open panel.

2. **Update Version:**
New auto-upgrade application version which you want to deploy on server.

3. **DSA Private Key File:**
Either fill in DSA private key file with absolute path or select a file through open panel.

4. **Server URL:**
Fill in server address and also add port if required where you are going to deploy auto-upgrade zip and Appcast.xml file.

5. **Version Details:**
Fill in the version details if you really want to provide. Its optional field.

6. Click on 'Generate Software Update Files' button to generate zip and Appcast.xml files.

## How to use Test Web Server:
If you want to test auto-upgrade on local network. 

1. Click on 'Start Web Server' button.
2. It'll deploy the app on `/Users/<user name>/Library/Caches/Saini.com.SparkleSoftwareUpdateTool` folder
3. Change URL of `SUFeedURL` entry in your app which you want to upgrade to [http://127.0.0.1:1337/Appcast.xml](http://127.0.0.1:1337/Appcast.xml). If application is running on some other system in the same local network, change IP Address - 127.0.0.1  to your system's IP Address where this tool is running.
