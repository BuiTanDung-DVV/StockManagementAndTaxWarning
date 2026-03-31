import * as dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || 8080,
  dbHost: process.env.DB_HOST || 'localhost',
  dbDatabase: process.env.DB_DATABASE || 'QLKH',
  dbUrl: process.env.DATABASE_URL || '',
  dbSync: process.env.DB_SYNC === 'true',
  jwtSecret: process.env.JWT_SECRET || 'secretKey',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '1d',
};
