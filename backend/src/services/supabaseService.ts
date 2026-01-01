import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { config } from '../config';
import { TranslationLog } from '../types';
import { logger } from '../utils/logger';

/**
 * Supabase service for logging translations
 */
class SupabaseService {
  private client: SupabaseClient;

  constructor() {
    this.client = createClient(
      config.supabase.url,
      config.supabase.serviceKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );
  }

  /**
   * Logs a translation to the database
   */
  async logTranslation(log: Omit<TranslationLog, 'id' | 'created_at'>): Promise<void> {
    if (!config.features.enableTranslationLogging) {
      logger.debug('Translation logging disabled, skipping');
      return;
    }

    try {
      const { error } = await this.client
        .from('translation_logs')
        .insert(log as Record<string, unknown>);

      if (error) {
        logger.error('Failed to log translation', {
          error: error.message,
          code: error.code,
        });
        // Don't throw - logging failure shouldn't break the translation
      } else {
        logger.debug('Translation logged successfully', {
          requestId: log.request_id,
        });
      }
    } catch (error: any) {
      logger.error('Supabase error', { error: error.message });
      // Don't throw - logging failure shouldn't break the translation
    }
  }

  /**
   * Health check for Supabase connection
   */
  async healthCheck(): Promise<boolean> {
    try {
      const { error } = await this.client
        .from('translation_logs')
        .select('id')
        .limit(1);

      return !error;
    } catch {
      return false;
    }
  }
}

export const supabaseService = new SupabaseService();
