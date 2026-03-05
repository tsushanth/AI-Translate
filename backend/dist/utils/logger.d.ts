/**
 * Simple structured logger for Cloud Run
 * Outputs JSON in production for Cloud Logging integration
 */
declare class Logger {
    private formatLog;
    private output;
    private formatDev;
    debug(message: string, meta?: Record<string, unknown>): void;
    info(message: string, meta?: Record<string, unknown>): void;
    warn(message: string, meta?: Record<string, unknown>): void;
    error(message: string, meta?: Record<string, unknown>): void;
}
export declare const logger: Logger;
export {};
//# sourceMappingURL=logger.d.ts.map