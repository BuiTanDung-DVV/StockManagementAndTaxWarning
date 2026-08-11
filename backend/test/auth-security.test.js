const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const jwt = require('jsonwebtoken');

const {
  completeOnboardingSchema,
  googleAuthSchema,
  loginSchema,
  registerSchema,
  resetPasswordSchema,
  updateProfileSchema,
} = require('../dist/auth/auth.schemas');
const { User } = require('../dist/auth/entities');
const { AppDataSource } = require('../dist/config/db.config');
const { config } = require('../dist/config/env.config');
const { AuthService } = require('../dist/services/auth.service');

const validPassword = `DummyTestPass_${Date.now()}@123`;

test('registration normalizes a verified Gmail-shaped identifier', () => {
  const result = registerSchema.parse({
    username: '  User.Name@GMAIL.COM ',
    password: validPassword,
    fullName: 'Nguyen Van A',
    accountType: 'SHOP',
    otpCode: '123456',
  });

  assert.equal(result.username, 'user.name@gmail.com');
});

test('registration rejects non-Gmail addresses and weak passwords', () => {
  assert.equal(registerSchema.safeParse({
    username: 'user@example.com',
    password: validPassword,
    fullName: 'Nguyen Van A',
    accountType: 'PERSONAL',
    otpCode: '123456',
  }).success, false);

  assert.equal(registerSchema.safeParse({
    username: 'user@gmail.com',
    password: 'password',
    fullName: 'Nguyen Van A',
    accountType: 'PERSONAL',
    otpCode: '123456',
  }).success, false);
});

test('auth payloads reject unexpected fields and malformed OTP values', () => {
  assert.equal(loginSchema.safeParse({
    username: 'user@gmail.com',
    password: validPassword,
    role: 'ADMIN',
  }).success, false);

  assert.equal(resetPasswordSchema.safeParse({
    identifier: 'user@gmail.com',
    newPassword: validPassword,
    otpCode: '12345a',
  }).success, false);
});

test('bcrypt inputs reject values longer than 72 bytes', () => {
  assert.equal(loginSchema.safeParse({
    username: 'user@gmail.com',
    password: 'á'.repeat(40),
  }).success, false);
});

test('Google authentication payload requires a realistic ID token', () => {
  assert.equal(googleAuthSchema.safeParse({
    idToken: 'short-token',
    createIfMissing: true,
    accountType: 'SHOP',
  }).success, false);
});

test('profile updates cannot replace the verified Gmail identity', () => {
  assert.equal(updateProfileSchema.safeParse({
    fullName: 'Nguyen Van A',
    email: 'attacker@gmail.com',
  }).success, false);
});

test('onboarding rejects privilege fields supplied by the client', () => {
  assert.equal(completeOnboardingSchema.safeParse({
    accountType: 'SHOP',
    fullName: 'Nguyen Van A',
    role: 'ADMIN',
  }).success, false);
});

test('onboarding accepts business account types but rejects system roles', () => {
  assert.equal(completeOnboardingSchema.safeParse({
    fullName: 'Nguyen Van A',
  }).success, false);
  assert.equal(completeOnboardingSchema.safeParse({
    accountType: 'SHOP',
    fullName: 'Nguyen Van A',
  }).success, true);
  assert.equal(completeOnboardingSchema.safeParse({
    accountType: 'ADMIN',
    fullName: 'Nguyen Van A',
  }).success, false);
});

test('auth entities build valid PostgreSQL metadata', async () => {
  await AppDataSource.buildMetadatas();
  const metadata = AppDataSource.getMetadata(User);

  for (const propertyName of ['passwordHash', 'googleSubject']) {
    const column = metadata.findColumnWithPropertyName(propertyName);
    assert.ok(column, `Missing metadata for User.${propertyName}`);
    assert.notEqual(column.type, Object, `User.${propertyName} must declare an explicit database type`);
  }

  const accountTypeColumn = metadata.findColumnWithPropertyName('accountType');
  assert.ok(accountTypeColumn, 'Missing metadata for User.accountType');
  assert.equal(accountTypeColumn.isNullable, true);
});

test('account type migration is explicit, idempotent, and does not rewrite users', () => {
  const migration = fs.readFileSync(
    path.join(
      __dirname,
      '..',
      'database',
      '20260809_nullable_account_type_until_onboarding.sql',
    ),
    'utf8',
  );
  const runner = fs.readFileSync(
    path.join(
      __dirname,
      '..',
      'src',
      'scripts',
      'apply-nullable-account-type-migration.ts',
    ),
    'utf8',
  );

  assert.match(migration, /ALTER COLUMN account_type DROP DEFAULT/i);
  assert.match(migration, /ALTER COLUMN account_type DROP NOT NULL/i);
  assert.match(migration, /IF NOT EXISTS/i);
  assert.doesNotMatch(migration, /UPDATE\s+users/i);
  assert.match(runner, /CONFIRM_ACCOUNT_TYPE_MIGRATION/);
  assert.match(runner, /NULLABLE_ACCOUNT_TYPE_20260809/);
});

test('refresh token reuse commits family revocation before returning 401', async () => {
  const service = new AuthService();
  const refreshToken = jwt.sign(
    { sub: 7, sid: '00000000-0000-4000-8000-000000000001', type: 'refresh' },
    config.refreshTokenSecret,
    { expiresIn: '7d' },
  );
  const session = {
    id: '00000000-0000-4000-8000-000000000001',
    familyId: '00000000-0000-4000-8000-000000000002',
    tokenHash: createHmac('sha256', config.refreshTokenSecret).update(refreshToken).digest('hex'),
    revokedAt: new Date(),
    expiresAt: new Date(Date.now() + 60_000),
  };
  let familyRevoked = false;
  let transactionCommitted = false;
  const repository = {
    createQueryBuilder() {
      return {
        setLock() { return this; },
        where() { return this; },
        async getOne() { return session; },
      };
    },
    async update(criteria, patch) {
      assert.equal(criteria.familyId, session.familyId);
      assert.ok(patch.revokedAt instanceof Date);
      familyRevoked = true;
    },
  };
  const originalTransaction = AppDataSource.transaction;
  AppDataSource.transaction = async callback => {
    const result = await callback({ getRepository: () => repository });
    transactionCommitted = true;
    return result;
  };
  try {
    await assert.rejects(
      service.refreshToken(refreshToken),
      error => error?.code === 'REFRESH_REUSED' && error?.statusCode === 401,
    );
  } finally {
    AppDataSource.transaction = originalTransaction;
  }
  assert.equal(familyRevoked, true);
  assert.equal(transactionCommitted, true);
});

test('auth migration requires explicit OTP reset confirmation and is idempotent', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'scripts', 'apply-auth-migration.ts'),
    'utf8',
  );

  assert.match(source, /CONFIRM_AUTH_MIGRATION/);
  assert.match(source, /RESET_PENDING_OTP_20260801/);
  assert.match(source, /if \(before\.ready\)/);
  assert.match(source, /không chạy lại migration/);
});

test('login shop context includes display identity for immediate selection', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'auth.service.ts'),
    'utf8',
  );

  assert.match(source, /shopName:\s*shop\?\.shopName/);
  assert.match(source, /shopCode:\s*shop\?\.shopCode/);
});
