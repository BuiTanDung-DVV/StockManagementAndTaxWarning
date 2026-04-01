import { User } from '../auth/entities';
export declare class AuthService {
    private userRepo;
    private memberRepo;
    register(dto: Partial<User>): Promise<User[]>;
    login(dto: any): Promise<{
        access_token: string;
        user: {
            id: number;
            username: string;
            role: string;
            fullName: string;
            email: string | null;
            phone: string | null;
            avatarUrl: string | null;
            accountType: string;
        };
        shops: any[];
    }>;
    forgotPassword(dto: any): Promise<{
        sent: boolean;
        userId?: undefined;
    } | {
        sent: boolean;
        userId: number;
    }>;
    resetPassword(dto: any): Promise<{
        updated: boolean;
    }>;
}
