import * as dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || 8080,
  dbHost: process.env.DB_HOST || 'localhost',
  dbDatabase: process.env.DB_DATABASE || 'QLKH',
  dbUrl: process.env.DATABASE_URL || '',
  dbSync: process.env.DB_SYNC === 'true',
  get jwtSecret(): string {
    const secret = process.env.JWT_SECRET;
    if (!secret && process.env.NODE_ENV === 'production') {
      throw new Error('FATAL SECURITY ERROR: JWT_SECRET environment variable is not defined!');
    }
    return secret || 'defaultDevSecretKeyOnly';
  },
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '1d',
  get allowedOrigins(): string[] {
    const origins = process.env.ALLOWED_ORIGINS;
    if (origins) {
      return origins.split(',').map(o => o.trim());
    }
    // Allow standard local dev ports by default
    return [
      'http://localhost:3000',
      'http://localhost:5000',
      'http://localhost:8080',
      'http://localhost:5173', // Vite default port
    ];
  }
};

