"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
const config_1 = require("../config");
/**
 * Simple structured logger for Cloud Run
 * Outputs JSON in production for Cloud Logging integration
 */
class Logger {
    formatLog(level, message, meta) {
        return {
            timestamp: new Date().toISOString(),
            level,
            message,
            ...meta,
        };
    }
    output(level, entry) {
        const output = config_1.config.server.isProd ? JSON.stringify(entry) : this.formatDev(entry);
        switch (level) {
            case 'debug':
                if (config_1.config.server.isDev)
                    console.debug(output);
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
    formatDev(entry) {
        const { timestamp, level, message, ...rest } = entry;
        const meta = Object.keys(rest).length > 0 ? ` ${JSON.stringify(rest)}` : '';
        return `[${timestamp}] ${level.toUpperCase().padEnd(5)} ${message}${meta}`;
    }
    debug(message, meta) {
        this.output('debug', this.formatLog('debug', message, meta));
    }
    info(message, meta) {
        this.output('info', this.formatLog('info', message, meta));
    }
    warn(message, meta) {
        this.output('warn', this.formatLog('warn', message, meta));
    }
    error(message, meta) {
        this.output('error', this.formatLog('error', message, meta));
    }
}
exports.logger = new Logger();
//# sourceMappingURL=logger.js.map