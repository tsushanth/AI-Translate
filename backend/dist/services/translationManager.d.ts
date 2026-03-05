import { TranslateParams, TranslateResult, TranslationProvider as ProviderType } from '../types';
/**
 * Translation manager that routes requests to the appropriate provider
 */
declare class TranslationManager {
    private googleProvider;
    private deeplProvider;
    constructor();
    /**
     * Get list of available providers
     */
    getAvailableProviders(): ProviderType[];
    /**
     * Check if a provider is available
     */
    isProviderAvailable(provider: ProviderType): boolean;
    /**
     * Check if DeepL supports the given language pair
     */
    private isDeepLLanguageSupported;
    /**
     * Translate text using the specified provider
     */
    translate(params: TranslateParams, provider?: ProviderType): Promise<TranslateResult & {
        provider: ProviderType;
    }>;
    private getProvider;
}
export declare const translationManager: TranslationManager;
export {};
//# sourceMappingURL=translationManager.d.ts.map