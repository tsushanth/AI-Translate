import { ErrorRequestHandler } from 'express';
/**
 * Custom API error class
 */
export declare class ApiError extends Error {
    statusCode: number;
    code: string;
    details?: any | undefined;
    constructor(statusCode: number, code: string, message: string, details?: any | undefined);
    static badRequest(message: string, details?: any): ApiError;
    static unauthorized(message?: string): ApiError;
    static notFound(message?: string): ApiError;
    static tooManyRequests(message?: string): ApiError;
    static internal(message?: string): ApiError;
}
/**
 * Global error handler middleware
 */
export declare const errorHandler: ErrorRequestHandler;
//# sourceMappingURL=errorHandler.d.ts.map