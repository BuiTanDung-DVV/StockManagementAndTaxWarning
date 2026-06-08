import { AppDataSource } from './src/config/db.config';

async function main() {
    try {
        await AppDataSource.initialize();
        console.log('DB connected');
        
        await AppDataSource.query("UPDATE cash_transactions SET type = 'INCOME' WHERE type = 'IN'");
        await AppDataSource.query("UPDATE cash_transactions SET type = 'EXPENSE' WHERE type = 'OUT'");
        console.log('Fixed DB types');
        
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

main();
