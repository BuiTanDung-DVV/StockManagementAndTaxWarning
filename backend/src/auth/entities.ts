import { Entity, PrimaryGeneratedColumn, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ unique: true })
    username: string;

    // In the SQL schema (backend/database/QLKH.sql) the column is named `password`.
    @Column({ name: 'password', type: 'varchar', length: 255, nullable: true })
    passwordHash: string | null;

    @Column({ name: 'full_name' })
    fullName: string;

    @Column({ nullable: true })
    email: string;

    @Column({ name: 'email_verified', default: false })
    emailVerified: boolean;

    @Column({ nullable: true })
    phone: string;

    @Column({ default: 'STAFF' }) // ADMIN, MANAGER, STAFF
    role: string;

    @Column({ name: 'avatar_url', nullable: true })
    avatarUrl: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @Column({ name: 'is_onboarded', default: false })
    isOnboarded: boolean;

    @Column({ name: 'account_type', type: 'varchar', length: 20, nullable: true })
    accountType: string | null; // NULL until onboarding, then 'SHOP' | 'PERSONAL'

    @Column({ name: 'google_subject', type: 'varchar', length: 255, nullable: true, unique: true })
    googleSubject: string | null;

    @Column({ name: 'failed_login_attempts', default: 0 })
    failedLoginAttempts: number;

    @Column({ name: 'locked_until', type: 'timestamptz', nullable: true })
    lockedUntil: Date | null;

    @Column({ name: 'auth_version', default: 0 })
    authVersion: number;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}

@Entity('refresh_sessions')
export class RefreshSession {
    @PrimaryColumn({ type: 'uuid' })
    id: string;

    @Column({ name: 'family_id', type: 'uuid' })
    familyId: string;

    @Column({ name: 'user_id' })
    userId: number;

    @Column({ name: 'token_hash', length: 64 })
    tokenHash: string;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
    revokedAt: Date | null;

    @Column({ name: 'replaced_by', type: 'uuid', nullable: true })
    replacedBy: string | null;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @Column({ name: 'last_used_at', type: 'timestamptz', nullable: true })
    lastUsedAt: Date | null;
}
