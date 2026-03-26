"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const auth_module_1 = require("./auth/auth.module");
const product_module_1 = require("./product/product.module");
const customer_module_1 = require("./customer/customer.module");
const supplier_module_1 = require("./supplier/supplier.module");
const sales_module_1 = require("./sales/sales.module");
const inventory_module_1 = require("./inventory/inventory.module");
const finance_module_1 = require("./finance/finance.module");
const system_module_1 = require("./system/system.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                inject: [config_1.ConfigService],
                useFactory: (config) => {
                    const host = config.get('DB_HOST') ?? 'DAOVOVI';
                    const database = config.get('DB_DATABASE') ?? 'QLKH';
                    return {
                        type: 'mssql',
                        host,
                        database,
                        entities: [__dirname + '/**/*.entity{.ts,.js}', __dirname + '/**/entities{.ts,.js}'],
                        synchronize: config.get('DB_SYNC') === 'true',
                        options: { encrypt: false, trustServerCertificate: true },
                        extra: {
                            connectionString: `Driver={ODBC Driver 17 for SQL Server};Server=${host};Database=${database};Trusted_Connection=Yes;`,
                            driver: 'msnodesqlv8',
                        },
                    };
                },
            }),
            auth_module_1.AuthModule,
            product_module_1.ProductModule,
            customer_module_1.CustomerModule,
            supplier_module_1.SupplierModule,
            sales_module_1.SalesModule,
            inventory_module_1.InventoryModule,
            finance_module_1.FinanceModule,
            system_module_1.SystemModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map