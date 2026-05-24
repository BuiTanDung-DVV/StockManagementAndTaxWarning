import { AppDataSource } from '../config/db.config';
import { JournalEntry, JournalLine } from '../finance/ledger.entity';
import { EntityManager } from 'typeorm';

export class PostingService {
    async postJournal(
        shopId: number,
        referenceType: string,
        referenceId: number,
        description: string,
        lines: { accountCode: string, amount: number, entryType: 'DEBIT' | 'CREDIT' }[],
        manager?: EntityManager
    ) {
        const repoEntry = manager ? manager.getRepository(JournalEntry) : AppDataSource.getRepository(JournalEntry);

        // Validate double-entry accounting principle (Total Debit == Total Credit)
        const totalDebit = lines.filter(l => l.entryType === 'DEBIT').reduce((sum, l) => sum + l.amount, 0);
        const totalCredit = lines.filter(l => l.entryType === 'CREDIT').reduce((sum, l) => sum + l.amount, 0);
        
        // Use a small epsilon for floating point comparison if necessary, but here we expect exact match
        if (Math.abs(totalDebit - totalCredit) > 0.01) {
            throw new Error(`Double-entry validation failed: Debit (${totalDebit}) != Credit (${totalCredit})`);
        }

        const entry = repoEntry.create({
            shopId,
            referenceType,
            referenceId,
            description,
            lines
        });

        await repoEntry.save(entry);
    }
}
