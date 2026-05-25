import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('financial_ledger')
export class FinancialLedger {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'shop_id', type: 'int' })
  shopId: number;

  @Column({ name: 'event_type', type: 'varchar', length: 50 })
  eventType: string; // 'SALE', 'CANCEL_SALE', 'PURCHASE', 'EXPENSE', 'SALARY', 'TAX_PAYMENT'

  @Column({ type: 'decimal', precision: 15, scale: 2 })
  amount: number;

  @Column({ name: 'payment_method', type: 'varchar', length: 30 })
  paymentMethod: string; // 'CASH', 'BANK_TRANSFER', 'QR_CODE'

  @Column({ name: 'account_id', type: 'int', nullable: true })
  accountId: number;

  @Column({ name: 'reference_id', type: 'int', nullable: true })
  referenceId: number;

  @Column({ type: 'text', nullable: true })
  description: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'created_by', type: 'int', nullable: true })
  createdBy: number;
}
