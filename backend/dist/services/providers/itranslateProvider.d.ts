import { TranslationProvider, TranslationProviderParams, TranslationProviderResult } from './types';
/**
 * iTranslate API provider
 * Docs: https://developer.itranslate.com/
 */
export declare class ITranslateProvider implements TranslationProvider {
    name: string;
    private apiKey;
    private baseUrl;
    constructor(apiKey: string);
    translate(params: TranslationProviderParams): Promise<TranslationProviderResult>;
}
//# sourceMappingURL=itranslateProvider.d.ts.map