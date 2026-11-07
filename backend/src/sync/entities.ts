import { Entity, PrimaryColumn, Column, CreateDateColumn } from 'typeorm';

/** Committed in the SAME transaction as the business document. Never expire
 * receipts while a client may still replay an operation. No credentials/payload. */
@Entity('sync_operations')
export class SyncOperation {
    @PrimaryColumn({ name: 'shop_id', type: 'integer' }) shopId: number;
    @PrimaryColumn({ name: 'user_id', type: 'integer' }) userId: number;
    @PrimaryColumn({ name: 'operation_id', type: 'varchar', length: 64 }) operationId: string;
    @Column({ type: 'varchar', length: 40 }) kind: string;
    @Column({ name: 'request_hash', type: 'varchar', length: 64 }) requestHash: string;
    @Column({ name: 'entity_id', type: 'integer' }) entityId: number;
    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
