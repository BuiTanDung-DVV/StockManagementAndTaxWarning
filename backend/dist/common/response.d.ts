export declare class ApiResponse<T> {
    success: boolean;
    message: string;
    data: T;
    static ok<T>(data: T, message?: string): ApiResponse<T>;
}
export declare class PageResponse<T> {
    items: T[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
    static of<T>(items: T[], total: number, page: number, limit: number): PageResponse<T>;
}
