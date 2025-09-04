// SwiftFetch Chrome Extension - Content Script
// Runs on all web pages to detect downloads and videos

(function() {
    'use strict';

    // Video detection patterns
    const VIDEO_PATTERNS = [
        /\.(mp4|webm|ogg|mov|avi|mkv|flv|wmv|m4v|mpg|mpeg)(\?.*)?$/i,
        /\.(mp3|wav|flac|aac|ogg|wma|m4a|opus)(\?.*)?$/i,
    ];

    const LARGE_FILE_PATTERNS = [
        /\.(zip|rar|7z|tar|gz|bz2|xz)(\?.*)?$/i,
        /\.(dmg|exe|msi|deb|rpm|pkg|app)(\?.*)?$/i,
        /\.(iso|img|bin|cue)(\?.*)?$/i,
    ];

    // Track all downloadable links
    let downloadableLinks = new Set();

    // Scan page for downloadable links
    function scanForDownloads() {
        const links = document.querySelectorAll('a[href]');
        downloadableLinks.clear();
        
        links.forEach(link => {
            const href = link.href;
            if (isDownloadableLink(href)) {
                downloadableLinks.add({
                    url: href,
                    text: link.textContent.trim() || 'Untitled',
                    type: getFileType(href)
                });
            }
        });

        // Send to background script
        if (downloadableLinks.size > 0) {
            chrome.runtime.sendMessage({
                action: 'updateDownloadableLinks',
                links: Array.from(downloadableLinks)
            });
        }
    }

    // Check if URL is likely a download
    function isDownloadableLink(url) {
        if (!url || url.startsWith('javascript:') || url.startsWith('#')) {
            return false;
        }

        // Check file extensions
        const allPatterns = [...VIDEO_PATTERNS, ...LARGE_FILE_PATTERNS];
        return allPatterns.some(pattern => pattern.test(url));
    }

    // Get file type from URL
    function getFileType(url) {
        if (VIDEO_PATTERNS.some(p => p.test(url))) {
            return url.match(/\.(mp4|webm|ogg|mov|avi|mkv|flv|wmv|m4v|mpg|mpeg)/i) ? 'video' : 'audio';
        }
        if (LARGE_FILE_PATTERNS.some(p => p.test(url))) {
            return 'archive';
        }
        return 'file';
    }

    // Intercept clicks on download links
    document.addEventListener('click', function(e) {
        const link = e.target.closest('a[href]');
        if (!link) return;

        const href = link.href;
        
        // Check if it's a downloadable link
        if (isDownloadableLink(href)) {
            // Check if extension context is still valid
            if (!chrome.runtime?.id) {
                console.log('Extension context invalidated, skipping interception');
                return;
            }
            
            try {
                // Ask background script if we should intercept
                chrome.runtime.sendMessage({
                    action: 'shouldIntercept',
                    url: href
                }, response => {
                    // Check for chrome.runtime.lastError
                    if (chrome.runtime.lastError) {
                        console.log('Runtime error:', chrome.runtime.lastError.message);
                        return;
                    }
                    
                    if (response && response.intercept) {
                        e.preventDefault();
                        e.stopPropagation();
                        
                        // Send to SwiftFetch
                        chrome.runtime.sendMessage({
                            action: 'downloadWithSwiftFetch',
                            url: href,
                            filename: link.download || link.textContent.trim(),
                            referrer: window.location.href
                        });
                    }
                });
            } catch (error) {
                console.log('Error sending message:', error);
            }
        }
    }, true);

    // Detect video elements (HTML5)
    function detectVideoElements() {
        const videos = document.querySelectorAll('video[src], video source[src]');
        const videoUrls = [];

        videos.forEach(video => {
            const src = video.src || (video.querySelector('source') && video.querySelector('source').src);
            if (src && !src.startsWith('blob:')) {
                videoUrls.push({
                    url: src,
                    type: 'video',
                    poster: video.poster || null,
                    title: document.title
                });
            }
        });

        if (videoUrls.length > 0) {
            chrome.runtime.sendMessage({
                action: 'videosDetected',
                videos: videoUrls
            });
        }
    }

    // Detect YouTube/video platform
    function detectVideoPlatform() {
        const hostname = window.location.hostname;
        const platforms = {
            'youtube.com': 'youtube',
            'www.youtube.com': 'youtube',
            'm.youtube.com': 'youtube',
            'youtu.be': 'youtube',
            'vimeo.com': 'vimeo',
            'dailymotion.com': 'dailymotion',
            'twitter.com': 'twitter',
            'x.com': 'twitter',
            'instagram.com': 'instagram',
            'tiktok.com': 'tiktok',
            'facebook.com': 'facebook',
            'twitch.tv': 'twitch'
        };

        const platform = platforms[hostname];
        if (platform) {
            // Get video info based on platform
            const videoInfo = extractVideoInfo(platform);
            if (videoInfo) {
                chrome.runtime.sendMessage({
                    action: 'platformVideoDetected',
                    platform: platform,
                    info: videoInfo
                });
            }
        }
    }

    // Extract video information based on platform
    function extractVideoInfo(platform) {
        const info = {
            url: window.location.href,
            title: document.title,
            platform: platform
        };

        switch(platform) {
            case 'youtube':
                // YouTube specific extraction
                const videoId = new URLSearchParams(window.location.search).get('v') || 
                               window.location.pathname.split('/').pop();
                if (videoId) {
                    info.videoId = videoId;
                    info.thumbnail = `https://i.ytimg.com/vi/${videoId}/maxresdefault.jpg`;
                    
                    // Try to get video title from page
                    const titleElement = document.querySelector('h1.title, h1 yt-formatted-string, meta[name="title"]');
                    if (titleElement) {
                        info.title = titleElement.textContent || titleElement.content || document.title;
                    }
                }
                break;

            case 'twitter':
                // Twitter/X video detection
                const tweetId = window.location.pathname.match(/status\/(\d+)/);
                if (tweetId) {
                    info.tweetId = tweetId[1];
                }
                break;

            case 'instagram':
                // Instagram post/reel detection
                const postId = window.location.pathname.match(/\/(p|reel)\/([A-Za-z0-9_-]+)/);
                if (postId) {
                    info.postId = postId[2];
                    info.type = postId[1];
                }
                break;
        }

        return info;
    }

    // Listen for messages from background script
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
        // Check if extension context is still valid
        if (!chrome.runtime?.id) {
            console.log('Extension context invalidated');
            return;
        }
        
        switch(request.action) {
            case 'scanPage':
                scanForDownloads();
                detectVideoElements();
                detectVideoPlatform();
                sendResponse({success: true});
                break;
                
            case 'getPageInfo':
                sendResponse({
                    title: document.title,
                    url: window.location.href,
                    links: Array.from(downloadableLinks)
                });
                break;
                
            case 'getAllLinks':
                const allLinks = Array.from(document.querySelectorAll('a[href]')).map(link => ({
                    url: link.href,
                    text: link.textContent.trim() || link.href,
                    download: link.download || null
                }));
                sendResponse(allLinks);
                break;
        }
    });

    // Initial scan
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            scanForDownloads();
            detectVideoElements();
            detectVideoPlatform();
        });
    } else {
        scanForDownloads();
        detectVideoElements();
        detectVideoPlatform();
    }

    // Monitor for dynamic content
    const observer = new MutationObserver(() => {
        scanForDownloads();
        detectVideoElements();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

})();