import { config } from '../config';
import { TranslateParams, TranslateResult, TranslationProvider as ProviderType } from '../types';
import { logger } from '../utils/logger';
import {
  GoogleTranslationProvider,
  DeepLTranslationProvider,
  TranslationProvider,
} from './providers';

/**
 * Translation manager that routes requests to the appropriate provider
 */
class TranslationManager {
  private googleProvider: GoogleTranslationProvider;
  private deeplProvider: DeepLTranslationProvider | null = null;

  constructor() {
    // Always initialize Google provider
    this.googleProvider = new GoogleTranslationProvider();

    // Initialize DeepL if configured
    if (config.deepl.isEnabled && config.deepl.apiKey) {
      this.deeplProvider = new DeepLTranslationProvider(
        config.deepl.apiKey,
        config.deepl.useFreeApi
      );
      logger.info('DeepL provider initialized');
    }
  }

  /**
   * Get list of available providers
   */
  getAvailableProviders(): ProviderType[] {
    const providers: ProviderType[] = ['google'];
    if (this.deeplProvider) {
      providers.push('deepl');
    }
    return providers;
  }

  /**
   * Check if a provider is available
   */
  isProviderAvailable(provider: ProviderType): boolean {
    if (provider === 'google') return true;
    if (provider === 'deepl') return this.deeplProvider !== null;
    return false;
  }

  /**
   * Check if DeepL supports the given language pair
   */
  private isDeepLLanguageSupported(sourceLanguage: string, targetLanguage: string): boolean {
    if (!this.deeplProvider) return false;

    // Auto-detect is always supported
    const sourceSupported = sourceLanguage === 'auto' || this.deeplProvider.isLanguageSupported(sourceLanguage);
    const targetSupported = this.deeplProvider.isLanguageSupported(targetLanguage);

    return sourceSupported && targetSupported;
  }

  /**
   * Translate text using the specified provider
   */
  async translate(
    params: TranslateParams,
    provider: ProviderType = 'google'
  ): Promise<TranslateResult & { provider: ProviderType }> {
    // Validate provider availability
    if (!this.isProviderAvailable(provider)) {
      logger.warn(`Provider ${provider} not available, falling back to google`);
      provider = 'google';
    }

    // Check if DeepL supports the language pair, fall back to Google if not
    if (provider === 'deepl' && !this.isDeepLLanguageSupported(params.sourceLanguage, params.targetLanguage)) {
      logger.info(`DeepL does not support language pair ${params.sourceLanguage} -> ${params.targetLanguage}, falling back to google`);
      provider = 'google';
    }

    const selectedProvider = this.getProvider(provider);
    const startTime = Date.now();

    try {
      const result = await selectedProvider.translate({
        text: params.text,
        sourceLanguage: params.sourceLanguage,
        targetLanguage: params.targetLanguage,
      });

      logger.info('Translation completed', {
        provider,
        sourceLanguage: result.sourceLanguage,
        targetLanguage: result.targetLanguage,
        characterCount: result.characterCount,
        latencyMs: result.latencyMs,
      });

      return {
        translatedText: result.translatedText,
        sourceLanguage: result.sourceLanguage,
        targetLanguage: result.targetLanguage,
        detectedLanguage: result.detectedLanguage,
        characterCount: result.characterCount,
        provider,
      };
    } catch (error: any) {
      const duration = Date.now() - startTime;
      logger.error('Translation failed', {
        provider,
        error: error.message,
        durationMs: duration,
      });
      throw error;
    }
  }

  private getProvider(provider: ProviderType): TranslationProvider {
    switch (provider) {
      case 'deepl':
        return this.deeplProvider!;
      case 'google':
      default:
        return this.googleProvider;
    }
  }
}

export const translationManager = new TranslationManager();
