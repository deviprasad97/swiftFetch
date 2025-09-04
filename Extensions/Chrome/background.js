// SwiftFetch Browser Extension - Background Script
// Handles download interception, native messaging, and media detection

let nativePort = null;
let settings = {
    enabled: true,
    interceptDownloads: true,
    detectMedia: true,
    minFileSize: 1048576, // 1MB
    fileTypes: ['zip', 'exe', 'dmg', 'iso', 'pdf', 'mp4', 'mkv']
};

// Native messaging connection
function connectNative() {
    if (nativePort) {
        console.log('Native port already connected');
        return;
    }
    
    try {
        console.log('Connecting to native host: com.swiftfetch.nativehost');
        nativePort = chrome.runtime.connectNative('com.swiftfetch.nativehost');
        console.log('Native port created:', nativePort);
        
        nativePort.onMessage.addListener(message => {
            console.log('Native message received:', message);
            handleNativeMessage(message);
        });
        
        nativePort.onDisconnect.addListener(() => {
            console.log('Native host disconnected');
            if (chrome.runtime.lastError) {
                console.error('Disconnect error:', chrome.runtime.lastError.message);
            }
            nativePort = null;
            
            // Retry connection after 5 seconds
            setTimeout(connectNative, 5000);
        });
        
        // Send initial ping
        console.log('Sending initial ping...');
        sendToNative({ type: 'ping' });
    } catch (error) {
        console.error('Failed to connect to native host:', error);
    }
}

// Send message to native host
function sendToNative(message) {
    console.log('sendToNative called with:', message);
    
    if (!nativePort) {
        console.log('Native port not connected, connecting...');
        connectNative();
    }
    
    if (nativePort) {
        try {
            console.log('Posting message to native port...');
            nativePort.postMessage(message);
            console.log('Message posted successfully');
        } catch (error) {
            console.error('Failed to send native message:', error);
            nativePort = null;
        }
    } else {
        console.error('Native port still not available after connection attempt');
    }
}

// Handle messages from native host
function handleNativeMessage(message) {
    console.log('Handling native message:', message);
    
    switch (message.type) {
        case 'pong':
            console.log('Native host is alive');
            break;
            
        case 'download_response':
            console.log('Download response:', message);
            if (message.success) {
                showNotification('Download Started', message.url || 'Download');
            } else {
                showNotification('Download Failed', message.error || 'Unknown error');
            }
            break;
            
        case 'download_started':
            showNotification('Download Started', message.message);
            break;
            
        case 'error':
            console.error('Native error:', message.message);
            showNotification('Download Error', message.message);
            break;
            
        case 'status':
            // Update extension badge with active download count
            const activeCount = message.tasks.filter(t => t.status === 'active').length;
            chrome.action.setBadgeText({ 
                text: activeCount > 0 ? String(activeCount) : '' 
            });
            break;
            
        default:
            console.log('Unknown message type:', message.type);
    }
}

// Initialize on install/update
chrome.runtime.onInstalled.addListener(() => {
    // Create context menus
    chrome.contextMenus.create({
        id: 'download-link',
        title: 'Download with SwiftFetch',
        contexts: ['link']
    });
    
    chrome.contextMenus.create({
        id: 'download-image',
        title: 'Download Image with SwiftFetch',
        contexts: ['image']
    });
    
    chrome.contextMenus.create({
        id: 'download-video',
        title: 'Download Video with SwiftFetch',
        contexts: ['video']
    });
    
    chrome.contextMenus.create({
        id: 'download-audio',
        title: 'Download Audio with SwiftFetch',
        contexts: ['audio']
    });
    
    chrome.contextMenus.create({
        id: 'download-all-links',
        title: 'Download All Links with SwiftFetch',
        contexts: ['page']
    });
    
    // Set badge color
    chrome.action.setBadgeBackgroundColor({ color: '#007AFF' });
    
    // Load settings
    loadSettings();
    
    // Connect to native host
    connectNative();
});

// Context menu handler
chrome.contextMenus.onClicked.addListener((info, tab) => {
    console.log('Context menu clicked:', info.menuItemId, 'URL:', info.linkUrl || info.srcUrl);
    
    switch (info.menuItemId) {
        case 'download-link':
            console.log('Downloading link:', info.linkUrl);
            downloadUrl(info.linkUrl, tab);
            break;
            
        case 'download-image':
        case 'download-video':
        case 'download-audio':
            console.log('Downloading media:', info.srcUrl);
            downloadUrl(info.srcUrl, tab);
            break;
            
        case 'download-all-links':
            console.log('Downloading all links');
            downloadAllLinks(tab);
            break;
    }
});

// Intercept browser downloads
chrome.downloads.onCreated.addListener(item => {
    if (!settings.enabled || !settings.interceptDownloads) return;
    
    // Check if we should intercept this download
    if (shouldInterceptDownload(item)) {
        // Cancel browser download
        chrome.downloads.cancel(item.id);
        chrome.downloads.erase({ id: item.id });
        
        // Get current tab
        chrome.tabs.query({ active: true, currentWindow: true }, tabs => {
            downloadUrl(item.url, tabs[0], item.filename);
        });
    }
});

// Check if download should be intercepted
function shouldInterceptDownload(item) {
    // Skip if URL is local file or data URL
    if (item.url.startsWith('file://') || item.url.startsWith('data:')) {
        return false;
    }
    
    // Check file size (if known)
    if (item.fileSize && item.fileSize < settings.minFileSize) {
        return false;
    }
    
    // Check file type
    const extension = getFileExtension(item.filename || item.url);
    if (extension && settings.fileTypes.includes(extension)) {
        return true;
    }
    
    // Large files without extension
    if (item.fileSize && item.fileSize > 10 * 1048576) { // 10MB
        return true;
    }
    
    return false;
}

// Download URL with SwiftFetch
async function downloadUrl(url, tab, filename) {
    console.log('downloadUrl called:', url, filename);
    if (!url) {
        console.log('No URL provided, skipping');
        return;
    }
    
    // Get cookies for the URL
    console.log('Getting cookies for URL...');
    const cookies = await getCookiesForUrl(url);
    console.log('Cookies retrieved:', cookies ? 'yes' : 'no');
    
    // Prepare download request
    const request = {
        type: 'download',
        url: url,
        filename: filename,
        referrer: tab?.url,
        cookies: cookies,
        userAgent: navigator.userAgent,
        tabUrl: tab?.url,
        tabTitle: tab?.title
    };
    
    console.log('Sending download request to native host:', request);
    sendToNative(request);
    console.log('Download request sent');
}

// Download all links from page
function downloadAllLinks(tab) {
    chrome.tabs.sendMessage(tab.id, { 
        action: 'get_all_links' 
    }, links => {
        if (links && links.length > 0) {
            const downloadableLinks = links.filter(link => {
                const ext = getFileExtension(link);
                return ext && settings.fileTypes.includes(ext);
            });
            
            if (downloadableLinks.length > 0) {
                sendToNative({
                    type: 'batch',
                    urls: downloadableLinks
                });
                
                showNotification(
                    'Batch Download', 
                    `Queued ${downloadableLinks.length} files`
                );
            }
        }
    });
}

// Get cookies for URL
async function getCookiesForUrl(url) {
    try {
        const urlObj = new URL(url);
        const cookies = await chrome.cookies.getAll({ 
            url: url 
        });
        
        return cookies
            .map(c => `${c.name}=${c.value}`)
            .join('; ');
    } catch (error) {
        console.error('Failed to get cookies:', error);
        return '';
    }
}

// Media detection via webRequest
chrome.webRequest.onBeforeRequest.addListener(
    details => {
        if (!settings.detectMedia) return;
        
        // Detect HLS manifests
        if (details.url.includes('.m3u8')) {
            notifyMediaDetected(details.tabId, {
                type: 'hls',
                url: details.url,
                format: 'HLS'
            });
        }
        
        // Detect DASH manifests
        if (details.url.includes('.mpd')) {
            notifyMediaDetected(details.tabId, {
                type: 'dash',
                url: details.url,
                format: 'DASH'
            });
        }
    },
    { urls: ['<all_urls>'] },
    []
);

// Store detected media per tab
const detectedMedia = new Map();

function notifyMediaDetected(tabId, manifest) {
    if (!detectedMedia.has(tabId)) {
        detectedMedia.set(tabId, []);
    }
    
    const media = detectedMedia.get(tabId);
    
    // Avoid duplicates
    if (!media.some(m => m.url === manifest.url)) {
        media.push(manifest);
        
        // Update tab badge
        chrome.action.setBadgeText({
            text: String(media.length),
            tabId: tabId
        });
        
        // Send to native host
        sendToNative({
            type: 'detect_media',
            tabId: tabId,
            manifests: [manifest]
        });
    }
}

// Clean up when tab is closed
chrome.tabs.onRemoved.addListener(tabId => {
    detectedMedia.delete(tabId);
});

// Message handler for popup and content scripts
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.action) {
        case 'get_settings':
            sendResponse(settings);
            break;
            
        case 'save_settings':
            settings = { ...settings, ...request.settings };
            chrome.storage.local.set({ settings });
            sendResponse({ success: true });
            break;
            
        case 'get_detected_media':
            sendResponse(detectedMedia.get(request.tabId) || []);
            break;
            
        case 'download_media':
            downloadUrl(request.url, sender.tab);
            sendResponse({ success: true });
            break;
            
        case 'get_status':
            sendToNative({ type: 'get_status' });
            sendResponse({ success: true });
            break;
    }
    
    return true; // Keep channel open for async response
});

// Load settings from storage
function loadSettings() {
    chrome.storage.local.get(['settings'], result => {
        if (result.settings) {
            settings = { ...settings, ...result.settings };
        }
    });
}

// Show notification
function showNotification(title, message) {
    if (chrome.notifications) {
        chrome.notifications.create({
            type: 'basic',
            iconUrl: 'icons/icon-128.png',
            title: title,
            message: message
        });
    }
}

// Get file extension from URL or filename
function getFileExtension(url) {
    try {
        const pathname = new URL(url).pathname;
        const match = pathname.match(/\\.([^.]+)$/);
        return match ? match[1].toLowerCase() : null;
    } catch {
        const match = url.match(/\\.([^.]+)$/);
        return match ? match[1].toLowerCase() : null;
    }
}

// Initialize on startup
connectNative();