import { TextToSpeechClient } from '@google-cloud/text-to-speech';
import { logger } from '../utils/logger';

type SsmlGender = 'MALE' | 'FEMALE' | 'NEUTRAL';

interface VoiceConfig {
  languageCode: string;
  name: string;
  ssmlGender: SsmlGender;
}

// Language to voice mapping for high-quality neural voices
const VOICE_MAP: Record<string, { languageCode: string; name: string; ssmlGender: 'MALE' | 'FEMALE' | 'NEUTRAL' }> = {
  // English variants
  'en': { languageCode: 'en-US', name: 'en-US-Neural2-J', ssmlGender: 'MALE' },
  'en-US': { languageCode: 'en-US', name: 'en-US-Neural2-J', ssmlGender: 'MALE' },
  'en-GB': { languageCode: 'en-GB', name: 'en-GB-Neural2-B', ssmlGender: 'MALE' },

  // Spanish
  'es': { languageCode: 'es-ES', name: 'es-ES-Neural2-B', ssmlGender: 'MALE' },
  'es-ES': { languageCode: 'es-ES', name: 'es-ES-Neural2-B', ssmlGender: 'MALE' },
  'es-MX': { languageCode: 'es-US', name: 'es-US-Neural2-B', ssmlGender: 'MALE' },

  // French
  'fr': { languageCode: 'fr-FR', name: 'fr-FR-Neural2-B', ssmlGender: 'MALE' },
  'fr-FR': { languageCode: 'fr-FR', name: 'fr-FR-Neural2-B', ssmlGender: 'MALE' },

  // German
  'de': { languageCode: 'de-DE', name: 'de-DE-Neural2-B', ssmlGender: 'MALE' },
  'de-DE': { languageCode: 'de-DE', name: 'de-DE-Neural2-B', ssmlGender: 'MALE' },

  // Italian
  'it': { languageCode: 'it-IT', name: 'it-IT-Neural2-C', ssmlGender: 'MALE' },
  'it-IT': { languageCode: 'it-IT', name: 'it-IT-Neural2-C', ssmlGender: 'MALE' },

  // Portuguese
  'pt': { languageCode: 'pt-BR', name: 'pt-BR-Neural2-B', ssmlGender: 'MALE' },
  'pt-BR': { languageCode: 'pt-BR', name: 'pt-BR-Neural2-B', ssmlGender: 'MALE' },
  'pt-PT': { languageCode: 'pt-PT', name: 'pt-PT-Neural2-B', ssmlGender: 'MALE' },

  // Russian
  'ru': { languageCode: 'ru-RU', name: 'ru-RU-Neural2-B', ssmlGender: 'MALE' },

  // Chinese
  'zh': { languageCode: 'cmn-CN', name: 'cmn-CN-Neural2-C', ssmlGender: 'MALE' },
  'zh-CN': { languageCode: 'cmn-CN', name: 'cmn-CN-Neural2-C', ssmlGender: 'MALE' },
  'zh-TW': { languageCode: 'cmn-TW', name: 'cmn-TW-Neural2-C', ssmlGender: 'MALE' },

  // Japanese
  'ja': { languageCode: 'ja-JP', name: 'ja-JP-Neural2-C', ssmlGender: 'MALE' },

  // Korean
  'ko': { languageCode: 'ko-KR', name: 'ko-KR-Neural2-C', ssmlGender: 'MALE' },

  // Arabic
  'ar': { languageCode: 'ar-XA', name: 'ar-XA-Neural2-C', ssmlGender: 'MALE' },

  // Hindi
  'hi': { languageCode: 'hi-IN', name: 'hi-IN-Neural2-B', ssmlGender: 'MALE' },

  // Dutch
  'nl': { languageCode: 'nl-NL', name: 'nl-NL-Neural2-C', ssmlGender: 'MALE' },

  // Polish
  'pl': { languageCode: 'pl-PL', name: 'pl-PL-Neural2-B', ssmlGender: 'MALE' },

  // Turkish
  'tr': { languageCode: 'tr-TR', name: 'tr-TR-Neural2-B', ssmlGender: 'MALE' },

  // Vietnamese
  'vi': { languageCode: 'vi-VN', name: 'vi-VN-Neural2-A', ssmlGender: 'FEMALE' },

  // Thai
  'th': { languageCode: 'th-TH', name: 'th-TH-Neural2-C', ssmlGender: 'FEMALE' },

  // Swedish
  'sv': { languageCode: 'sv-SE', name: 'sv-SE-Neural2-A', ssmlGender: 'FEMALE' },

  // Danish
  'da': { languageCode: 'da-DK', name: 'da-DK-Neural2-D', ssmlGender: 'FEMALE' },

  // Finnish
  'fi': { languageCode: 'fi-FI', name: 'fi-FI-Neural2-A', ssmlGender: 'FEMALE' },

  // Norwegian
  'no': { languageCode: 'nb-NO', name: 'nb-NO-Neural2-B', ssmlGender: 'MALE' },
  'nb': { languageCode: 'nb-NO', name: 'nb-NO-Neural2-B', ssmlGender: 'MALE' },

  // Czech
  'cs': { languageCode: 'cs-CZ', name: 'cs-CZ-Neural2-A', ssmlGender: 'FEMALE' },

  // Greek
  'el': { languageCode: 'el-GR', name: 'el-GR-Neural2-A', ssmlGender: 'FEMALE' },

  // Hebrew
  'he': { languageCode: 'he-IL', name: 'he-IL-Neural2-B', ssmlGender: 'MALE' },

  // Indonesian
  'id': { languageCode: 'id-ID', name: 'id-ID-Neural2-B', ssmlGender: 'MALE' },

  // Malay
  'ms': { languageCode: 'ms-MY', name: 'ms-MY-Neural2-B', ssmlGender: 'MALE' },

  // Romanian
  'ro': { languageCode: 'ro-RO', name: 'ro-RO-Neural2-A', ssmlGender: 'FEMALE' },

  // Ukrainian
  'uk': { languageCode: 'uk-UA', name: 'uk-UA-Neural2-A', ssmlGender: 'FEMALE' },

  // Hungarian
  'hu': { languageCode: 'hu-HU', name: 'hu-HU-Neural2-A', ssmlGender: 'FEMALE' },

  // Bengali
  'bn': { languageCode: 'bn-IN', name: 'bn-IN-Neural2-B', ssmlGender: 'MALE' },
};

export interface TTSParams {
  text: string;
  languageCode: string;
  speakingRate?: number; // 0.25 to 4.0, default 1.0
  pitch?: number; // -20.0 to 20.0, default 0.0
}

export interface TTSResult {
  audioContent: Buffer;
  audioEncoding: string;
  durationMs?: number;
}

class TextToSpeechService {
  private client: TextToSpeechClient;

  constructor() {
    // Client will use Application Default Credentials
    this.client = new TextToSpeechClient();
  }

  /**
   * Synthesizes speech from text
   * @returns Audio content as a Buffer (MP3 format)
   */
  async synthesize(params: TTSParams): Promise<TTSResult> {
    const { text, languageCode, speakingRate = 1.0, pitch = 0.0 } = params;
    const startTime = Date.now();

    // Get voice configuration for this language
    const voiceConfig = this.getVoiceConfig(languageCode);

    logger.info('TTS request', {
      languageCode,
      textLength: text.length,
      voiceName: voiceConfig.name,
    });

    try {
      const [response] = await this.client.synthesizeSpeech({
        input: { text },
        voice: {
          languageCode: voiceConfig.languageCode,
          name: voiceConfig.name,
          ssmlGender: voiceConfig.ssmlGender,
        },
        audioConfig: {
          audioEncoding: 'MP3',
          speakingRate: Math.max(0.25, Math.min(4.0, speakingRate)),
          pitch: Math.max(-20.0, Math.min(20.0, pitch)),
          effectsProfileId: ['small-bluetooth-speaker-class-device'], // Optimized for mobile
        },
      });

      const durationMs = Date.now() - startTime;

      logger.info('TTS completed', {
        languageCode,
        voiceName: voiceConfig.name,
        audioSize: response.audioContent ? (response.audioContent as Buffer).length : 0,
        durationMs,
      });

      return {
        audioContent: response.audioContent as Buffer,
        audioEncoding: 'MP3',
        durationMs,
      };
    } catch (error: any) {
      logger.error('TTS failed', {
        languageCode,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Gets the best voice configuration for a language code
   */
  private getVoiceConfig(languageCode: string): VoiceConfig {
    const normalizedCode = languageCode.toLowerCase();

    // Try exact match first
    const exactMatch = VOICE_MAP[normalizedCode];
    if (exactMatch) {
      return exactMatch;
    }

    // Try language prefix (e.g., "en" for "en-AU")
    const prefix = normalizedCode.split('-')[0] || normalizedCode;
    const prefixMatch = VOICE_MAP[prefix];
    if (prefixMatch) {
      return prefixMatch;
    }

    // Default to English if language not found
    logger.warn('No voice mapping found for language, defaulting to English', { languageCode });
    return VOICE_MAP['en']!;
  }

  /**
   * Checks if a language is supported for TTS
   */
  isLanguageSupported(languageCode: string): boolean {
    const normalizedCode = languageCode.toLowerCase();
    const prefix = normalizedCode.split('-')[0] || normalizedCode;
    return normalizedCode in VOICE_MAP || prefix in VOICE_MAP;
  }

  /**
   * Gets list of supported languages
   */
  getSupportedLanguages(): string[] {
    // Return unique language codes (without duplicates from variants)
    const languages = new Set<string>();
    for (const code of Object.keys(VOICE_MAP)) {
      const prefix = code.split('-')[0];
      if (prefix) {
        languages.add(prefix);
      }
    }
    return Array.from(languages).sort();
  }
}

export const ttsService = new TextToSpeechService();
