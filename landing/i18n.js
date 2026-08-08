const translations = {
  en: {
    'meta.title': 'Enjoy Player — Language Learning Player',
    'meta.desc': 'Enjoy Player is a cross-platform language-learning player for audio and video with transcript, echo mode, and YouTube support. Available for Windows, macOS, Android, and iOS.',
    
    'hero.title': 'Enjoy Player',
    'hero.tagline': 'A cross-platform language-learning player for audio & video',
    'hero.cta': 'Download Now',
    'hero.secondary_cta': 'View Features',
    'hero.nojs': 'Enable JavaScript to get direct download links, or visit the download directory.',
    
    'features.title': 'Features',
    'features.transcripts.title': 'Interactive Transcripts',
    'features.transcripts.desc': 'Follow along with automatically synced subtitles (SRT/VTT). Click any word to jump to that exact moment in the video or audio.',
    'features.echo.title': 'Echo Mode',
    'features.echo.desc': 'Practice speaking with line-bounded shadow reading. Listen, record, and compare your pronunciation.',
    'features.youtube.title': 'YouTube Support',
    'features.youtube.desc': 'Learn from any YouTube video with dual-engine playback and integrated transcripts.',
    'features.dictionary.title': 'Dictionary Lookup',
    'features.dictionary.desc': 'Instant definitions and translations without leaving the player. Build your vocabulary seamlessly.',
    'features.sync.title': 'Cross-Platform Sync',
    'features.sync.desc': 'Your progress, library, and settings sync across Windows, macOS, Linux, Android, and iOS.',
    
    'download.title': 'Download',
    'download.windows.title': 'Windows',
    'download.windows.subtitle': 'Windows 10 / 11 · x64',
    'download.windows.btn': 'Download for Windows',
    
    'download.macos.title': 'macOS',
    'download.macos.subtitle': 'macOS 10.15+ · Universal',
    'download.macos.btn': 'Download for macOS',
    
    'download.android.title': 'Android',
    'download.android.subtitle': 'Android 8.0+',
    'download.android.btn.apk': 'Download APK',
    'download.android.btn.play': 'Join Play Beta',
    'download.android.note': 'Tip: installing the APK requires enabling <em>Install unknown apps</em> in your Android settings.',
    
    'download.ios.title': 'iOS',
    'download.ios.subtitle': 'iOS 14.0+',
    'download.ios.btn': 'Join TestFlight',
    'download.ios.note': 'TestFlight public beta is live. App Store release coming soon.',
    
    'download.comingSoon': 'Coming soon',
    
    'download.linux.title': 'Linux',
    'download.linux.subtitle': 'Ubuntu 22.04 LTS · x86_64',
    'download.linux.btn': 'Download for Linux',
    'download.linux.note': 'AppImage: <code>chmod +x enjoy-player-*.AppImage && ./enjoy-player-*.AppImage</code>',
    
    'recommended': 'Recommended',
    'footer.copyright': '© 2026 Enjoy Player'
  },
  zh: {
    'meta.title': 'Enjoy Player — 跨平台音视频语言学习播放器',
    'meta.desc': 'Enjoy Player 是一款跨平台音视频语言学习播放器，支持交互式字幕、跟读模式和 YouTube 播放。支持 Windows、macOS、Linux、Android 和 iOS。',
    
    'hero.title': 'Enjoy Player',
    'hero.tagline': '跨平台音视频语言学习播放器',
    'hero.cta': '立即下载',
    'hero.secondary_cta': '查看功能',
    'hero.nojs': '请启用 JavaScript 以获取直接下载链接，或访问下载目录。',
    
    'features.title': '核心功能',
    'features.transcripts.title': '交互式字幕',
    'features.transcripts.desc': '自动同步字幕 (SRT/VTT)。点击任何单词即可跳转到音视频中的精确时刻。',
    'features.echo.title': '跟读模式',
    'features.echo.desc': '通过逐句影子跟读练习口语。聆听、录音并对比你的发音。',
    'features.youtube.title': 'YouTube 支持',
    'features.youtube.desc': '支持播放任何 YouTube 视频，双引擎播放并集成字幕功能。',
    'features.dictionary.title': '划词翻译',
    'features.dictionary.desc': '无需离开播放器即可获得即时释义和翻译，无缝积累词汇量。',
    'features.sync.title': '跨平台同步',
    'features.sync.desc': '你的学习进度、媒体库和设置会在 Windows、macOS、Linux、Android 和 iOS 之间无缝同步。',
    
    'download.title': '下载',
    'download.windows.title': 'Windows',
    'download.windows.subtitle': 'Windows 10 / 11 · x64',
    'download.windows.btn': '下载 Windows 版',
    
    'download.macos.title': 'macOS',
    'download.macos.subtitle': 'macOS 10.15+ · Universal',
    'download.macos.btn': '下载 macOS 版',
    
    'download.android.title': 'Android',
    'download.android.subtitle': 'Android 8.0+',
    'download.android.btn.apk': '下载 APK',
    'download.android.btn.play': '加入 Play Beta',
    'download.android.note': '提示：安装 APK 需要在 Android 设置中开启<em>允许安装未知应用</em>。',
    
    'download.ios.title': 'iOS',
    'download.ios.subtitle': 'iOS 14.0+',
    'download.ios.btn': '加入 TestFlight',
    'download.ios.note': 'TestFlight 公开测试已上线，App Store 版本即将推出。',
    
    'download.comingSoon': '即将推出',
    
    'download.linux.title': 'Linux',
    'download.linux.subtitle': 'Ubuntu 22.04 LTS · x86_64',
    'download.linux.btn': '下载 Linux 版',
    'download.linux.note': 'AppImage: <code>chmod +x enjoy-player-*.AppImage && ./enjoy-player-*.AppImage</code>',
    
    'recommended': '推荐',
    'footer.copyright': '© 2026 Enjoy Player'
  }
};

function setLanguage(lang) {
  if (!translations[lang]) lang = 'en';
  document.documentElement.lang = lang;
  localStorage.setItem('enjoy_lang', lang);
  
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (translations[lang][key]) {
      // Use innerHTML if the translation contains HTML tags (like <em>)
      if (translations[lang][key].includes('<')) {
        el.innerHTML = translations[lang][key];
      } else {
        el.textContent = translations[lang][key];
      }
    }
  });

  // Update meta tags
  if (translations[lang]['meta.title']) {
    document.title = translations[lang]['meta.title'];
    const ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle) ogTitle.content = translations[lang]['meta.title'];
    const twTitle = document.querySelector('meta[name="twitter:title"]');
    if (twTitle) twTitle.content = translations[lang]['meta.title'];
  }
  
  if (translations[lang]['meta.desc']) {
    const desc = document.querySelector('meta[name="description"]');
    if (desc) desc.content = translations[lang]['meta.desc'];
    const ogDesc = document.querySelector('meta[property="og:description"]');
    if (ogDesc) ogDesc.content = translations[lang]['meta.desc'];
    const twDesc = document.querySelector('meta[name="twitter:description"]');
    if (twDesc) twDesc.content = translations[lang]['meta.desc'];
  }

  // Update active state of language switcher buttons
  document.querySelectorAll('.lang-btn').forEach(btn => {
    if (btn.dataset.lang === lang) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
}

function initI18n() {
  // Determine initial language
  let lang = localStorage.getItem('enjoy_lang');
  if (!lang) {
    const browserLang = navigator.language || navigator.userLanguage;
    lang = browserLang.toLowerCase().startsWith('zh') ? 'zh' : 'en';
  }
  setLanguage(lang);

  // Bind language switcher events
  document.querySelectorAll('.lang-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      setLanguage(btn.dataset.lang);
    });
  });
}

// Export for use in main.js
window.initI18n = initI18n;
window.setLanguage = setLanguage;
window.translations = translations;
