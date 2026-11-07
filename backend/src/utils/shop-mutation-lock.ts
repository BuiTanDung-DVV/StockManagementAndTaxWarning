import { EntityManager } from 'typeorm';

/** Serialize linked money/stock writes within a shop, including separate documents.
 * The transaction releases this lock on commit or rollback; other shops do not wait.
 */
export async function lockShopMutation(manager: EntityManager, shopId: number): Promise<void> {
    if (!manager.queryRunner?.isTransactionActive) {
        throw new Error('Shop mutation lock requires an active transaction');
    }
    await manager.query('SELECT pg_advisory_xact_lock($1, $2)', [147917, shopId]);
}
