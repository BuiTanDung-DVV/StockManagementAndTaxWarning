import * as dotenv from 'dotenv';
dotenv.config();

function securitySecret(name: string, value: string | undefined, developmentFallback: string): string {
  if (process.env.NODE_ENV === 'production' && (!value || Buffer.byteLength(value, 'utf8') < 32)) {
    throw new Error(`FATAL SECURITY ERROR: ${name} must contain at least 32 bytes`);
  }
  return value || developmentFallback;
}

export const config = {
  port: process.env.PORT || 8080,
  dbHost: process.env.DB_HOST || 'localhost',
  dbDatabase: process.env.DB_DATABASE || 'QLKH',
  dbUrl: process.env.DATABASE_URL || '',
  dbSync: process.env.DB_SYNC === 'true',
  get accessTokenSecret(): string {
    return securitySecret(
      'ACCESS_TOKEN_SECRET',
      process.env.ACCESS_TOKEN_SECRET || process.env.JWT_SECRET,
      'dev-access-secret-change-before-production',
    );
  },
  get refreshTokenSecret(): string {
    return securitySecret(
      'REFRESH_TOKEN_SECRET',
      process.env.REFRESH_TOKEN_SECRET,
      'dev-refresh-secret-change-before-production',
    );
  },
  get otpSecret(): string {
    return securitySecret(
      'OTP_SECRET',
      process.env.OTP_SECRET,
      'dev-otp-secret-change-before-production',
    );
  },
  get jwtSecret(): string {
    return this.accessTokenSecret;
  },
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '15m',
  refreshTokenExpiresInDays: 7,
  get googleClientIds(): string[] {
    return (process.env.GOOGLE_CLIENT_IDS || '')
      .split(',')
      .map(value => value.trim())
      .filter(Boolean);
  },
  cloudinaryCloudName: process.env.CLOUDINARY_CLOUD_NAME || '',
  cloudinaryApiKey: process.env.CLOUDINARY_API_KEY || '',
  cloudinaryApiSecret: process.env.CLOUDINARY_API_SECRET || '',
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  get allowedOrigins(): string[] {
    const defaultOrigins = [
      'http://localhost:3000',
      'http://localhost:5000',
      'http://localhost:8080',
      'http://localhost:5173',
      'https://smartstock-app.vercel.app',
      'https://smartstock-tax.vercel.app',
      'https://stock-management-and-tax-warning.vercel.app',
    ];
    
    const origins = process.env.ALLOWED_ORIGINS;
    if (origins) {
      const parsed = origins.split(',').map(o => o.trim());
      return Array.from(new Set([...parsed, ...defaultOrigins]));
    }
    return defaultOrigins;
  }
};

export function isAllowedOrigin(origin: string): boolean {
  if (!origin) return true;
  if (config.allowedOrigins.includes(origin)) return true;
  if (/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) return true;
  if (/\.vercel\.app$/.test(origin)) return true;
  return false;
}

export function validateSecurityConfig(): void {
  const secrets = [config.accessTokenSecret, config.refreshTokenSecret, config.otpSecret];
  if (new Set(secrets).size !== secrets.length) {
    throw new Error('FATAL SECURITY ERROR: authentication secrets must be different');
  }
}
