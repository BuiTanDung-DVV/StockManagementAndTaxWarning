import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { User } from './user.entity';
export declare class AuthService {
    private userRepo;
    private jwtService;
    constructor(userRepo: Repository<User>, jwtService: JwtService);
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
    login(username: string, password: string): Promise<{
        accessToken: any;
        user: {
            id: number;
            username: string;
            fullName: string;
            role: string;
        };
    }>;
    findById(id: number): Promise<User | null>;
}
