import { AppDataSource } from './src/config/db.config';

async function main() {
    try {
        await AppDataSource.initialize();
        console.log('DB connected');
        
        const cashRes = await AppDataSource.query('SELECT COUNT(*) FROM cash_transactions');
        console.log('Cash transactions count:', cashRes[0].count);
        
        const soRes = await AppDataSource.query('SELECT COUNT(*) FROM sales_orders');
        console.log('Sales orders count:', soRes[0].count);

        const pmRes = await AppDataSource.query('SELECT payment_method, COUNT(*) as c FROM sales_orders GROUP BY payment_method');
        console.log('Sales orders payment methods:', pmRes);
        
        // Also let's check a sample cash transaction
        const cashSample = await AppDataSource.query('SELECT * FROM cash_transactions LIMIT 1');
        console.log('Sample cash transaction:', cashSample);
        
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

main();
