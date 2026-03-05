"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const zod_1 = require("zod");
const translationManager_1 = require("../services/translationManager");
const supabaseService_1 = require("../services/supabaseService");
const config_1 = require("../config");
const errorHandler_1 = require("../middleware/errorHandler");
const router = (0, express_1.Router)();
/**
 * Request validation schema
 */
const translateRequestSchema = zod_1.z.object({
    text: zod_1.z
        .string()
        .min(config_1.config.translation.minCharacters, 'Text is required')
        .max(config_1.config.translation.maxCharacters, `Text must be ${config_1.config.translation.maxCharacters} characters or less`),
    sourceLanguage: zod_1.z
        .string()
        .min(2, 'Source language is required'),
    targetLanguage: zod_1.z
        .string()
        .min(2, 'Target language is required'),
    deviceId: zod_1.z
        .string()
        .uuid('Device ID must be a valid UUID'),
    provider: zod_1.z
        .enum(['google', 'deepl'])
        .optional()
        .default('google'),
    options: zod_1.z
        .object({
        format: zod_1.z.enum(['text', 'html']).optional(),
    })
        .optional(),
});
/**
 * POST /v1/translate
 * Translates text from source language to target language
 */
router.post('/', async (req, res, next) => {
    const startTime = Date.now();
    try {
        // Validate request body
        const validatedData = translateRequestSchema.parse(req.body);
        const { text, sourceLanguage, targetLanguage, deviceId, provider, options } = validatedData;
        // Perform translation using the specified provider
        const result = await translationManager_1.translationManager.translate({
            text,
            sourceLanguage,
            targetLanguage,
            format: options?.format,
        }, provider);
        const processingTimeMs = Date.now() - startTime;
        // Log translation to Supabase (non-blocking)
        supabaseService_1.supabaseService.logTranslation({
            device_id: deviceId,
            source_text: text,
            translated_text: result.translatedText,
            source_language: result.sourceLanguage,
            target_language: result.targetLanguage,
            detected_language: result.detectedLanguage || null,
            character_count: result.characterCount,
            processing_time_ms: processingTimeMs,
            request_id: req.requestId,
            provider: result.provider,
        }).catch(() => {
            // Silently ignore logging errors
        });
        // Build response
        const responseData = {
            translatedText: result.translatedText,
            sourceLanguage: result.sourceLanguage,
            targetLanguage: result.targetLanguage,
            characterCount: result.characterCount,
            provider: result.provider,
        };
        if (result.detectedLanguage) {
            responseData.detectedLanguage = result.detectedLanguage;
        }
        const response = {
            success: true,
            data: responseData,
            meta: {
                requestId: req.requestId,
                processingTimeMs,
            },
        };
        res.json(response);
    }
    catch (error) {
        // Handle API errors
        if (error.code && typeof error.code === 'number') {
            if (error.code === 3) {
                return next(errorHandler_1.ApiError.badRequest('Invalid language code'));
            }
            if (error.code === 8) {
                return next(errorHandler_1.ApiError.tooManyRequests('Translation quota exceeded'));
            }
        }
        // Handle DeepL errors
        if (error.message?.includes('DeepL API error')) {
            return next(errorHandler_1.ApiError.badRequest(error.message));
        }
        next(error);
    }
});
/**
 * GET /v1/translate/providers
 * Returns list of available translation providers
 */
router.get('/providers', (_req, res) => {
    const providers = translationManager_1.translationManager.getAvailableProviders();
    res.json({
        success: true,
        data: {
            providers,
            default: 'google',
        },
    });
});
exports.default = router;
//# sourceMappingURL=translate.js.map