import { TranslationServiceClient } from '@google-cloud/translate';
import { config } from '../../config';
import { TranslationProvider, TranslationProviderParams, TranslationProviderResult } from './types';

/**
 * Google Cloud Translation API provider (Neural Machine Translation)
 */
export class GoogleTranslationProvider implements TranslationProvider {
  name = 'Google Cloud Translation';
  private client: TranslationServiceClient;
  private projectId: string;
  private location: string = 'global';

  constructor() {
    this.client = new TranslationServiceClient();
    this.projectId = config.google.projectId;
  }

  async translate(params: TranslationProviderParams): Promise<TranslationProviderResult> {
    const { text, sourceLanguage, targetLanguage } = params;
    const startTime = Date.now();

    const parent = `projects/${this.projectId}/locations/${this.location}`;

    const request: any = {
      parent,
      contents: [text],
      targetLanguageCode: targetLanguage,
      mimeType: 'text/plain',
    };

    if (sourceLanguage !== 'auto') {
      request.sourceLanguageCode = sourceLanguage;
    }

    const [response] = await this.client.translateText(request);
    const translation = response.translations?.[0];

    if (!translation || !translation.translatedText) {
      throw new Error('No translation returned from Google API');
    }

    const latencyMs = Date.now() - startTime;

    return {
      translatedText: translation.translatedText,
      sourceLanguage: sourceLanguage === 'auto'
        ? translation.detectedLanguageCode || sourceLanguage
        : sourceLanguage,
      targetLanguage,
      detectedLanguage: sourceLanguage === 'auto' && translation.detectedLanguageCode
        ? translation.detectedLanguageCode
        : undefined,
      characterCount: text.length,
      provider: this.name,
      latencyMs,
    };
  }
}
