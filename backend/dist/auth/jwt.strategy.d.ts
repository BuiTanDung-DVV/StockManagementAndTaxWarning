import { ConfigService } from '@nestjs/config';
declare const JwtStrategy_base: any;
export declare class JwtStrategy extends JwtStrategy_base {
    constructor(config: ConfigService);
    validate(payload: {
        sub: number;
        username: string;
        role: string;
    }): Promise<{
        id: number;
        username: string;
        role: string;
    }>;
}
export {};
