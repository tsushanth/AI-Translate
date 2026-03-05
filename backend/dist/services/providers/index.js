"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ITranslateProvider = exports.DeepLTranslationProvider = exports.GoogleTranslationProvider = void 0;
__exportStar(require("./types"), exports);
var googleProvider_1 = require("./googleProvider");
Object.defineProperty(exports, "GoogleTranslationProvider", { enumerable: true, get: function () { return googleProvider_1.GoogleTranslationProvider; } });
var deeplProvider_1 = require("./deeplProvider");
Object.defineProperty(exports, "DeepLTranslationProvider", { enumerable: true, get: function () { return deeplProvider_1.DeepLTranslationProvider; } });
var itranslateProvider_1 = require("./itranslateProvider");
Object.defineProperty(exports, "ITranslateProvider", { enumerable: true, get: function () { return itranslateProvider_1.ITranslateProvider; } });
//# sourceMappingURL=index.js.map