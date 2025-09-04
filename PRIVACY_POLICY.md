# Privacy Policy for SwiftFetch Download Manager

**Effective Date:** September 4, 2025  
**Last Updated:** September 4, 2025

## Overview

SwiftFetch is a desktop download manager application for macOS with an accompanying browser extension. This privacy policy explains how SwiftFetch handles your data and protects your privacy.

## Our Commitment to Privacy

SwiftFetch is designed with privacy as a core principle. We do not collect, store, transmit, or sell any personal data to third parties. All data processing occurs locally on your device.

## Information We Do NOT Collect

- **No Personal Information:** We do not collect names, email addresses, phone numbers, or other personal identifiers
- **No Browsing History:** We do not track, log, or store your browsing history
- **No Analytics:** We do not use analytics services or tracking pixels
- **No Telemetry:** We do not send usage statistics or crash reports to external servers
- **No User Accounts:** SwiftFetch does not require user registration or accounts

## Local Data Processing

SwiftFetch processes the following data locally on your device only:

### Desktop Application Data
- **Download URLs:** URLs of files you choose to download
- **Download Metadata:** File names, sizes, and download progress
- **Local Settings:** Your preferences for download locations, concurrent downloads, and app behavior
- **Download History:** A local record of completed downloads stored in your app's data folder

### Browser Extension Data
- **Current Tab Information:** Page title and URL when you initiate downloads
- **Authentication Cookies:** Session cookies for downloads from password-protected sites (processed locally only)
- **Download Links:** URLs of downloadable content detected on web pages
- **User Preferences:** Extension settings like minimum file size thresholds

## How Data is Used

All data processing serves the single purpose of providing download management functionality:

- **Download Processing:** URLs and metadata are used to manage and execute downloads
- **Authentication:** Cookies are used locally to access protected downloads you initiate
- **User Experience:** Settings and preferences customize the app behavior to your needs
- **Content Detection:** The browser extension scans pages to identify downloadable content

## Data Storage and Security

- **Local Storage Only:** All data is stored locally on your macOS device
- **No Cloud Sync:** Data is never transmitted to external servers or cloud services
- **System Security:** Data benefits from your macOS system's built-in security features
- **User Control:** You can delete all data by removing the application

### Storage Locations
- **Application Data:** `~/Library/Containers/com.swiftfetch.app/Data/`
- **Extension Settings:** Local browser storage only
- **Downloads:** Your chosen download directory (default: ~/Downloads)

## Browser Extension Permissions

Our Chrome extension requests several permissions solely for download management functionality:

- **activeTab:** To detect downloadable content on the current page
- **contextMenus:** To add "Download with SwiftFetch" to right-click menus
- **cookies:** To access authentication cookies for protected downloads (local processing only)
- **downloads:** To intercept and redirect downloads to the desktop app
- **nativeMessaging:** To communicate with the SwiftFetch desktop application
- **storage:** To save extension preferences locally
- **tabs:** To identify the source of downloads for organization
- **webRequest/webNavigation:** To detect streaming media and update content detection
- **host permissions:** To work across all websites where you encounter downloads

## Third-Party Services

SwiftFetch does not integrate with any third-party analytics, advertising, or tracking services. The application operates independently without external dependencies for data processing.

## aria2 Download Engine

SwiftFetch uses the open-source aria2 download engine, which runs locally on your system. aria2 does not collect or transmit any data beyond what is necessary for downloading the files you request.

## Children's Privacy

SwiftFetch does not collect any data from users of any age. The application is suitable for all users as it operates entirely locally without data collection.

## International Users

Since SwiftFetch processes all data locally on your device, there are no international data transfer concerns. Your data never leaves your computer.

## Data Retention and Deletion

- **User Control:** You control all data retention through the app's settings
- **Download History:** Can be cleared manually through the app interface
- **Complete Removal:** Uninstalling SwiftFetch removes all associated data
- **No Persistent Tracking:** No data persists after uninstallation

## Changes to This Privacy Policy

We may update this privacy policy to reflect changes in functionality or legal requirements. Updated versions will:

- Be posted with a new "Last Updated" date
- Include a summary of material changes
- Maintain our commitment to local-only data processing

## Contact Information

If you have questions about this privacy policy or SwiftFetch's privacy practices:

- **GitHub Issues:** [Create an issue on our GitHub repository](https://github.com/deviprasad97/swiftFetch/issues)
- **Email:** tripathy.devi7@gmail.com

## Legal Compliance

This privacy policy complies with:

- **Chrome Web Store Developer Program Policies**
- **California Consumer Privacy Act (CCPA)** - though we collect no personal information
- **General Data Protection Regulation (GDPR)** - though we process no personal data
- **Apple App Store Guidelines** - for potential future App Store distribution

## Technical Implementation

For transparency, our privacy implementation includes:

- **No Network Requests:** The desktop app makes no network requests except for downloads you initiate
- **Local Database:** Download history stored in local SQLite database
- **Sandboxed Extension:** Browser extension runs in Chrome's sandboxed environment
- **Native Messaging Only:** Extension communicates only with your local SwiftFetch app

## Your Rights

Since SwiftFetch does not collect personal data, traditional data rights (access, portability, deletion) are not applicable. However, you have complete control over:

- All locally stored data through the application interface
- Extension permissions through browser settings
- Data removal through application uninstallation

---

**Summary:** SwiftFetch is designed to respect your privacy by processing all data locally on your device and never transmitting personal information to external servers. This privacy policy will be updated if our data handling practices change, but our commitment to local-only processing remains constant.