import { config } from '../config';

/**
 * Log levels
 */
type LogLevel = 'debug' | 'info' | 'warn' | 'error';

/**
 * Structured log entry
 */
interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  [key: string]: unknown;
}

/**
 * Simple structured logger for Cloud Run
 * Outputs JSON in production for Cloud Logging integration
 */
class Logger {
  private formatLog(level: LogLevel, message: string, meta?: Record<string, unknown>): LogEntry {
    return {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...meta,
    };
  }

  private output(level: LogLevel, entry: LogEntry): void {
    const output = config.server.isProd ? JSON.stringify(entry) : this.formatDev(entry);

    switch (level) {
      case 'debug':
        if (config.server.isDev) console.debug(output);
        break;
      case 'info':
        console.info(output);
        break;
      case 'warn':
        console.warn(output);
        break;
      case 'error':
        console.error(output);
        break;
    }
  }

  private formatDev(entry: LogEntry): string {
    const { timestamp, level, message, ...rest } = entry;
    const meta = Object.keys(rest).length > 0 ? ` ${JSON.stringify(rest)}` : '';
    return `[${timestamp}] ${level.toUpperCase().padEnd(5)} ${message}${meta}`;
  }

  debug(message: string, meta?: Record<string, unknown>): void {
    this.output('debug', this.formatLog('debug', message, meta));
  }

  info(message: string, meta?: Record<string, unknown>): void {
    this.output('info', this.formatLog('info', message, meta));
  }

  warn(message: string, meta?: Record<string, unknown>): void {
    this.output('warn', this.formatLog('warn', message, meta));
  }

  error(message: string, meta?: Record<string, unknown>): void {
    this.output('error', this.formatLog('error', message, meta));
  }
}

export const logger = new Logger();
