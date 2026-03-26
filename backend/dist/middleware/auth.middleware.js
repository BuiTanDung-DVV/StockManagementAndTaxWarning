"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticateJwt = void 0;
const jwt = require("jsonwebtoken");
const env_config_1 = require("../config/env.config");
const authenticateJwt = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, env_config_1.config.jwtSecret);
        req.user = decoded;
        next();
    }
    catch (error) {
        res.status(401).json({ success: false, message: 'Unauthorized' });
    }
};
exports.authenticateJwt = authenticateJwt;
//# sourceMappingURL=auth.middleware.js.map