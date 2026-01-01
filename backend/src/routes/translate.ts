import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { translationManager } from '../services/translationManager';
import { supabaseService } from '../services/supabaseService';
import { config } from '../config';
import { ApiError } from '../middleware/errorHandler';
import { SuccessResponse, TranslateResponseData, TranslationProvider } from '../types';

const router = Router();

/**
 * Request validation schema
 */
const translateRequestSchema = z.object({
  text: z
    .string()
    .min(config.translation.minCharacters, 'Text is required')
    .max(config.translation.maxCharacters, `Text must be ${config.translation.maxCharacters} characters or less`),
  sourceLanguage: z
    .string()
    .min(2, 'Source language is required'),
  targetLanguage: z
    .string()
    .min(2, 'Target language is required'),
  deviceId: z
    .string()
    .uuid('Device ID must be a valid UUID'),
  provider: z
    .enum(['google', 'deepl'])
    .optional()
    .default('google'),
  options: z
    .object({
      format: z.enum(['text', 'html']).optional(),
    })
    .optional(),
});

/**
 * POST /v1/translate
 * Translates text from source language to target language
 */
router.post(
  '/',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const startTime = Date.now();

    try {
      // Validate request body
      const validatedData = translateRequestSchema.parse(req.body);

      const { text, sourceLanguage, targetLanguage, deviceId, provider, options } = validatedData;

      // Perform translation using the specified provider
      const result = await translationManager.translate(
        {
          text,
          sourceLanguage,
          targetLanguage,
          format: options?.format,
        },
        provider as TranslationProvider
      );

      const processingTimeMs = Date.now() - startTime;

      // Log translation to Supabase (non-blocking)
      supabaseService.logTranslation({
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
      const responseData: TranslateResponseData = {
        translatedText: result.translatedText,
        sourceLanguage: result.sourceLanguage,
        targetLanguage: result.targetLanguage,
        characterCount: result.characterCount,
        provider: result.provider,
      };

      if (result.detectedLanguage) {
        responseData.detectedLanguage = result.detectedLanguage;
      }

      const response: SuccessResponse<TranslateResponseData> = {
        success: true,
        data: responseData,
        meta: {
          requestId: req.requestId,
          processingTimeMs,
        },
      };

      res.json(response);

    } catch (error: any) {
      // Handle API errors
      if (error.code && typeof error.code === 'number') {
        if (error.code === 3) {
          return next(ApiError.badRequest('Invalid language code'));
        }
        if (error.code === 8) {
          return next(ApiError.tooManyRequests('Translation quota exceeded'));
        }
      }

      // Handle DeepL errors
      if (error.message?.includes('DeepL API error')) {
        return next(ApiError.badRequest(error.message));
      }

      next(error);
    }
  }
);

/**
 * GET /v1/translate/providers
 * Returns list of available translation providers
 */
router.get(
  '/providers',
  (_req: Request, res: Response): void => {
    const providers = translationManager.getAvailableProviders();
    res.json({
      success: true,
      data: {
        providers,
        default: 'google',
      },
    });
  }
);

export default router;
