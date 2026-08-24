import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { SalesService } from '../services/sales.service';

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

async function main(): Promise<void> {
    const shopId = Number(argument('shop-id'));
    const from = argument('from');
    const to = argument('to');
    if (!Number.isInteger(shopId) || shopId <= 0 || !from || !to) {
        throw new Error('Usage: --shop-id=<id> --from=YYYY-MM-DD --to=YYYY-MM-DD');
    }

    await AppDataSource.initialize();
    try {
        const rows = await new SalesService().getTopReturnedProducts(
            shopId,
            from,
            to,
        );
        console.table(rows);
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
