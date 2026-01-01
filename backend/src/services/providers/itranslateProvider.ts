import { TranslationProvider, TranslationProviderParams, TranslationProviderResult } from './types';

/**
 * iTranslate API provider
 * Docs: https://developer.itranslate.com/
 */
export class ITranslateProvider implements TranslationProvider {
  name = 'iTranslate';
  private apiKey: string;
  private baseUrl = 'https://dev-api.itranslate.com/translation/v2/';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async translate(params: TranslationProviderParams): Promise<TranslationProviderResult> {
    const { text, sourceLanguage, targetLanguage } = params;
    const startTime = Date.now();

    const body = {
      source: {
        dialect: sourceLanguage === 'auto' ? 'auto' : sourceLanguage,
        text: text,
      },
      target: {
        dialect: targetLanguage,
      },
    };

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`iTranslate API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json() as {
      source: {
        dialect: string;
        text: string;
      };
      target: {
        dialect: string;
        text: string;
      };
      times?: {
        total_time: number;
      };
    };

    if (!data.target?.text) {
      throw new Error('No translation returned from iTranslate API');
    }

    const latencyMs = Date.now() - startTime;

    return {
      translatedText: data.target.text,
      sourceLanguage: data.source.dialect || sourceLanguage,
      targetLanguage: data.target.dialect || targetLanguage,
      detectedLanguage: sourceLanguage === 'auto' ? data.source.dialect : undefined,
      characterCount: text.length,
      provider: this.name,
      latencyMs,
    };
  }
}
