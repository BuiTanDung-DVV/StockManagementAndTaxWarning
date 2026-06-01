import 'reflect-metadata';
import * as dotenv from 'dotenv';
dotenv.config();
import { AppDataSource } from '../src/config/db.config';

async function main() {
  try {
    console.log('Initializing database connection...');
    await AppDataSource.initialize();
    console.log('Database connected!');

    const tables = ['customers', 'suppliers', 'sales_orders', 'transactions'];

    for (const table of tables) {
      const query = `ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS "tags" text;`;
      console.log(`Executing: ${query}`);
      await AppDataSource.query(query);
    }
    
    console.log('All tables altered successfully.');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await AppDataSource.destroy();
    console.log('Database connection closed.');
  }
}

main();
