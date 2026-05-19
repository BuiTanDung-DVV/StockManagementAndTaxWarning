import { AppDataSource } from './src/config/db.config';

async function clearData() {
    await AppDataSource.initialize();
    console.log('Connected to DB');
    await AppDataSource.query('DELETE FROM sales_returns');
    await AppDataSource.query('DELETE FROM sales_return_items');
    await AppDataSource.query('DELETE FROM sales_order_items');
    await AppDataSource.query('DELETE FROM sales_orders');
    await AppDataSource.query('DELETE FROM cash_transactions');
    console.log('Data cleared');
    await AppDataSource.destroy();
}

clearData().catch(console.error);
