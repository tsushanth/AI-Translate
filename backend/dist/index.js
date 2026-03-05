"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const config_1 = require("./config");
const logger_1 = require("./utils/logger");
const requestId_1 = require("./middleware/requestId");
const errorHandler_1 = require("./middleware/errorHandler");
const translate_1 = __importDefault(require("./routes/translate"));
const languages_1 = __importDefault(require("./routes/languages"));
const tts_1 = __importDefault(require("./routes/tts"));
// Create Express app
const app = (0, express_1.default)();
// Trust proxy for Cloud Run (needed for rate limiting)
app.set('trust proxy', 1);
// Security middleware
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)({
    origin: '*', // Allow all origins for mobile app
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
}));
// Request parsing
app.use(express_1.default.json({ limit: '100kb' }));
// Request ID middleware
app.use(requestId_1.requestIdMiddleware);
// Rate limiting
const limiter = (0, express_rate_limit_1.default)({
    windowMs: config_1.config.rateLimit.windowMs,
    max: config_1.config.rateLimit.maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        success: false,
        error: {
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'Too many requests, please try again later',
        },
    },
    keyGenerator: (req) => {
        // Use device ID from body if available, otherwise use IP
        const deviceId = req.body?.deviceId;
        return deviceId || req.ip || 'unknown';
    },
});
app.use('/v1', limiter);
// Health check endpoint (no rate limiting)
app.get('/health', (_req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env['npm_package_version'] || '1.0.0',
    });
});
// API routes
app.use('/v1/translate', translate_1.default);
app.use('/v1/languages', languages_1.default);
app.use('/v1/tts', tts_1.default);
// 404 handler
app.use((_req, res) => {
    res.status(404).json({
        success: false,
        error: {
            code: 'NOT_FOUND',
            message: 'The requested resource was not found',
        },
    });
});
// Error handler (must be last)
app.use(errorHandler_1.errorHandler);
// Start server
const port = config_1.config.server.port;
app.listen(port, () => {
    logger_1.logger.info(`Server started`, {
        port,
        environment: config_1.config.server.nodeEnv,
        projectId: config_1.config.google.projectId,
    });
});
// Graceful shutdown
process.on('SIGTERM', () => {
    logger_1.logger.info('SIGTERM received, shutting down gracefully');
    process.exit(0);
});
process.on('SIGINT', () => {
    logger_1.logger.info('SIGINT received, shutting down gracefully');
    process.exit(0);
});
//# sourceMappingURL=index.js.map