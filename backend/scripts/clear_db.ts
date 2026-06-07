import { AppDataSource } from '../src/config/db.config';

async function clearDB() {
    console.log('Initializing DB...');
    await AppDataSource.initialize();
    
    console.log('Fetching all tables...');
    const entities = AppDataSource.entityMetadatas;
    const tableNames = entities.map(entity => `"${entity.tableName}"`).join(', ');

    if (tableNames) {
        console.log(`Truncating tables: ${tableNames}`);
        await AppDataSource.query(`TRUNCATE TABLE ${tableNames} CASCADE;`);
        console.log('All tables truncated successfully.');
    } else {
        console.log('No tables found to truncate.');
    }

    await AppDataSource.destroy();
    console.log('DB Connection closed.');
}

clearDB().catch(e => console.error(e));
