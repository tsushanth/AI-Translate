"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const zod_1 = require("zod");
const ttsService_1 = require("../services/ttsService");
const errorHandler_1 = require("../middleware/errorHandler");
const logger_1 = require("../utils/logger");
const router = (0, express_1.Router)();
/**
 * Request validation schema for TTS
 */
const ttsRequestSchema = zod_1.z.object({
    text: zod_1.z
        .string()
        .min(1, 'Text is required')
        .max(5000, 'Text must be 5000 characters or less'),
    languageCode: zod_1.z
        .string()
        .min(2, 'Language code is required'),
    speakingRate: zod_1.z
        .number()
        .min(0.25)
        .max(4.0)
        .optional()
        .default(1.0),
    pitch: zod_1.z
        .number()
        .min(-20.0)
        .max(20.0)
        .optional()
        .default(0.0),
    deviceId: zod_1.z
        .string()
        .uuid('Device ID must be a valid UUID'),
});
/**
 * POST /v1/tts
 * Synthesizes speech from text and returns MP3 audio
 */
router.post('/', async (req, res, next) => {
    try {
        // Validate request body
        const validatedData = ttsRequestSchema.parse(req.body);
        const { text, languageCode, speakingRate, pitch, deviceId } = validatedData;
        // Check if language is supported
        if (!ttsService_1.ttsService.isLanguageSupported(languageCode)) {
            logger_1.logger.warn('TTS language not supported', { languageCode, deviceId });
            // Still try to synthesize - will fall back to English
        }
        // Synthesize speech
        const result = await ttsService_1.ttsService.synthesize({
            text,
            languageCode,
            speakingRate,
            pitch,
        });
        // Set headers for audio response
        res.set({
            'Content-Type': 'audio/mpeg',
            'Content-Length': result.audioContent.length.toString(),
            'X-Audio-Duration-Ms': result.durationMs?.toString() || '0',
            'Cache-Control': 'public, max-age=86400', // Cache for 24 hours
        });
        // Send audio data
        res.send(result.audioContent);
    }
    catch (error) {
        // Handle Google Cloud errors
        if (error.code === 3) {
            return next(errorHandler_1.ApiError.badRequest('Invalid language code for TTS'));
        }
        if (error.code === 8 || error.code === 429) {
            return next(errorHandler_1.ApiError.tooManyRequests('TTS quota exceeded'));
        }
        logger_1.logger.error('TTS endpoint error', {
            error: error.message,
            code: error.code,
        });
        next(error);
    }
});
/**
 * GET /v1/tts/languages
 * Returns list of supported TTS languages
 */
router.get('/languages', (_req, res) => {
    const languages = ttsService_1.ttsService.getSupportedLanguages();
    res.json({
        success: true,
        data: {
            languages,
            count: languages.length,
        },
    });
});
exports.default = router;
//# sourceMappingURL=tts.js.map