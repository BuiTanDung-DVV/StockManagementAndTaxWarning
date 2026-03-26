import { AppDataSource } from '../config/db.config';
import { Notification } from '../shop/entities';

export class NotificationService {
    private repo = AppDataSource.getRepository(Notification);

    /** List notifications for a user */
    async findAll(userId: number, page = 1, limit = 20) {
        const [items, total] = await this.repo.findAndCount({
            where: { userId },
            order: { createdAt: 'DESC' },
            skip: (page - 1) * limit,
            take: limit,
        });
        return { items, total, page, limit };
    }

    /** Get unread count */
    async unreadCount(userId: number) {
        return this.repo.count({ where: { userId, isRead: false } });
    }

    /** Mark one as read */
    async markRead(id: number) {
        await this.repo.update(id, { isRead: true });
        return { updated: true };
    }

    /** Mark all as read */
    async markAllRead(userId: number) {
        await this.repo.update({ userId, isRead: false }, { isRead: true });
        return { updated: true };
    }
}
