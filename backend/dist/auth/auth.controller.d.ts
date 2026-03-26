import { AuthService } from './auth.service';
export declare class AuthController {
    private authService;
    constructor(authService: AuthService);
    register(dto: {
        username: string;
        password: string;
        fullName: string;
        email?: string;
        phone?: string;
    }): Promise<{
        id: number;
        username: string;
        fullName: string;
    }>;
    login(dto: {
        username: string;
        password: string;
    }): Promise<{
        accessToken: any;
        user: {
            id: number;
            username: string;
            fullName: string;
            role: string;
        };
    }>;
}
