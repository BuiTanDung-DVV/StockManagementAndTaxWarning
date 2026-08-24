export class AiShopContextError extends Error {
    constructor() {
        super('Vui lòng chọn một cửa hàng cụ thể trước khi dùng trợ lý AI');
        this.name = 'AiShopContextError';
    }
}

export const requireAiShopId = (value: unknown): number => {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed <= 0) {
        throw new AiShopContextError();
    }
    return parsed;
};
