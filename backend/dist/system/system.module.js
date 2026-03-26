"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SystemModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const entities_1 = require("./entities");
const system_service_1 = require("./system.service");
const system_controller_1 = require("./system.controller");
let SystemModule = class SystemModule {
};
exports.SystemModule = SystemModule;
exports.SystemModule = SystemModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([entities_1.ShopProfile, entities_1.ActivityLog, entities_1.InvoiceScan, entities_1.Invoice, entities_1.InvoiceItem, entities_1.PurchaseWithoutInvoice, entities_1.PurchaseWithoutInvoiceItem])],
        providers: [system_service_1.SystemService],
        controllers: [system_controller_1.ShopProfileController, system_controller_1.ActivityLogController, system_controller_1.InvoiceScanController, system_controller_1.InvoiceController, system_controller_1.PurchaseWithoutInvoiceController],
        exports: [system_service_1.SystemService],
    })
], SystemModule);
//# sourceMappingURL=system.module.js.map