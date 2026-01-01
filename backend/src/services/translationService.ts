import { TranslationServiceClient } from '@google-cloud/translate';
import { config } from '../config';
import { TranslateParams, TranslateResult } from '../types';
import { logger } from '../utils/logger';

/**
 * Google Cloud Translation service wrapper
 */
class TranslationService {
  private client: TranslationServiceClient;
  private projectId: string;
  private location: string = 'global';

  constructor() {
    this.client = new TranslationServiceClient();
    this.projectId = config.google.projectId;
  }

  /**
   * Translates text from source language to target language
   */
  async translate(params: TranslateParams): Promise<TranslateResult> {
    const { text, sourceLanguage, targetLanguage, format = 'text' } = params;

    const startTime = Date.now();

    try {
      const parent = `projects/${this.projectId}/locations/${this.location}`;

      const request: any = {
        parent,
        contents: [text],
        targetLanguageCode: targetLanguage,
        mimeType: format === 'html' ? 'text/html' : 'text/plain',
      };

      // Only set source language if not auto-detect
      if (sourceLanguage !== 'auto') {
        request.sourceLanguageCode = sourceLanguage;
      }

      const [response] = await this.client.translateText(request);

      const translation = response.translations?.[0];

      if (!translation || !translation.translatedText) {
        throw new Error('No translation returned from API');
      }

      const result: TranslateResult = {
        translatedText: translation.translatedText,
        sourceLanguage: sourceLanguage === 'auto'
          ? translation.detectedLanguageCode || sourceLanguage
          : sourceLanguage,
        targetLanguage,
        characterCount: text.length,
      };

      // Add detected language info if auto-detect was used
      if (sourceLanguage === 'auto' && translation.detectedLanguageCode) {
        result.detectedLanguage = translation.detectedLanguageCode;
        // Google doesn't return confidence, so we don't set it
      }

      const duration = Date.now() - startTime;
      logger.debug('Translation completed', {
        sourceLanguage: result.sourceLanguage,
        targetLanguage,
        characterCount: result.characterCount,
        durationMs: duration,
      });

      return result;

    } catch (error: any) {
      const duration = Date.now() - startTime;
      logger.error('Translation failed', {
        error: error.message,
        sourceLanguage,
        targetLanguage,
        durationMs: duration,
      });
      throw error;
    }
  }

  /**
   * Gets list of supported languages
   */
  async getSupportedLanguages(): Promise<Array<{ code: string; name: string }>> {
    try {
      const parent = `projects/${this.projectId}/locations/${this.location}`;

      const [response] = await this.client.getSupportedLanguages({
        parent,
        displayLanguageCode: 'en',
      });

      return (response.languages || []).map((lang) => ({
        code: lang.languageCode || '',
        name: lang.displayName || lang.languageCode || '',
      }));

    } catch (error: any) {
      logger.error('Failed to get supported languages', { error: error.message });
      throw error;
    }
  }
}

export const translationService = new TranslationService();
