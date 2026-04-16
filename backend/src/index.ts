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
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));

// Define the base API URL
const apiRouter = express.Router();

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

// Routes
apiRouter.use('/auth', authRoutes);
apiRouter.use('/', financeRoutes);
apiRouter.use('/', inventoryRoutes);
apiRouter.use('/', salesRoutes);
apiRouter.use('/', productRoutes);
apiRouter.use('/', customerRoutes);
apiRouter.use('/', supplierRoutes);
apiRouter.use('/', systemRoutes);
apiRouter.use('/', shopRoleRoutes);
apiRouter.use('/', shopMemberRoutes);
apiRouter.use('/', notificationRoutes);
apiRouter.use('/profile', profileRoutes);
apiRouter.use('/cogs', cogsRoutes);

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
    .then(() => {
      console.log(`🚀 Database connected: ${config.dbHost}\\${config.dbDatabase}`);
      app.listen(config.port, () => {
        console.log(`🚀 Server running on http://localhost:${config.port}/api`);
      });
    })
    .catch((error) => console.log('❌ Database connection error: ', error));
}

// Function to handle requests on Vercel
const vercelHandler = async (req: express.Request, res: express.Response) => {
  if (!AppDataSource.isInitialized) {
    try {
      await AppDataSource.initialize();
      console.log('🚀 Database connected for Vercel Serverless');
    } catch (error) {
      console.log('❌ Database connection error: ', error);
      return res.status(500).json({ success: false, message: 'Database connection failed' });
    }
  }
  return app(req, res);
};

export default vercelHandler;
