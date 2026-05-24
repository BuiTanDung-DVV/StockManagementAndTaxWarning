import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn, OneToMany } from 'typeorm';

@Entity('journal_entries')
export class JournalEntry {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'shop_id' })
    shopId: number;

    @Column({ name: 'entry_date', type: 'timestamp with time zone', default: () => 'CURRENT_TIMESTAMP' })
    entryDate: Date;

    @Column({ name: 'reference_type', length: 50 })
    referenceType: string;

    @Column({ name: 'reference_id' })
    referenceId: number;

    @Column({ type: 'text', nullable: true })
    description: string;

    @Column({ name: 'is_voided', default: false })
    isVoided: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @OneToMany(() => JournalLine, line => line.journalEntry, { cascade: true })
    lines: JournalLine[];
}

@Entity('journal_lines')
export class JournalLine {
    @PrimaryGeneratedColumn()
    id: number;

    @Column({ name: 'journal_entry_id' })
    journalEntryId: number;

    @ManyToOne(() => JournalEntry, entry => entry.lines, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'journal_entry_id' })
    journalEntry: JournalEntry;

    @Column({ name: 'account_code', length: 50 })
    accountCode: string;

    @Column({ type: 'decimal', precision: 15, scale: 2, transformer: {
        to: (value: number) => value,
        from: (value: string) => parseFloat(value)
    }})
    amount: number;

    @Column({ name: 'entry_type', length: 10 })
    entryType: 'DEBIT' | 'CREDIT';

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;
}
