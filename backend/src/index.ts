import 'reflect-metadata';
import express = require('express');
import cors = require('cors');
import helmet from 'helmet';
import morgan = require('morgan');
import { AppDataSource } from './config/db.config';
import { config } from './config/env.config';

const app = express();

app.use(express.json());
app.use(cors({
  origin: (origin, callback) => {
    if (
      !origin ||
      config.allowedOrigins.indexOf(origin) !== -1 ||
      /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)
    ) {
      callback(null, true);
    } else {
      callback(null, false);
    }
  },
  credentials: true,
}));
app.use(helmet());
app.use(morgan('dev'));

const apiRouter = express.Router();

import { contextMiddleware } from './middleware/context.middleware';
apiRouter.use(contextMiddleware);

import authRoutes from './routes/auth.routes';
import financeRoutes from './routes/finance.routes';
import inventoryRoutes from './routes/inventory.routes';
import salesRoutes from './routes/sales.routes';
import productRoutes from './routes/product.routes';
import customerRoutes from './routes/customer.routes';
import supplierRoutes from './routes/supplier.routes';
import systemRoutes from './routes/system.routes';
import shopRoleRoutes from './routes/shop-role.routes';
import shopMemberRoutes from './routes/shop-member.routes';
import notificationRoutes from './routes/notification.routes';
import profileRoutes from './routes/profile.routes';
import cogsRoutes from './routes/cogs.routes';
import taxConfigRoutes from './routes/tax-config.routes';
import taxRoutes from './routes/tax.routes';
import tagRoutes from './routes/tag.routes';

import { authenticateJwt, requireShopId } from './middleware/auth.middleware';

apiRouter.use('/auth', authRoutes);
apiRouter.use(authenticateJwt);

apiRouter.use('/', notificationRoutes);
apiRouter.use('/profile', profileRoutes);

import * as shopMemberCtrl from './controllers/shop-member.controller';
apiRouter.get('/my-shops', shopMemberCtrl.getMyShops);
apiRouter.get('/shops/search', shopMemberCtrl.searchShops);
apiRouter.post('/shop-members/request-join', shopMemberCtrl.requestJoin);

apiRouter.use(requireShopId);
apiRouter.use('/', financeRoutes);
apiRouter.use('/', inventoryRoutes);
apiRouter.use('/', salesRoutes);
apiRouter.use('/', productRoutes);
apiRouter.use('/', customerRoutes);
apiRouter.use('/', supplierRoutes);
apiRouter.use('/', systemRoutes);
apiRouter.use('/', shopRoleRoutes);
apiRouter.use('/', shopMemberRoutes);
apiRouter.use('/cogs', cogsRoutes);
apiRouter.use('/', taxConfigRoutes);
apiRouter.use('/tax', taxRoutes);
apiRouter.use('/tags', tagRoutes);

app.use('/api', apiRouter);

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

if (process.env.NODE_ENV !== 'production' && process.env.VERCEL !== '1') {
  AppDataSource.initialize()
    .then(() => {
      console.log(`Database connected: ${config.dbHost}\\${config.dbDatabase}`);
      app.listen(config.port, () => {
        console.log(`Server running on http://localhost:${config.port}/api`);
      });
    })
    .catch((error) => console.log('Database connection error: ', error));
}

let dbInitPromise: Promise<void> | null = null;

const vercelHandler = async (req: express.Request, res: express.Response) => {
  if (!AppDataSource.isInitialized) {
    if (!dbInitPromise) {
      dbInitPromise = (async () => {
        try {
          await AppDataSource.initialize();
          console.log('Database connected for Vercel Serverless');
        } catch (error) {
          console.log('Database connection error: ', error);
          dbInitPromise = null;
          throw error;
        }
      })();
    }

    try {
      await dbInitPromise;
    } catch {
      return res.status(500).json({ success: false, message: 'Database connection failed' });
    }
  }

  return app(req, res);
};

export default vercelHandler;
