import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

import { config } from './config';
import { logger } from './utils/logger';
import { requestIdMiddleware } from './middleware/requestId';
import { errorHandler } from './middleware/errorHandler';
import translateRouter from './routes/translate';
import languagesRouter from './routes/languages';
import ttsRouter from './routes/tts';

// Create Express app
const app = express();

// Trust proxy for Cloud Run (needed for rate limiting)
app.set('trust proxy', 1);

// Security middleware
app.use(helmet());
app.use(cors({
  origin: '*', // Allow all origins for mobile app
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Request parsing
app.use(express.json({ limit: '100kb' }));

// Request ID middleware
app.use(requestIdMiddleware);

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
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
app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env['npm_package_version'] || '1.0.0',
  });
});

// API routes
app.use('/v1/translate', translateRouter);
app.use('/v1/languages', languagesRouter);
app.use('/v1/tts', ttsRouter);

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: 'The requested resource was not found',
    },
  });
});

// Error handler (must be last)
app.use(errorHandler);

// Start server
const port = config.server.port;

app.listen(port, () => {
  logger.info(`Server started`, {
    port,
    environment: config.server.nodeEnv,
    projectId: config.google.projectId,
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});
