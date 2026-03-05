import { TranslateParams, TranslateResult } from '../types';
/**
 * Google Cloud Translation service wrapper
 */
declare class TranslationService {
    private client;
    private projectId;
    private location;
    constructor();
    /**
     * Translates text from source language to target language
     */
    translate(params: TranslateParams): Promise<TranslateResult>;
    /**
     * Gets list of supported languages
     */
    getSupportedLanguages(): Promise<Array<{
        code: string;
        name: string;
    }>>;
}
export declare const translationService: TranslationService;
export {};
//# sourceMappingURL=translationService.d.ts.map