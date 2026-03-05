import { TranslationProvider, TranslationProviderParams, TranslationProviderResult } from './types';
/**
 * Google Cloud Translation API provider (Neural Machine Translation)
 */
export declare class GoogleTranslationProvider implements TranslationProvider {
    name: string;
    private client;
    private projectId;
    private location;
    constructor();
    translate(params: TranslationProviderParams): Promise<TranslationProviderResult>;
}
//# sourceMappingURL=googleProvider.d.ts.map