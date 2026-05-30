// js/main.js
// Application entry + real orchestration (being restored)

(function() {
    'use strict';

    // Global preset helpers (keep working even in stub phase)
    window.applyMainApiPreset = function(key) {
        if (key === 'deepseek') {
            var ep = document.getElementById('apiEndpoint');
            var md = document.getElementById('modelName');
            if (ep) ep.value = 'https://api.deepseek.com';
            if (md) md.value = 'deepseek-chat';
        }
    };

    window.applySummarizeApiPreset = function(key) {
        if (key === 'deepseek') {
            var ep = document.getElementById('summarizeApiEndpoint');
            var md = document.getElementById('summarizeModel');
            if (ep) ep.value = 'https://api.deepseek.com';
            if (md) md.value = 'deepseek-chat';
        }
    };

    function bindEvents() {
        // This will be replaced by the full real bindEvents from the backup
        console.log('[main] bindEvents() running (partial)');

        // Basic critical buttons
        var sendBtn = document.getElementById('sendBtn');
        if (sendBtn) {
            sendBtn.addEventListener('click', function() {
                console.log('[main] Send clicked — full handler will be restored soon');
                // TODO: call real sendMessage() once migrated
            });
        }

        var newChatBtn = document.getElementById('newChatBtn');
        if (newChatBtn && window.newChat) {
            newChatBtn.addEventListener('click', function() { window.newChat(); });
        }

        var worldBookBtn = document.getElementById('worldBookBtn');
        if (worldBookBtn && window.openWorldBookModal) {
            worldBookBtn.addEventListener('click', window.openWorldBookModal);
        }

        var summarizeBtn = document.getElementById('summarizeBtn');
        if (summarizeBtn && window.openSummaryManager) {
            summarizeBtn.addEventListener('click', window.openSummaryManager);
        }

        // Settings buttons
        var topSettings = document.getElementById('topSettingsBtn');
        if (topSettings && dom.settingsModal) {
            topSettings.addEventListener('click', function() {
                dom.settingsModal.classList.remove('hidden');
            });
        }

        var sidebarSettings = document.getElementById('sidebarSettingsBtn');
        if (sidebarSettings && dom.settingsModal) {
            sidebarSettings.addEventListener('click', function() {
                dom.settingsModal.classList.remove('hidden');
            });
        }

        // Close buttons for settings
        if (dom.settingsCloseBtn && dom.settingsModal) {
            dom.settingsCloseBtn.addEventListener('click', function() {
                dom.settingsModal.classList.add('hidden');
            });
        }
        if (dom.settingsBackdrop && dom.settingsModal) {
            dom.settingsBackdrop.addEventListener('click', function() {
                dom.settingsModal.classList.add('hidden');
            });
        }

        // Hamburger
        var hamburger = document.getElementById('hamburgerBtn');
        if (hamburger && window.toggleSidebar) {
            hamburger.addEventListener('click', window.toggleSidebar);
        }
    }

    async function init() {
        console.log('[main] OpenTavern modular init starting...');

        if (window.cacheDom) window.cacheDom();
        if (window.initState) await window.initState();

        if (window.applyTranslations) window.applyTranslations();

        if (window.bindEvents) bindEvents();
        if (window.wireWorldBookListeners) window.wireWorldBookListeners();

        if (window.renderAll) window.renderAll();

        // Basic input state after load
        if (window.updateInputState) window.updateInputState();

        console.log('[main] Modular bootstrap complete.');
    }

    // Boot
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            init().catch(console.error);
        });
    } else {
        init().catch(console.error);
    }

    window.__OpenTavernInit = init;
})();
