"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PageResponse = exports.ApiResponse = void 0;
class ApiResponse {
    static ok(data, message = 'Success') {
        const r = new ApiResponse();
        r.success = true;
        r.message = message;
        r.data = data;
        return r;
    }
}
exports.ApiResponse = ApiResponse;
class PageResponse {
    static of(items, total, page, limit) {
        const r = new PageResponse();
        r.items = items;
        r.total = total;
        r.page = page;
        r.limit = limit;
        r.totalPages = Math.ceil(total / limit);
        return r;
    }
}
exports.PageResponse = PageResponse;
//# sourceMappingURL=response.js.map