import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true })
    username: string;

    // In the SQL schema (backend/database/QLKH.sql) the column is named `password`.
    @Column({ name: 'password' })
    passwordHash: string;

    @Column({ name: 'full_name' })
    fullName: string;

    @Column({ nullable: true })
    email: string;

    @Column({ nullable: true })
    phone: string;

    @Column({ default: 'STAFF' }) // ADMIN, MANAGER, STAFF
    role: string;

    @Column({ name: 'avatar_url', nullable: true })
    avatarUrl: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @Column({ name: 'account_type', length: 20, default: 'PERSONAL' })
    accountType: string; // 'SHOP' (hộ kinh doanh) | 'PERSONAL'

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}
