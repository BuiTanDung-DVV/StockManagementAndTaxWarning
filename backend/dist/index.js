"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("reflect-metadata");
const express = require("express");
const cors = require("cors");
const helmet_1 = require("helmet");
const morgan = require("morgan");
const db_config_1 = require("./config/db.config");
const env_config_1 = require("./config/env.config");
const app = express();
app.use(express.json());
app.use(cors());
app.use((0, helmet_1.default)());
app.use(morgan('dev'));
const apiRouter = express.Router();
const auth_routes_1 = require("./routes/auth.routes");
const finance_routes_1 = require("./routes/finance.routes");
const inventory_routes_1 = require("./routes/inventory.routes");
const sales_routes_1 = require("./routes/sales.routes");
const product_routes_1 = require("./routes/product.routes");
const customer_routes_1 = require("./routes/customer.routes");
const supplier_routes_1 = require("./routes/supplier.routes");
const system_routes_1 = require("./routes/system.routes");
const shop_role_routes_1 = require("./routes/shop-role.routes");
const shop_member_routes_1 = require("./routes/shop-member.routes");
const notification_routes_1 = require("./routes/notification.routes");
const profile_routes_1 = require("./routes/profile.routes");
const cogs_routes_1 = require("./routes/cogs.routes");
apiRouter.use('/auth', auth_routes_1.default);
apiRouter.use('/', finance_routes_1.default);
apiRouter.use('/', inventory_routes_1.default);
apiRouter.use('/', sales_routes_1.default);
apiRouter.use('/', product_routes_1.default);
apiRouter.use('/', customer_routes_1.default);
apiRouter.use('/', supplier_routes_1.default);
apiRouter.use('/', system_routes_1.default);
apiRouter.use('/', shop_role_routes_1.default);
apiRouter.use('/', shop_member_routes_1.default);
apiRouter.use('/', notification_routes_1.default);
apiRouter.use('/profile', profile_routes_1.default);
apiRouter.use('/cogs', cogs_routes_1.default);
app.use('/api', apiRouter);
app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ success: false, message: 'Internal server error' });
});
db_config_1.AppDataSource.initialize()
    .then(() => {
    console.log(`🚀 Database connected: ${env_config_1.config.dbHost}\\${env_config_1.config.dbDatabase}`);
    app.listen(env_config_1.config.port, () => {
        console.log(`🚀 Server running on http://localhost:${env_config_1.config.port}/api`);
    });
})
    .catch((error) => console.log('❌ Database connection error: ', error));
//# sourceMappingURL=index.js.map