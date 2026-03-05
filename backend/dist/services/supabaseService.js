"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.supabaseService = void 0;
const supabase_js_1 = require("@supabase/supabase-js");
const config_1 = require("../config");
const logger_1 = require("../utils/logger");
/**
 * Supabase service for logging translations
 */
class SupabaseService {
    client;
    constructor() {
        this.client = (0, supabase_js_1.createClient)(config_1.config.supabase.url, config_1.config.supabase.serviceKey, {
            auth: {
                autoRefreshToken: false,
                persistSession: false,
            },
        });
    }
    /**
     * Logs a translation to the database
     */
    async logTranslation(log) {
        if (!config_1.config.features.enableTranslationLogging) {
            logger_1.logger.debug('Translation logging disabled, skipping');
            return;
        }
        try {
            const { error } = await this.client
                .from('translation_logs')
                .insert(log);
            if (error) {
                logger_1.logger.error('Failed to log translation', {
                    error: error.message,
                    code: error.code,
                });
                // Don't throw - logging failure shouldn't break the translation
            }
            else {
                logger_1.logger.debug('Translation logged successfully', {
                    requestId: log.request_id,
                });
            }
        }
        catch (error) {
            logger_1.logger.error('Supabase error', { error: error.message });
            // Don't throw - logging failure shouldn't break the translation
        }
    }
    /**
     * Health check for Supabase connection
     */
    async healthCheck() {
        try {
            const { error } = await this.client
                .from('translation_logs')
                .select('id')
                .limit(1);
            return !error;
        }
        catch {
            return false;
        }
    }
}
exports.supabaseService = new SupabaseService();
//# sourceMappingURL=supabaseService.js.map