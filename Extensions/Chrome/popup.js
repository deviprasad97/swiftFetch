// SwiftFetch Chrome Extension - Popup Script

document.addEventListener('DOMContentLoaded', async () => {
    // Elements
    const statusIndicator = document.getElementById('statusIndicator');
    const statusText = document.getElementById('statusText');
    const linksList = document.getElementById('linksList');
    const videoInfo = document.getElementById('videoInfo');
    const scanButton = document.getElementById('scanPage');
    const downloadAllButton = document.getElementById('downloadAll');
    const downloadVideoButton = document.getElementById('downloadVideo');
    const openAppButton = document.getElementById('openApp');
    
    // Settings
    const autoInterceptCheckbox = document.getElementById('autoIntercept');
    const detectMediaCheckbox = document.getElementById('detectMedia');
    const notificationsCheckbox = document.getElementById('notifications');
    
    // Tab handling
    const tabs = document.querySelectorAll('.tab');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const tabName = tab.dataset.tab;
            
            // Update active tab
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            
            // Update active content
            tabContents.forEach(content => {
                content.classList.remove('active');
                if (content.id === tabName) {
                    content.classList.add('active');
                }
            });
        });
    });
    
    // State
    let detectedLinks = [];
    let currentTab = null;
    let videoData = null;
    
    // Initialize
    async function init() {
        // Get current tab
        const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
        currentTab = tab;
        
        // Check connection status
        checkConnection();
        
        // Load settings
        loadSettings();
        
        // Scan current page
        scanCurrentPage();
        
        // Check for videos
        checkForVideos();
    }
    
    // Check native host connection
    async function checkConnection() {
        try {
            const response = await chrome.runtime.sendMessage({action: 'get_status'});
            updateConnectionStatus(true);
        } catch (error) {
            updateConnectionStatus(false);
        }
    }
    
    // Update connection status UI
    function updateConnectionStatus(connected) {
        if (connected) {
            statusIndicator.classList.add('connected');
            statusText.textContent = 'Connected to SwiftFetch';
        } else {
            statusIndicator.classList.remove('connected');
            statusText.textContent = 'SwiftFetch not connected';
        }
    }
    
    // Load settings
    async function loadSettings() {
        const settings = await chrome.runtime.sendMessage({action: 'get_settings'});
        autoInterceptCheckbox.checked = settings.interceptDownloads;
        detectMediaCheckbox.checked = settings.detectMedia;
        notificationsCheckbox.checked = settings.enabled;
    }
    
    // Save settings
    async function saveSettings() {
        await chrome.runtime.sendMessage({
            action: 'save_settings',
            settings: {
                interceptDownloads: autoInterceptCheckbox.checked,
                detectMedia: detectMediaCheckbox.checked,
                enabled: notificationsCheckbox.checked
            }
        });
    }
    
    // Scan current page for downloads
    async function scanCurrentPage() {
        if (!currentTab) return;
        
        try {
            // Send message to content script
            const response = await chrome.tabs.sendMessage(currentTab.id, {
                action: 'scanPage'
            });
            
            // Get detected links
            const pageInfo = await chrome.tabs.sendMessage(currentTab.id, {
                action: 'getPageInfo'
            });
            
            if (pageInfo && pageInfo.links && pageInfo.links.length > 0) {
                detectedLinks = pageInfo.links;
                displayLinks();
            }
        } catch (error) {
            console.error('Failed to scan page:', error);
        }
    }
    
    // Display detected links
    function displayLinks() {
        if (detectedLinks.length === 0) {
            linksList.innerHTML = '<div class="empty-state">No downloadable links found</div>';
            downloadAllButton.style.display = 'none';
            return;
        }
        
        linksList.innerHTML = detectedLinks.map(link => `
            <div class="link-item" data-url="${link.url}">
                <span class="link-icon">${getIcon(link.type)}</span>
                <span class="link-text">${link.text || getFilename(link.url)}</span>
            </div>
        `).join('');
        
        // Add click handlers
        linksList.querySelectorAll('.link-item').forEach(item => {
            item.addEventListener('click', () => {
                downloadLink(item.dataset.url);
            });
        });
        
        downloadAllButton.style.display = 'block';
    }
    
    // Check for videos on the page
    async function checkForVideos() {
        if (!currentTab) return;
        
        const url = currentTab.url;
        
        // Check if it's a video platform
        if (isVideoPlatform(url)) {
            videoData = {
                url: url,
                title: currentTab.title,
                platform: getPlatform(url)
            };
            
            displayVideoInfo();
        }
    }
    
    // Display video information
    function displayVideoInfo() {
        if (!videoData) {
            videoInfo.innerHTML = '<div class="empty-state">No videos detected</div>';
            downloadVideoButton.style.display = 'none';
            return;
        }
        
        videoInfo.innerHTML = `
            <div class="link-item">
                <span class="link-icon">🎬</span>
                <span class="link-text">${videoData.title}</span>
            </div>
            <div style="padding: 10px; font-size: 12px; opacity: 0.8;">
                Platform: ${videoData.platform}<br>
                URL: ${videoData.url.substring(0, 50)}...
            </div>
        `;
        
        downloadVideoButton.style.display = 'block';
    }
    
    // Check if URL is a video platform
    function isVideoPlatform(url) {
        const platforms = [
            'youtube.com', 'youtu.be',
            'vimeo.com',
            'twitter.com', 'x.com',
            'instagram.com',
            'tiktok.com',
            'facebook.com',
            'twitch.tv'
        ];
        
        return platforms.some(platform => url.includes(platform));
    }
    
    // Get platform name from URL
    function getPlatform(url) {
        if (url.includes('youtube.com') || url.includes('youtu.be')) return 'YouTube';
        if (url.includes('vimeo.com')) return 'Vimeo';
        if (url.includes('twitter.com') || url.includes('x.com')) return 'Twitter/X';
        if (url.includes('instagram.com')) return 'Instagram';
        if (url.includes('tiktok.com')) return 'TikTok';
        if (url.includes('facebook.com')) return 'Facebook';
        if (url.includes('twitch.tv')) return 'Twitch';
        return 'Unknown';
    }
    
    // Get icon for file type
    function getIcon(type) {
        const icons = {
            'video': '🎬',
            'audio': '🎵',
            'archive': '📦',
            'document': '📄',
            'image': '🖼️',
            'file': '📎'
        };
        return icons[type] || icons.file;
    }
    
    // Get filename from URL
    function getFilename(url) {
        try {
            const pathname = new URL(url).pathname;
            return pathname.split('/').pop() || 'download';
        } catch {
            return 'download';
        }
    }
    
    // Download single link
    async function downloadLink(url) {
        await chrome.runtime.sendMessage({
            action: 'downloadWithSwiftFetch',
            url: url,
            referrer: currentTab.url
        });
        
        // Show feedback
        showNotification('Download sent to SwiftFetch');
    }
    
    // Show notification
    function showNotification(message) {
        // Create a temporary notification element
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            z-index: 9999;
        `;
        notification.textContent = message;
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 2000);
    }
    
    // Event handlers
    scanButton.addEventListener('click', scanCurrentPage);
    
    downloadAllButton.addEventListener('click', async () => {
        if (detectedLinks.length > 0) {
            for (const link of detectedLinks) {
                await downloadLink(link.url);
            }
            showNotification(`Sent ${detectedLinks.length} downloads to SwiftFetch`);
        }
    });
    
    downloadVideoButton.addEventListener('click', async () => {
        if (videoData) {
            await chrome.runtime.sendMessage({
                action: 'downloadVideo',
                url: videoData.url,
                title: videoData.title
            });
            showNotification('Video sent to SwiftFetch for download');
        }
    });
    
    openAppButton.addEventListener('click', () => {
        // Try to open SwiftFetch via custom URL scheme
        chrome.tabs.create({
            url: 'swiftfetch://open'
        });
    });
    
    // Settings change handlers
    autoInterceptCheckbox.addEventListener('change', saveSettings);
    detectMediaCheckbox.addEventListener('change', saveSettings);
    notificationsCheckbox.addEventListener('change', saveSettings);
    
    // Initialize
    init();
});