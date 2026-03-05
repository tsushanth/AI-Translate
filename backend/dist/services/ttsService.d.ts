export interface TTSParams {
    text: string;
    languageCode: string;
    speakingRate?: number;
    pitch?: number;
}
export interface TTSResult {
    audioContent: Buffer;
    audioEncoding: string;
    durationMs?: number;
}
declare class TextToSpeechService {
    private client;
    constructor();
    /**
     * Synthesizes speech from text
     * @returns Audio content as a Buffer (MP3 format)
     */
    synthesize(params: TTSParams): Promise<TTSResult>;
    /**
     * Gets the best voice configuration for a language code
     */
    private getVoiceConfig;
    /**
     * Checks if a language is supported for TTS
     */
    isLanguageSupported(languageCode: string): boolean;
    /**
     * Gets list of supported languages
     */
    getSupportedLanguages(): string[];
}
export declare const ttsService: TextToSpeechService;
export {};
//# sourceMappingURL=ttsService.d.ts.map