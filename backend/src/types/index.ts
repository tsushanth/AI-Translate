/**
 * Type definitions for the translation backend API
 */

// =============================================================================
// Request/Response Types
// =============================================================================

/** Supported translation providers */
export type TranslationProvider = 'google' | 'deepl';

/**
 * Request body for POST /v1/translate
 */
export interface TranslateRequestBody {
  /** Text to translate (1-5000 characters) */
  text: string;

  /** Source language code (ISO 639-1) or "auto" for detection */
  sourceLanguage: string;

  /** Target language code (ISO 639-1) */
  targetLanguage: string;

  /** Anonymous device identifier (UUID v4) */
  deviceId: string;

  /** Translation provider to use (default: "google") */
  provider?: TranslationProvider;

  /** Optional configuration */
  options?: {
    /** Content format: "text" (default) or "html" */
    format?: 'text' | 'html';
  };
}

/**
 * Successful translation response data
 */
export interface TranslateResponseData {
  /** Translated text */
  translatedText: string;

  /** Source language (resolved if "auto" was requested) */
  sourceLanguage: string;

  /** Target language */
  targetLanguage: string;

  /** Detected language (if sourceLanguage was "auto") */
  detectedLanguage?: string;

  /** Detection confidence (0-1, if detected) */
  confidence?: number;

  /** Character count of source text */
  characterCount: number;

  /** Translation provider used */
  provider: TranslationProvider;
}

/**
 * Response metadata
 */
export interface ResponseMeta {
  /** Unique request identifier for debugging */
  requestId: string;

  /** Server processing time in milliseconds */
  processingTimeMs?: number;
}

/**
 * Successful API response
 */
export interface SuccessResponse<T> {
  success: true;
  data: T;
  meta: ResponseMeta;
}

/**
 * Error details for validation errors
 */
export interface ValidationErrorDetail {
  field: string;
  message: string;
}

/**
 * Error response structure
 */
export interface ErrorResponseBody {
  success: false;
  error: {
    code: string;
    message: string;
    details?: ValidationErrorDetail[] | Record<string, unknown>;
  };
  meta: ResponseMeta;
}

// =============================================================================
// Language Types
// =============================================================================

/**
 * Language information
 */
export interface Language {
  /** ISO 639-1 language code */
  code: string;

  /** English display name */
  name: string;

  /** Native display name */
  nativeName: string;

  /** Whether language uses RTL script */
  rtl: boolean;
}

/**
 * Response for GET /v1/languages
 */
export interface LanguagesResponseData {
  languages: Language[];
}

// =============================================================================
// Database Types (Supabase)
// =============================================================================

/**
 * Translation log record for Supabase
 */
export interface TranslationLog {
  id?: string;
  device_id: string;
  source_text: string;
  translated_text: string;
  source_language: string;
  target_language: string;
  detected_language?: string | null;
  character_count: number;
  processing_time_ms: number;
  request_id: string;
  provider: string;
  created_at?: string;
}

/**
 * Supabase database schema types
 */
export interface Database {
  public: {
    Tables: {
      translation_logs: {
        Row: TranslationLog;
        Insert: Omit<TranslationLog, 'id' | 'created_at'>;
        Update: Partial<TranslationLog>;
      };
    };
  };
}

// =============================================================================
// Service Types
// =============================================================================

/**
 * Parameters for translation service
 */
export interface TranslateParams {
  text: string;
  sourceLanguage: string;
  targetLanguage: string;
  format?: 'text' | 'html';
}

/**
 * Result from translation service
 */
export interface TranslateResult {
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  detectedLanguage?: string;
  confidence?: number;
  characterCount: number;
}

// =============================================================================
// Express Extensions
// =============================================================================

declare global {
  namespace Express {
    interface Request {
      /** Unique request ID for tracing */
      requestId: string;
    }
  }
}
