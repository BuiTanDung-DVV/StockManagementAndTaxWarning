export class ApiResponse<T> {
    success: boolean;
    message: string;
    data: T;

    static ok<T>(data: T, message = 'Success'): ApiResponse<T> {
        const r = new ApiResponse<T>();
        r.success = true;
        r.message = message;
        r.data = data;
        return r;
    }
}

export class PageResponse<T> {
    items: T[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;

    static of<T>(items: T[], total: number, page: number, limit: number): PageResponse<T> {
        const r = new PageResponse<T>();
        r.items = items;
        r.total = total;
        r.page = page;
        r.limit = limit;
        r.totalPages = Math.ceil(total / limit);
        return r;
    }
}
