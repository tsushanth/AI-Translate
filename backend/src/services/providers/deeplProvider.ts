import { TranslationProvider, TranslationProviderParams, TranslationProviderResult } from './types';

/**
 * DeepL API provider
 * Docs: https://www.deepl.com/docs-api
 */
export class DeepLTranslationProvider implements TranslationProvider {
  name = 'DeepL';
  private apiKey: string;
  private baseUrl: string;

  constructor(apiKey: string, useFreeApi: boolean = false) {
    this.apiKey = apiKey;
    // DeepL has different endpoints for free vs pro API
    this.baseUrl = useFreeApi
      ? 'https://api-free.deepl.com/v2'
      : 'https://api.deepl.com/v2';
  }

  // Map common language codes to DeepL format
  private mapLanguageCode(code: string, isTarget: boolean): string {
    const mappings: Record<string, string> = {
      'en': isTarget ? 'EN-US' : 'EN', // DeepL requires EN-US or EN-GB for target
      'pt': isTarget ? 'PT-BR' : 'PT', // Portuguese Brazil for target
      'zh': 'ZH',
    };
    return mappings[code.toLowerCase()] || code.toUpperCase();
  }

  async translate(params: TranslationProviderParams): Promise<TranslationProviderResult> {
    const { text, sourceLanguage, targetLanguage } = params;
    const startTime = Date.now();

    const body: Record<string, string | string[]> = {
      text: [text],
      target_lang: this.mapLanguageCode(targetLanguage, true),
    };

    if (sourceLanguage !== 'auto') {
      body['source_lang'] = this.mapLanguageCode(sourceLanguage, false);
    }

    const response = await fetch(`${this.baseUrl}/translate`, {
      method: 'POST',
      headers: {
        'Authorization': `DeepL-Auth-Key ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`DeepL API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json() as {
      translations: Array<{
        detected_source_language: string;
        text: string;
      }>;
    };

    const translation = data.translations?.[0];
    if (!translation) {
      throw new Error('No translation returned from DeepL API');
    }

    const latencyMs = Date.now() - startTime;

    return {
      translatedText: translation.text,
      sourceLanguage: sourceLanguage === 'auto'
        ? translation.detected_source_language.toLowerCase()
        : sourceLanguage,
      targetLanguage,
      detectedLanguage: sourceLanguage === 'auto'
        ? translation.detected_source_language.toLowerCase()
        : undefined,
      characterCount: text.length,
      provider: this.name,
      latencyMs,
    };
  }
}
