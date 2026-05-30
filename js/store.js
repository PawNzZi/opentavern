// js/store.js
// Real state management migrated from original monolithic code
// Includes: createReactiveStore, appStore, state, defaultSettings, defaultConversation,
// persistState, initState, getActiveConv, applyTranslations, setLanguage, etc.

function defaultSettings() {
    return {
        apiEndpoint: 'https://api.openai.com/v1/chat/completions',
        apiKey: '',
        saveApiKey: false,
        model: 'gpt-4o',
        contextLength: 10,
        maxTokens: 1024,
        temperature: 0.7,
        topP: 0.9,
        userName: 'User',
        systemPrompt: '',
        lang: 'zh-CN',
        summaryEnabled: true,
        autoSummarizeOnReply: false,
        summaryThreshold: 10,
        summaryMaxWords: 0,
        worldInfoBudgetEnabled: true,
        worldInfoBudget: 2048,
        summarizeUseMainAPI: true,
        summarizeApiEndpoint: '',
        summarizeApiKey: '',
        summarizeModel: 'deepseek-chat'
    };
}

function defaultConversation() {
    return {
        id: makeId(),
        title: 'New Chat',
        character: null,
        messages: [],
        summaries: [],
        worldInfo: null,
        worldBookIds: [],
        created: Date.now(),
        updated: Date.now()
    };
}

// Returns a copy of settings with API keys stripped unless user explicitly opted in.
function getSafeSettingsForPersist() {
    var s = JSON.parse(JSON.stringify(state.settings || {}));
    if (!s.saveApiKey) {
        s.apiKey = '';
        s.summarizeApiKey = '';
    }
    return s;
}

// Reactive store (non-Proxy version, explicit notifications)
function createReactiveStore(initialState) {
    var state = JSON.parse(JSON.stringify(initialState || {}));
    var listeners = {};
    var globalListeners = new Set();

    function notify(changedKeys) {
        changedKeys.forEach(function(key) {
            if (listeners[key]) {
                listeners[key].forEach(function(fn) {
                    try { fn(key); } catch (e) { console.error(e); }
                });
            }
        });
        globalListeners.forEach(function(fn) {
            try { fn(changedKeys); } catch (e) { console.error(e); }
        });
    }

    return {
        get state() { return state; },

        subscribe: function(keyOrFn, callback) {
            if (typeof keyOrFn === 'function') {
                globalListeners.add(keyOrFn);
                return function() { globalListeners.delete(keyOrFn); };
            }
            var key = keyOrFn;
            if (!listeners[key]) listeners[key] = new Set();
            listeners[key].add(callback);
            return function() {
                if (listeners[key]) listeners[key].delete(callback);
            };
        },

        notify: function(keys) {
            var arr = Array.isArray(keys) ? keys : [keys];
            notify(arr);
        }
    };
}

var appStore = createReactiveStore({
    settings: defaultSettings(),
    conversations: {},
    conversationOrder: [],
    activeConvId: null,
    worldBooks: {},
    isGenerating: false
});

var state = appStore.state;

// Manual render subscription map (for backward compatibility with old code)
var renderSubscriptions = {
    'settings': function() {},
    'conversations': function() {},
    'activeConvId': function() {},
    'isGenerating': function() {}
};

async function initState() {
    let migrationResult = { attempted: false, success: false, backend: 'localStorage' };

    try {
        const idbReady = await StorageService.initIndexedDB();
        if (idbReady) {
            const idbData = await StorageService.loadAllFromIDB();
            const hasConversations = idbData && Object.keys(idbData.conversations || {}).length > 0;

            if (!hasConversations) {
                console.log('[Storage] No IndexedDB data found. Attempting migration...');
                migrationResult.attempted = true;
                const migrated = await StorageService.migrateFromLocalStorage();
                migrationResult.success = migrated;
                migrationResult.backend = migrated ? 'indexeddb' : 'localStorage';
                if (migrated) window._showStorageMigrationNotice = true;
            } else {
                StorageService._useIndexedDB = true;
                migrationResult.backend = 'indexeddb';
            }
        }
    } catch (err) {
        console.warn('[Storage] IndexedDB init failed, falling back to localStorage:', err);
        migrationResult.backend = 'localStorage';
        migrationResult.migrationFailed = true;
        window._showStorageMigrationWarning = true;
    }

    const saved = await StorageService.loadAll();

    if (saved) {
        if (saved.settings) {
            Object.keys(saved.settings).forEach(function(key) {
                state.settings[key] = saved.settings[key];
            });
        }
        if (saved.conversations) state.conversations = saved.conversations;
        if (saved.conversationOrder) state.conversationOrder = saved.conversationOrder;
        if (saved.activeConvId && state.conversations[saved.activeConvId]) {
            state.activeConvId = saved.activeConvId;
        }
        if (saved.worldBooks) state.worldBooks = saved.worldBooks;
    }

    if (migrationResult.success) {
        await StorageService.saveAll({
            settings: getSafeSettingsForPersist(),
            conversations: state.conversations,
            conversationOrder: state.conversationOrder,
            activeConvId: state.activeConvId,
            worldBooks: state.worldBooks || {}
        });
    }

    state._storageMigration = migrationResult;

    if (!state.settings.lang) state.settings.lang = 'zh-CN';

    var hadApiKey = !!(state.settings && state.settings.apiKey);
    if (typeof state.settings.saveApiKey === 'undefined') {
        state.settings.saveApiKey = hadApiKey;
    }
    if (!state.settings.saveApiKey) {
        state.settings.apiKey = '';
        state.settings.summarizeApiKey = '';
    }

    if (!state.activeConvId || !state.conversations[state.activeConvId]) {
        var conv = defaultConversation();
        state.conversations[conv.id] = conv;
        state.conversationOrder.unshift(conv.id);
        state.activeConvId = conv.id;
    }
}

var _persistTimeout = null;

function persistState(immediate) {
    const dataToSave = {
        settings: getSafeSettingsForPersist(),
        conversations: state.conversations,
        conversationOrder: state.conversationOrder,
        activeConvId: state.activeConvId,
        worldBooks: state.worldBooks || {}
    };

    if (immediate) {
        if (_persistTimeout) {
            clearTimeout(_persistTimeout);
            _persistTimeout = null;
        }
        StorageService.saveAll(dataToSave);
        return;
    }

    if (_persistTimeout) clearTimeout(_persistTimeout);
    _persistTimeout = setTimeout(function() {
        StorageService.saveAll(dataToSave);
        _persistTimeout = null;
    }, 500);
}

function getActiveConv() {
    return state.conversations[state.activeConvId];
}

function applyTranslations() {
    document.querySelectorAll('[data-i18n]').forEach(function(el) {
        var key = el.getAttribute('data-i18n');
        var trans = t(key);
        if (trans) el.textContent = trans;
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function(el) {
        var key = el.getAttribute('data-i18n-placeholder');
        var trans = t(key);
        if (trans) el.placeholder = trans;
    });
    document.querySelectorAll('[data-i18n-title]').forEach(function(el) {
        var key = el.getAttribute('data-i18n-title');
        var trans = t(key);
        if (trans) el.title = trans;
    });
}

function setLanguage(lang) {
    state.settings.lang = lang;
    document.documentElement.lang = lang;

    document.querySelectorAll('.lang-btn').forEach(function(btn) {
        var btnLang = btn.getAttribute('data-lang');
        if (btnLang === lang) {
            btn.classList.add('active', 'text-zinc-900');
            btn.classList.remove('text-zinc-400');
        } else {
            btn.classList.remove('active', 'text-zinc-900');
            btn.classList.add('text-zinc-400');
        }
    });

    applyTranslations();
    if (window.renderAll) renderAll();
    persistState();
}

// Expose
window.appStore = appStore;
window.state = state;
window.defaultSettings = defaultSettings;
window.defaultConversation = defaultConversation;
window.persistState = persistState;
window.initState = initState;
window.getActiveConv = getActiveConv;
window.applyTranslations = applyTranslations;
window.setLanguage = setLanguage;
window.getSafeSettingsForPersist = getSafeSettingsForPersist;
