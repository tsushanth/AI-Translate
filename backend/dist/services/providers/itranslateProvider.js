"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ITranslateProvider = void 0;
/**
 * iTranslate API provider
 * Docs: https://developer.itranslate.com/
 */
class ITranslateProvider {
    name = 'iTranslate';
    apiKey;
    baseUrl = 'https://dev-api.itranslate.com/translation/v2/';
    constructor(apiKey) {
        this.apiKey = apiKey;
    }
    async translate(params) {
        const { text, sourceLanguage, targetLanguage } = params;
        const startTime = Date.now();
        const body = {
            source: {
                dialect: sourceLanguage === 'auto' ? 'auto' : sourceLanguage,
                text: text,
            },
            target: {
                dialect: targetLanguage,
            },
        };
        const response = await fetch(this.baseUrl, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.apiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
        });
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`iTranslate API error: ${response.status} - ${errorText}`);
        }
        const data = await response.json();
        if (!data.target?.text) {
            throw new Error('No translation returned from iTranslate API');
        }
        const latencyMs = Date.now() - startTime;
        return {
            translatedText: data.target.text,
            sourceLanguage: data.source.dialect || sourceLanguage,
            targetLanguage: data.target.dialect || targetLanguage,
            detectedLanguage: sourceLanguage === 'auto' ? data.source.dialect : undefined,
            characterCount: text.length,
            provider: this.name,
            latencyMs,
        };
    }
}
exports.ITranslateProvider = ITranslateProvider;
//# sourceMappingURL=itranslateProvider.js.map