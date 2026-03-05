/**
 * Application configuration object
 * Provides typed access to all configuration values
 */
export declare const config: {
    readonly server: {
        readonly port: number;
        readonly nodeEnv: "development" | "production" | "test";
        readonly isDev: boolean;
        readonly isProd: boolean;
    };
    readonly google: {
        readonly projectId: string;
    };
    readonly deepl: {
        readonly apiKey: string | undefined;
        readonly useFreeApi: boolean;
        readonly isEnabled: boolean;
    };
    readonly supabase: {
        readonly url: string;
        readonly serviceKey: string;
    };
    readonly rateLimit: {
        readonly windowMs: number;
        readonly maxRequests: number;
    };
    readonly features: {
        readonly enableTranslationLogging: boolean;
    };
    readonly translation: {
        readonly maxCharacters: 5000;
        readonly minCharacters: 1;
        readonly supportedFormats: readonly ["text", "html"];
    };
};
export type Config = typeof config;
//# sourceMappingURL=index.d.ts.map