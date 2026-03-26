import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';

// ── Shop Roles (custom per shop) ──────────────────
@Entity('shop_roles')
export class ShopRole {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'shop_id' })
    shopId: number;

    @Column({ length: 100 })
    name: string;

    @Column({ type: 'nvarchar', length: 'MAX' })
    permissions: string; // JSON: {"pos":"full","products":"view",...}

    @Column({ name: 'is_default', default: false })
    isDefault: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}

// ── Shop Members (user ↔ shop mapping) ────────────
@Entity('shop_members')
export class ShopMember {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'shop_id' })
    shopId: number;

    @Column({ name: 'user_id' })
    userId: number;

    @Column({ name: 'role_id', nullable: true })
    roleId: number;

    @Column({ name: 'member_type', length: 20, default: 'EMPLOYEE' })
    memberType: string; // 'OWNER' | 'EMPLOYEE'

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    // Relations (lazy, for joins)
    @ManyToOne(() => ShopRole, { nullable: true, eager: true })
    @JoinColumn({ name: 'role_id' })
    role: ShopRole;
}

// ── Notifications ─────────────────────────────────
@Entity('notifications')
export class Notification {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'user_id' })
    userId: number;

    @Column({ length: 30 })
    type: string; // 'SHOP_INVITE', 'ROLE_CHANGE', 'PERMISSION_CHANGE'

    @Column({ length: 200, nullable: true })
    title: string;

    @Column({ length: 500, nullable: true })
    message: string;

    @Column({ type: 'nvarchar', length: 'MAX', nullable: true })
    data: string; // JSON metadata

    @Column({ name: 'is_read', default: false })
    isRead: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}
