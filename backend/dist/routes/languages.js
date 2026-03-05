"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const router = (0, express_1.Router)();
/**
 * Static list of commonly supported languages with metadata
 * This provides a consistent response while the dynamic list can be fetched from Google
 */
const SUPPORTED_LANGUAGES = [
    { code: 'en', name: 'English', nativeName: 'English', rtl: false },
    { code: 'es', name: 'Spanish', nativeName: 'Español', rtl: false },
    { code: 'fr', name: 'French', nativeName: 'Français', rtl: false },
    { code: 'de', name: 'German', nativeName: 'Deutsch', rtl: false },
    { code: 'it', name: 'Italian', nativeName: 'Italiano', rtl: false },
    { code: 'pt', name: 'Portuguese', nativeName: 'Português', rtl: false },
    { code: 'ru', name: 'Russian', nativeName: 'Русский', rtl: false },
    { code: 'zh', name: 'Chinese', nativeName: '中文', rtl: false },
    { code: 'ja', name: 'Japanese', nativeName: '日本語', rtl: false },
    { code: 'ko', name: 'Korean', nativeName: '한국어', rtl: false },
    { code: 'ar', name: 'Arabic', nativeName: 'العربية', rtl: true },
    { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', rtl: false },
    { code: 'nl', name: 'Dutch', nativeName: 'Nederlands', rtl: false },
    { code: 'pl', name: 'Polish', nativeName: 'Polski', rtl: false },
    { code: 'tr', name: 'Turkish', nativeName: 'Türkçe', rtl: false },
    { code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', rtl: false },
    { code: 'th', name: 'Thai', nativeName: 'ไทย', rtl: false },
    { code: 'sv', name: 'Swedish', nativeName: 'Svenska', rtl: false },
    { code: 'da', name: 'Danish', nativeName: 'Dansk', rtl: false },
    { code: 'fi', name: 'Finnish', nativeName: 'Suomi', rtl: false },
    { code: 'no', name: 'Norwegian', nativeName: 'Norsk', rtl: false },
    { code: 'cs', name: 'Czech', nativeName: 'Čeština', rtl: false },
    { code: 'el', name: 'Greek', nativeName: 'Ελληνικά', rtl: false },
    { code: 'he', name: 'Hebrew', nativeName: 'עברית', rtl: true },
    { code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', rtl: false },
    { code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', rtl: false },
    { code: 'ro', name: 'Romanian', nativeName: 'Română', rtl: false },
    { code: 'uk', name: 'Ukrainian', nativeName: 'Українська', rtl: false },
    { code: 'hu', name: 'Hungarian', nativeName: 'Magyar', rtl: false },
    { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', rtl: false },
];
/**
 * GET /v1/languages
 * Returns list of supported languages
 */
router.get('/', async (req, res, next) => {
    try {
        const response = {
            success: true,
            data: {
                languages: SUPPORTED_LANGUAGES,
            },
            meta: {
                requestId: req.requestId,
            },
        };
        res.json(response);
    }
    catch (error) {
        next(error);
    }
});
exports.default = router;
//# sourceMappingURL=languages.js.map