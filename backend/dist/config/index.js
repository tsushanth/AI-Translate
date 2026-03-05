"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const zod_1 = require("zod");
/**
 * Environment variable schema validation using Zod
 * Ensures all required configuration is present at startup
 */
const envSchema = zod_1.z.object({
    // Server
    PORT: zod_1.z.string().default('8080'),
    NODE_ENV: zod_1.z.enum(['development', 'production', 'test']).default('production'),
    // Google Cloud
    GOOGLE_CLOUD_PROJECT: zod_1.z.string().min(1, 'GOOGLE_CLOUD_PROJECT is required'),
    // DeepL (optional)
    DEEPL_API_KEY: zod_1.z.string().optional(),
    DEEPL_FREE: zod_1.z.string().default('true'),
    // Supabase
    SUPABASE_URL: zod_1.z.string().url('SUPABASE_URL must be a valid URL'),
    SUPABASE_SERVICE_KEY: zod_1.z.string().min(1, 'SUPABASE_SERVICE_KEY is required'),
    // Rate Limiting
    RATE_LIMIT_WINDOW_MS: zod_1.z.string().default('60000'),
    RATE_LIMIT_MAX_REQUESTS: zod_1.z.string().default('100'),
    // Feature Flags
    ENABLE_TRANSLATION_LOGGING: zod_1.z.string().default('true'),
});
/**
 * Parse and validate environment variables
 * Exits process with error if validation fails
 */
function parseEnv() {
    const result = envSchema.safeParse(process.env);
    if (!result.success) {
        console.error('❌ Invalid environment variables:');
        console.error(JSON.stringify(result.error.format(), null, 2));
        process.exit(1);
    }
    return result.data;
}
const env = parseEnv();
/**
 * Application configuration object
 * Provides typed access to all configuration values
 */
exports.config = {
    server: {
        port: parseInt(env.PORT, 10),
        nodeEnv: env.NODE_ENV,
        isDev: env.NODE_ENV === 'development',
        isProd: env.NODE_ENV === 'production',
    },
    google: {
        projectId: env.GOOGLE_CLOUD_PROJECT,
    },
    deepl: {
        apiKey: env.DEEPL_API_KEY,
        useFreeApi: env.DEEPL_FREE === 'true',
        isEnabled: !!env.DEEPL_API_KEY,
    },
    supabase: {
        url: env.SUPABASE_URL,
        serviceKey: env.SUPABASE_SERVICE_KEY,
    },
    rateLimit: {
        windowMs: parseInt(env.RATE_LIMIT_WINDOW_MS, 10),
        maxRequests: parseInt(env.RATE_LIMIT_MAX_REQUESTS, 10),
    },
    features: {
        enableTranslationLogging: env.ENABLE_TRANSLATION_LOGGING === 'true',
    },
    translation: {
        maxCharacters: 5000,
        minCharacters: 1,
        supportedFormats: ['text', 'html'],
    },
};
//# sourceMappingURL=index.js.map