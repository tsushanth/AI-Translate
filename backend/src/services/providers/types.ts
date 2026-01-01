/**
 * Common types for translation providers
 */

export interface TranslationProviderResult {
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  detectedLanguage?: string;
  characterCount: number;
  provider: string;
  latencyMs: number;
}

export interface TranslationProviderParams {
  text: string;
  sourceLanguage: string;
  targetLanguage: string;
}

export interface TranslationProvider {
  name: string;
  translate(params: TranslationProviderParams): Promise<TranslationProviderResult>;
}
