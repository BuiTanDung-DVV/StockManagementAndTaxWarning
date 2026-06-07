import 'reflect-metadata';
import express = require('express');
import cors = require('cors');
import helmet from 'helmet';
import morgan = require('morgan');
import { AppDataSource } from './config/db.config';
import { config } from './config/env.config';

const app = express();

// Middleware
app.use(express.json());
app.use(cors({
  origin: (origin, callback) => {
    // allow requests with no origin (like mobile apps or curl requests)
    if (!origin || config.allowedOrigins.indexOf(origin) !== -1 || /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) {
      callback(null, true);
    } else {
      callback(null, false);
    }
  },
  credentials: true,
}));
app.use(helmet());
app.use(morgan('dev'));

// Define the base API URL
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

// Routes
apiRouter.use('/auth', authRoutes);

// Protect all other routes
apiRouter.use(authenticateJwt);

// User-scoped routes (no shopId required)
apiRouter.use('/', notificationRoutes);
apiRouter.use('/profile', profileRoutes);

// my-shops needs to be accessible before we know the shopId
import * as shopMemberCtrl from './controllers/shop-member.controller';
apiRouter.get('/my-shops', shopMemberCtrl.getMyShops);
apiRouter.get('/shops/search', shopMemberCtrl.searchShops);
apiRouter.post('/shop-members/request-join', shopMemberCtrl.requestJoin);

// Shop-scoped routes (shopId REQUIRED)
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

// Mount the API router
app.use('/api', apiRouter);

// Global Error Handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

// Vercel Serverless requirements: export the app
if (process.env.NODE_ENV !== 'production' && process.env.VERCEL !== '1') {
  // Start Server locally
  AppDataSource.initialize()
    .then(async () => {
      console.log(`🚀 Database connected: ${config.dbHost}\\${config.dbDatabase}`);
      try {
          await AppDataSource.query(`
              ALTER TABLE shop_profiles 
              ADD COLUMN IF NOT EXISTS business_sector VARCHAR(50) DEFAULT 'TRADE',
              ADD COLUMN IF NOT EXISTS apply_vat_reduction BOOLEAN DEFAULT false,
              ADD COLUMN IF NOT EXISTS custom_vat_rate DECIMAL(5,2),
              ADD COLUMN IF NOT EXISTS custom_pit_rate DECIMAL(5,2);
          `);
          await AppDataSource.query(`
              CREATE TABLE IF NOT EXISTS otps (
                  id SERIAL PRIMARY KEY,
                  phone VARCHAR(255) NOT NULL,
                  otp_code VARCHAR(10) NOT NULL,
                  expires_at TIMESTAMP NOT NULL,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              );
              ALTER TABLE otps ALTER COLUMN phone TYPE VARCHAR(255);
          `);
          console.log('✅ Dynamic schema sync complete for shop_profiles and otps');
      } catch (e) {
          console.log('⚠️ Dynamic schema sync error:', e);
      }
      app.listen(config.port, () => {
        console.log(`🚀 Server running on http://localhost:${config.port}/api`);
      });
    })
    .catch((error) => console.log('❌ Database connection error: ', error));
}

let dbInitPromise: Promise<void> | null = null;

// Function to handle requests on Vercel
const vercelHandler = async (req: express.Request, res: express.Response) => {
  if (!AppDataSource.isInitialized) {
    if (!dbInitPromise) {
      dbInitPromise = (async () => {
        try {
          await AppDataSource.initialize();
          console.log('🚀 Database connected for Vercel Serverless');
          try {
              await AppDataSource.query(`
                  ALTER TABLE shop_profiles 
                  ADD COLUMN IF NOT EXISTS business_sector VARCHAR(50) DEFAULT 'TRADE',
                  ADD COLUMN IF NOT EXISTS apply_vat_reduction BOOLEAN DEFAULT false,
                  ADD COLUMN IF NOT EXISTS custom_vat_rate DECIMAL(5,2),
                  ADD COLUMN IF NOT EXISTS custom_pit_rate DECIMAL(5,2);
              `);
              await AppDataSource.query(`
                  CREATE TABLE IF NOT EXISTS otps (
                      id SERIAL PRIMARY KEY,
                      phone VARCHAR(255) NOT NULL,
                      otp_code VARCHAR(10) NOT NULL,
                      expires_at TIMESTAMP NOT NULL,
                      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                  );
                  ALTER TABLE otps ALTER COLUMN phone TYPE VARCHAR(255);
              `);
              console.log('✅ Dynamic schema sync complete for shop_profiles and otps');
          } catch (e) {
              console.log('⚠️ Dynamic schema sync error:', e);
          }
        } catch (error) {
          console.log('❌ Database connection error: ', error);
          dbInitPromise = null; // allow retry
          throw error;
        }
      })();
    }
    try {
      await dbInitPromise;
    } catch (error) {
      return res.status(500).json({ success: false, message: 'Database connection failed' });
    }
  }
  return app(req, res);
};

export default vercelHandler;
