import { TranslationProvider, TranslationProviderParams, TranslationProviderResult } from './types';
/**
 * DeepL API provider
 * Docs: https://www.deepl.com/docs-api
 */
export declare class DeepLTranslationProvider implements TranslationProvider {
    name: string;
    private apiKey;
    private baseUrl;
    constructor(apiKey: string, useFreeApi?: boolean);
    private static readonly SUPPORTED_LANGUAGES;
    isLanguageSupported(code: string): boolean;
    private mapLanguageCode;
    translate(params: TranslationProviderParams): Promise<TranslationProviderResult>;
}
//# sourceMappingURL=deeplProvider.d.ts.map