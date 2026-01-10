import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { ttsService } from '../services/ttsService';
import { ApiError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

/**
 * Request validation schema for TTS
 */
const ttsRequestSchema = z.object({
  text: z
    .string()
    .min(1, 'Text is required')
    .max(5000, 'Text must be 5000 characters or less'),
  languageCode: z
    .string()
    .min(2, 'Language code is required'),
  speakingRate: z
    .number()
    .min(0.25)
    .max(4.0)
    .optional()
    .default(1.0),
  pitch: z
    .number()
    .min(-20.0)
    .max(20.0)
    .optional()
    .default(0.0),
  deviceId: z
    .string()
    .uuid('Device ID must be a valid UUID'),
});

/**
 * POST /v1/tts
 * Synthesizes speech from text and returns MP3 audio
 */
router.post(
  '/',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      // Validate request body
      const validatedData = ttsRequestSchema.parse(req.body);
      const { text, languageCode, speakingRate, pitch, deviceId } = validatedData;

      // Check if language is supported
      if (!ttsService.isLanguageSupported(languageCode)) {
        logger.warn('TTS language not supported', { languageCode, deviceId });
        // Still try to synthesize - will fall back to English
      }

      // Synthesize speech
      const result = await ttsService.synthesize({
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

    } catch (error: any) {
      // Handle Google Cloud errors
      if (error.code === 3) {
        return next(ApiError.badRequest('Invalid language code for TTS'));
      }
      if (error.code === 8 || error.code === 429) {
        return next(ApiError.tooManyRequests('TTS quota exceeded'));
      }

      logger.error('TTS endpoint error', {
        error: error.message,
        code: error.code,
      });

      next(error);
    }
  }
);

/**
 * GET /v1/tts/languages
 * Returns list of supported TTS languages
 */
router.get(
  '/languages',
  (_req: Request, res: Response): void => {
    const languages = ttsService.getSupportedLanguages();
    res.json({
      success: true,
      data: {
        languages,
        count: languages.length,
      },
    });
  }
);

export default router;
