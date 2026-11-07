import {
  EntitySubscriberInterface,
  EventSubscriber,
  InsertEvent,
  UpdateEvent,
  RemoveEvent,
} from 'typeorm';
import { ActivityLog } from './entities';
import { requestContext } from '../middleware/context.middleware';

@EventSubscriber()
export class AuditLogSubscriber implements EntitySubscriberInterface {
  
  private isAuditable(entityName: string): boolean {
    const auditableEntities = ['SalesOrder', 'PurchaseOrder', 'InventoryStock', 'CashTransaction', 'JournalEntry'];
    return auditableEntities.includes(entityName);
  }

  async afterInsert(event: InsertEvent<any>) {
    await this.logActivity('CREATE', event);
  }

  async afterUpdate(event: UpdateEvent<any>) {
    await this.logActivity('UPDATE', event);
  }

  async afterRemove(event: RemoveEvent<any>) {
    // Note: Remove event doesn't have a new value, just old
    await this.logActivity('DELETE', event);
  }

  private async logActivity(
    action: string,
    event: InsertEvent<any> | UpdateEvent<any> | RemoveEvent<any>
  ) {
    if (!event.entity) return;

    const entityName = event.metadata.name;
    if (!this.isAuditable(entityName)) return;

    const ctx = requestContext.getStore();
    if (!ctx || !ctx.userId) return; // Only log if there is a context with an active user

    let entityId = null;
    let nameOrRef = '';

    if (event.entity) {
      entityId = (event.entity as any).id;
      nameOrRef = (event.entity as any).code || (event.entity as any).name || (event.entity as any).orderCode || (event.entity as any).orderNumber || '';
    } else if ((event as any).entityId) {
      entityId = (event as any).entityId;
    }

    let oldValue = null;
    let newValue = null;
    // Loaded relations can contain whole customers and order items. The audit
    // columns store a bounded scalar snapshot, not an entity graph.
    const changed = action === 'UPDATE'
      ? (event as UpdateEvent<any>).updatedColumns.map(column => column.propertyName)
      : [];
    const fields = [...new Set(['id', ...changed, ...event.metadata.columns.map(column => column.propertyName)])];
    const snapshot = (entity: any): string | null => {
      if (!entity) return null;
      const values: Record<string, unknown> = {};
      const omitted: string[] = [];
      for (const field of fields) {
        const value = entity[field];
        if (value === undefined) continue;
        const serialized = JSON.stringify({...values, [field]: value});
        if (serialized.length <= 1400) values[field] = value;
        else omitted.push(field);
      }
      if (omitted.length) {
        values._auditIncomplete = true;
        values._auditOmittedCount = omitted.length;
        values._auditOmittedFields = omitted.slice(0, 8).map(field => field.slice(0, 40));
      }
      return JSON.stringify(values);
    };

    if (action === 'UPDATE') {
      const updateEvent = event as UpdateEvent<any>;
      if (updateEvent.databaseEntity) {
        oldValue = snapshot(updateEvent.databaseEntity);
      }
      newValue = snapshot(updateEvent.entity);
    } else if (action === 'CREATE') {
      newValue = snapshot(event.entity);
    } else if (action === 'DELETE') {
      oldValue = snapshot((event as any).databaseEntity || event.entity);
    }

    const logRepo = event.manager.getRepository(ActivityLog);
    const log = new ActivityLog();
    log.userId = ctx.userId;
    log.shopId = ctx.shopId || null as any;
    log.action = action;
    log.entityType = entityName;
    log.entityId = entityId;
    log.entityName = String(nameOrRef).slice(0, 200);
    log.oldValue = oldValue as any;
    log.newValue = newValue as any;
    log.description = `Auto-audit: ${action} on ${entityName}`;
    log.ipAddress = ctx.ipAddress || null as any;

    try {
      await logRepo.save(log);
    } catch (err) {
      console.error('Failed to write audit log', err);
    }
  }
}
