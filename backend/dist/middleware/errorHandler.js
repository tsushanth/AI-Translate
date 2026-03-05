"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = exports.ApiError = void 0;
const zod_1 = require("zod");
const logger_1 = require("../utils/logger");
/**
 * Custom API error class
 */
class ApiError extends Error {
    statusCode;
    code;
    details;
    constructor(statusCode, code, message, details) {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.details = details;
        this.name = 'ApiError';
    }
    static badRequest(message, details) {
        return new ApiError(400, 'BAD_REQUEST', message, details);
    }
    static unauthorized(message = 'Unauthorized') {
        return new ApiError(401, 'UNAUTHORIZED', message);
    }
    static notFound(message = 'Not found') {
        return new ApiError(404, 'NOT_FOUND', message);
    }
    static tooManyRequests(message = 'Too many requests') {
        return new ApiError(429, 'RATE_LIMITED', message);
    }
    static internal(message = 'Internal server error') {
        return new ApiError(500, 'INTERNAL_ERROR', message);
    }
}
exports.ApiError = ApiError;
/**
 * Global error handler middleware
 */
const errorHandler = (err, req, res, _next) => {
    const requestId = req.requestId || 'unknown';
    // Handle Zod validation errors
    if (err instanceof zod_1.ZodError) {
        const details = err.errors.map((e) => ({
            field: e.path.join('.'),
            message: e.message,
        }));
        const response = {
            success: false,
            error: {
                code: 'VALIDATION_ERROR',
                message: 'Invalid request data',
                details,
            },
            meta: { requestId },
        };
        res.status(400).json(response);
        return;
    }
    // Handle custom API errors
    if (err instanceof ApiError) {
        const response = {
            success: false,
            error: {
                code: err.code,
                message: err.message,
                details: err.details,
            },
            meta: { requestId },
        };
        res.status(err.statusCode).json(response);
        return;
    }
    // Handle unknown errors
    logger_1.logger.error('Unhandled error', {
        requestId,
        error: err.message,
        stack: err.stack,
    });
    const response = {
        success: false,
        error: {
            code: 'INTERNAL_ERROR',
            message: 'An unexpected error occurred',
        },
        meta: { requestId },
    };
    res.status(500).json(response);
};
exports.errorHandler = errorHandler;
//# sourceMappingURL=errorHandler.js.map