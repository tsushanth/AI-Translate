import { TranslationLog } from '../types';
/**
 * Supabase service for logging translations
 */
declare class SupabaseService {
    private client;
    constructor();
    /**
     * Logs a translation to the database
     */
    logTranslation(log: Omit<TranslationLog, 'id' | 'created_at'>): Promise<void>;
    /**
     * Health check for Supabase connection
     */
    healthCheck(): Promise<boolean>;
}
export declare const supabaseService: SupabaseService;
export {};
//# sourceMappingURL=supabaseService.d.ts.map