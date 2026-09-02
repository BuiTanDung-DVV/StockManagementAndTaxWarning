import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { parseTestShopIds } from '../quality/test-shop-data.utils';

type OwnerMapping = Map<number, number>;

const argument = (name: string): string | undefined => {
  const prefix = `--${name}=`;
  return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const apply = process.argv.includes('--apply');
const runId = argument('run-id') || `repair-test-shop-owners-${new Date().toISOString().replace(/[-:.TZ]/g, '')}`;

function parseOwnerMap(raw: string | undefined, shopIds: number[]): OwnerMapping {
  if (!raw) throw new Error('Bắt buộc --owner-map=34:113,35:113');
  const mapping = new Map<number, number>();
  for (const part of raw.split(',')) {
    const [shopRaw, userRaw] = part.split(':').map((value) => value.trim());
    const shopId = Number(shopRaw);
    const userId = Number(userRaw);
    if (!Number.isSafeInteger(shopId) || !Number.isSafeInteger(userId) || shopId <= 0 || userId <= 0) {
      throw new Error(`Mapping owner không hợp lệ: ${part}`);
    }
    if (mapping.has(shopId)) throw new Error(`Trùng mapping owner cho shop ${shopId}`);
    mapping.set(shopId, userId);
  }
  if (mapping.size !== shopIds.length || shopIds.some((shopId) => !mapping.has(shopId))) {
    throw new Error(`Phải chỉ định đúng owner cho các shop: ${shopIds.join(',')}`);
  }
  if ([...mapping.keys()].some((shopId) => !shopIds.includes(shopId))) {
    throw new Error('owner-map chứa shop ngoài phạm vi đã chọn');
  }
  return mapping;
}

type ActiveOwner = {
  membershipId: number;
  userId: number;
  username: string | null;
  fullName: string | null;
};

async function loadActiveOwners(executor: { query(sql: string, params?: unknown[]): Promise<any[]> }, shopId: number): Promise<ActiveOwner[]> {
  return executor.query(`
    SELECT
      sm.id AS "membershipId",
      sm.user_id AS "userId",
      u.username,
      u.full_name AS "fullName"
    FROM shop_members sm
    LEFT JOIN users u ON u.id = sm.user_id
    WHERE sm.shop_id = $1
      AND sm.member_type = 'OWNER'
      AND sm.status = 'ACTIVE'
      AND sm.is_active = true
    ORDER BY sm.id
  `, [shopId]);
}

function returningRows<T>(result: unknown): T[] {
  if (!Array.isArray(result)) return [];
  if (result.length === 2 && Array.isArray(result[0]) && typeof result[1] === 'number') {
    return result[0] as T[];
  }
  return result as T[];
}

async function main(): Promise<void> {
  const shopIds = parseTestShopIds(argument('shop-ids'));
  const ownerMap = parseOwnerMap(argument('owner-map'), shopIds);
  const expectedConfirmation = `OWNER-${shopIds.map((shopId) => `${shopId}:${ownerMap.get(shopId)}`).join(',')}`;
  if (apply && argument('confirm') !== expectedConfirmation) {
    throw new Error(`Ghi database yêu cầu --confirm=${expectedConfirmation}`);
  }

  await AppDataSource.initialize();
  try {
    if (!apply) {
      const plan = [];
      for (const shopId of shopIds) {
        const owners = await loadActiveOwners(AppDataSource, shopId);
        const targetUserId = ownerMap.get(shopId)!;
        if (!owners.some((owner) => owner.userId === targetUserId)) {
          throw new Error(`Shop ${shopId} không có owner ACTIVE mục tiêu user ${targetUserId}`);
        }
        plan.push({
          shopId,
          targetOwner: targetUserId,
          activeOwners: owners.map((owner) => `${owner.userId}:${owner.fullName || owner.username || 'unknown'}`).join(', '),
          deactivateCount: owners.filter((owner) => owner.userId !== targetUserId).length,
        });
      }
      console.table(plan);
      console.log(`Dry-run owner đến ${runId}: database không thay đổi.`);
      return;
    }

    const applied = [];
    for (const shopId of shopIds) {
      const targetUserId = ownerMap.get(shopId)!;
      const runner = AppDataSource.createQueryRunner();
      await runner.connect();
      await runner.startTransaction();
      try {
        await runner.query('SELECT pg_advisory_xact_lock($1)', [20260901]);
        const owners = await loadActiveOwners(runner, shopId);
        const targetOwners = owners.filter((owner) => owner.userId === targetUserId);
        if (targetOwners.length !== 1) {
          throw new Error(`Shop ${shopId} phải có đúng 1 owner ACTIVE mục tiêu user ${targetUserId}`);
        }
        const toDeactivate = owners.filter((owner) => owner.userId !== targetUserId);
        const changedResult = toDeactivate.length
          ? await runner.query(`
              UPDATE shop_members
              SET status = 'INACTIVE', is_active = false
              WHERE shop_id = $1
                AND member_type = 'OWNER'
                AND status = 'ACTIVE'
                AND is_active = true
                AND user_id <> $2
              RETURNING id AS "membershipId", user_id AS "userId"
            `, [shopId, targetUserId])
          : [];
        const changed = returningRows<{ membershipId: number; userId: number }>(changedResult);
        const remaining = await loadActiveOwners(runner, shopId);
        if (remaining.length !== 1 || remaining[0].userId !== targetUserId) {
          throw new Error(`Shop ${shopId} chưa đạt đúng 1 owner ACTIVE sau cập nhật`);
        }
        await runner.query(`
          INSERT INTO activity_logs (
            user_id, shop_id, action, entity_type, entity_id, entity_name,
            old_value, new_value, description, ip_address, created_at
          ) VALUES ($1, $2, 'UPDATE', 'SHOP_MEMBERSHIP', NULL, $3, $4, $5, $6, NULL, NOW())
        `, [
          targetUserId,
          shopId,
          runId,
          JSON.stringify({ runId, shopId, activeOwnersBefore: owners }),
          JSON.stringify({
            runId,
            shopId,
            primaryOwnerId: targetUserId,
            deactivatedOwnerIds: toDeactivate.map((owner) => owner.userId),
            activeOwnersAfter: remaining,
          }),
          'Chuẩn hóa owner cửa hàng test theo xác nhận, giữ lại lịch sử membership.',
        ]);
        await runner.commitTransaction();
        applied.push({ shopId, targetOwner: targetUserId, deactivatedOwnerIds: changed.map((row) => row.userId) });
      } catch (error) {
        await runner.rollbackTransaction();
        throw error;
      } finally {
        await runner.release();
      }
    }
    console.table(applied);
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? (error.stack || error.message) : error);
  process.exitCode = 1;
});
