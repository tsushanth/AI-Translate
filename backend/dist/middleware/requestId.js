"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestIdMiddleware = requestIdMiddleware;
const uuid_1 = require("uuid");
/**
 * Middleware to attach a unique request ID to each request
 */
function requestIdMiddleware(req, res, next) {
    // Use existing header or generate new ID
    const requestId = req.headers['x-request-id'] || (0, uuid_1.v4)();
    req.requestId = requestId;
    res.setHeader('X-Request-ID', requestId);
    next();
}
//# sourceMappingURL=requestId.js.map