// js/ui.js
// Real UI layer (gradually being restored)
// Currently: solid cacheDom + safe renderAll + basic helpers

var dom = {};

function cacheDom() {
    dom = {
        sidebar: document.getElementById('sidebar'),
        convList: document.getElementById('convList'),
        noConvHint: document.getElementById('noConvHint'),
        messagesContainer: document.getElementById('messagesContainer'),
        emptyState: document.getElementById('emptyState'),
        messageInput: document.getElementById('messageInput'),
        sendBtn: document.getElementById('sendBtn'),
        stopBtn: document.getElementById('stopBtn'),
        chatTitle: document.getElementById('chatTitle'),
        chatSubtitle: document.getElementById('chatSubtitle'),
        charAvatar: document.getElementById('charAvatar'),
        tokenInfo: document.getElementById('tokenInfo'),
        tokenCount: document.getElementById('tokenCount'),
        tokenBar: document.getElementById('tokenBar'),
        tokenMax: document.getElementById('tokenMax'),

        // Modals
        settingsModal: document.getElementById('settingsModal'),
        settingsCloseBtn: document.getElementById('settingsCloseBtn'),
        settingsBackdrop: document.getElementById('settingsBackdrop'),

        importModal: document.getElementById('importModal'),
        importCloseBtn: document.getElementById('importCloseBtn'),
        importBackdrop: document.getElementById('importBackdrop'),
        importFileInput: document.getElementById('importFileInput'),

        charEditorModal: document.getElementById('charEditorModal'),
        charEditorCloseBtn: document.getElementById('charEditorCloseBtn'),
        charEditorBackdrop: document.getElementById('charEditorBackdrop'),
        charEditorCancelBtn: document.getElementById('charEditorCancelBtn'),
        charEditorSaveBtn: document.getElementById('charEditorSaveBtn'),

        worldBookModal: document.getElementById('worldBookModal'),
        worldBookBackdrop: document.getElementById('worldBookBackdrop'),
        worldBookBtn: document.getElementById('worldBookBtn'),
        wiCloseBtn: document.getElementById('wiCloseBtn'),

        summaryManagerModal: document.getElementById('summaryManagerModal'),
        summaryManagerCloseBtn: document.getElementById('summaryManagerCloseBtn'),
        summaryManagerBackdrop: document.getElementById('summaryManagerBackdrop'),

        announceModal: document.getElementById('announceModal'),
        announceCloseBtn: document.getElementById('announceCloseBtn'),
        announceBackdrop: document.getElementById('announceBackdrop'),
        announceGotItBtn: document.getElementById('announceGotItBtn'),
        announceDontShow: document.getElementById('announceDontShow'),

        // Character card UI
        charCardPreview: document.getElementById('charCardPreview'),
        charCardEmptyHint: document.getElementById('charCardEmptyHint'),
        charCardAvatar: document.getElementById('charCardAvatar'),
        charCardName: document.getElementById('charCardName'),
        charCardTagCount: document.getElementById('charCardTagCount'),
        charCardPersonality: document.getElementById('charCardPersonality'),
        charCardActions: document.getElementById('charCardActions'),
        charEditBtn: document.getElementById('charEditBtn'),
        charExportBtn: document.getElementById('charExportBtn'),
        charRemoveBtn: document.getElementById('charRemoveBtn'),
        charImportBtn: document.getElementById('charImportBtn'),
        charCreateBtn: document.getElementById('charCreateBtn'),

        // Top bar
        topSettingsBtn: document.getElementById('topSettingsBtn'),
        sidebarSettingsBtn: document.getElementById('sidebarSettingsBtn'),
        viewPromptBtn: document.getElementById('viewPromptBtn'),
        archiveBtn: document.getElementById('archiveBtn'),
        summarizeBtn: document.getElementById('summarizeBtn'),
        githubBtn: document.getElementById('githubBtn'),

        // Misc
        storageStatus: document.getElementById('storageStatus'),
        wiEntryCount: document.getElementById('wiEntryCount'),
        newChatBtn: document.getElementById('newChatBtn'),
        hamburgerBtn: document.getElementById('hamburgerBtn'),
        sidebarCloseBtn: document.getElementById('sidebarCloseBtn'),
        sidebarBackdrop: document.getElementById('sidebarBackdrop'),
    };

    // console.log('[ui] cacheDom executed (real elements cached)');
}

function renderAll() {
    // Safe no-op versions until full render functions are migrated
    try { if (typeof renderConversationList === 'function') renderConversationList(); } catch(e){}
    try { if (typeof renderMessages === 'function') renderMessages(); } catch(e){}
    try { if (typeof renderCharacterCard === 'function') renderCharacterCard(); } catch(e){}
    try { if (typeof renderTopBar === 'function') renderTopBar(); } catch(e){}
    try { if (typeof renderTokenBar === 'function') renderTokenBar(); } catch(e){}
    try { if (typeof updateInputState === 'function') updateInputState(); } catch(e){}
    try { if (typeof renderWorldInfoBudgetWarning === 'function') renderWorldInfoBudgetWarning(); } catch(e){}
}

function renderMessagesOnly() { /* will be replaced by real version */ }
function renderConversationListOnly() { /* will be replaced */ }
function renderCharacterUI() { if (typeof renderCharacterCard === 'function') renderCharacterCard(); }
function renderTopBar() { /* placeholder */ }
function renderTokenBar() { /* placeholder */ }
function updateInputState() {
    if (!dom.messageInput || !dom.sendBtn) return;
    var hasApi = !!(state.settings && state.settings.apiKey && state.settings.apiEndpoint);
    dom.messageInput.disabled = !hasApi || !!state.isGenerating;
    dom.sendBtn.disabled = !hasApi || !!state.isGenerating;
}

function openModal(modalEl) {
    if (modalEl) modalEl.classList.remove('hidden');
}
function closeModal(modalEl) {
    if (modalEl) modalEl.classList.add('hidden');
}

// Expose
window.dom = dom;
window.cacheDom = cacheDom;
window.renderAll = renderAll;
window.renderMessagesOnly = renderMessagesOnly;
window.renderConversationListOnly = renderConversationListOnly;
window.renderCharacterUI = renderCharacterUI;
window.updateInputState = updateInputState;
