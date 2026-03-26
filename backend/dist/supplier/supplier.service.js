"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SupplierService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const entities_1 = require("./entities");
let SupplierService = class SupplierService {
    constructor(supplierRepo, payableRepo) {
        this.supplierRepo = supplierRepo;
        this.payableRepo = payableRepo;
    }
    async findAll(page = 1, limit = 20, search) {
        const where = search ? [{ name: (0, typeorm_2.Like)(`%${search}%`) }, { code: (0, typeorm_2.Like)(`%${search}%`) }] : {};
        const [items, total] = await this.supplierRepo.findAndCount({
            where, skip: (page - 1) * limit, take: limit, order: { createdAt: 'DESC' },
        });
        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }
    async findById(id) {
        const s = await this.supplierRepo.findOne({ where: { id } });
        if (!s)
            throw new common_1.NotFoundException('Supplier not found');
        return s;
    }
    async create(dto) {
        if (!dto.code)
            dto.code = 'NCC' + Date.now().toString().slice(-6);
        return this.supplierRepo.save(this.supplierRepo.create(dto));
    }
    async update(id, dto) {
        const s = await this.findById(id);
        Object.assign(s, dto);
        return this.supplierRepo.save(s);
    }
    async findPayables(supplierId) {
        return this.payableRepo.find({ where: { supplierId }, order: { createdAt: 'DESC' } });
    }
};
exports.SupplierService = SupplierService;
exports.SupplierService = SupplierService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.Supplier)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.Payable)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], SupplierService);
//# sourceMappingURL=supplier.service.js.map