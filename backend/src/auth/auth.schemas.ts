import { z } from 'zod';

export const normalizeEmail = (value: string): string => value.trim().toLowerCase();

const gmailSchema = z
  .string()
  .trim()
  .max(254)
  .email('Địa chỉ Gmail không hợp lệ')
  .transform(normalizeEmail)
  .refine((email) => email.endsWith('@gmail.com'), {
    message: 'Chỉ hỗ trợ đăng ký bằng địa chỉ @gmail.com',
  });

export const securePasswordSchema = z
  .string()
  .min(8, 'Mật khẩu phải có ít nhất 8 ký tự')
  .max(64, 'Mật khẩu không được vượt quá 64 ký tự')
  .refine((value) => Buffer.byteLength(value, 'utf8') <= 72, {
    message: 'Mật khẩu quá dài',
  })
  .refine((value) => /[A-Z]/.test(value), { message: 'Mật khẩu phải có chữ hoa' })
  .refine((value) => /[a-z]/.test(value), { message: 'Mật khẩu phải có chữ thường' })
  .refine((value) => /\d/.test(value), { message: 'Mật khẩu phải có chữ số' })
  .refine((value) => /[^A-Za-z0-9]/.test(value), {
    message: 'Mật khẩu phải có ký tự đặc biệt',
  });

const accountTypeSchema = z.enum(['SHOP', 'PERSONAL']);

const bcryptPasswordInputSchema = z
  .string()
  .min(1, 'Vui lòng nhập mật khẩu')
  .max(64, 'Mật khẩu không được vượt quá 64 ký tự')
  .refine((value) => Buffer.byteLength(value, 'utf8') <= 72, {
    message: 'Mật khẩu quá dài',
  });

export const registerSchema = z.object({
  username: gmailSchema,
  password: securePasswordSchema,
  fullName: z.string().trim().min(2, 'Họ và tên phải có ít nhất 2 ký tự').max(100, 'Họ và tên quá dài'),
  accountType: accountTypeSchema.default('PERSONAL'),
  otpCode: z.string().regex(/^\d{6}$/, 'Mã OTP phải gồm đúng 6 chữ số'),
}).strict();

export const loginSchema = z.object({
  username: z.string().trim().min(3, 'Gmail hoặc tên đăng nhập phải từ 3 ký tự trở lên').max(254, 'Tên đăng nhập quá dài'),
  password: bcryptPasswordInputSchema,
}).strict();

export const sendOtpSchema = z.object({
  identifier: gmailSchema,
  isRegistration: z.boolean().optional().default(false),
  checkExists: z.boolean().optional().default(false),
}).strict();

export const forgotPasswordSchema = z.object({ identifier: gmailSchema }).strict();

export const resetPasswordSchema = z.object({
  identifier: gmailSchema,
  newPassword: securePasswordSchema,
  otpCode: z.string().regex(/^\d{6}$/, 'Mã OTP phải gồm đúng 6 chữ số'),
}).strict();

export const refreshTokenSchema = z.object({
  refresh_token: z.string().min(20).max(4096).optional(),
}).strict();

export const googleAuthSchema = z.object({
  idToken: z.string().min(100).max(12000),
  accountType: accountTypeSchema.default('PERSONAL'),
  createIfMissing: z.boolean().default(false),
}).strict();

export const changePasswordSchema = z.object({
  currentPassword: bcryptPasswordInputSchema,
  newPassword: securePasswordSchema,
}).strict();

export const updateProfileSchema = z.object({
  fullName: z.string().trim().min(2).max(100).optional(),
  phone: z.string().trim().max(20).regex(/^[0-9+ .()-]*$/).optional(),
  avatarUrl: z.string().trim().max(2048).refine(
    value => value === '' || URL.canParse(value),
    { message: 'Đường dẫn ảnh đại diện không hợp lệ' },
  ).optional(),
}).strict();

export const completeOnboardingSchema = z.object({
  username: z.string().trim().min(4).max(50).regex(/^\S+$/).optional(),
  phone: z.string().trim().regex(/^(0|\+84)\d{8,9}$/).optional(),
  fullName: z.string().trim().min(2).max(100),
  shopName: z.string().trim().min(2).max(200).optional(),
  ownerName: z.string().trim().max(200).optional(),
  address: z.string().trim().max(500).optional(),
  shopCode: z.string().trim().min(4).max(20).regex(/^[A-Za-z0-9]+$/).optional(),
  shopId: z.string().regex(/^\d+$/).optional(),
}).strict();

export type RegisterDto = z.infer<typeof registerSchema>;
export type LoginDto = z.infer<typeof loginSchema>;
export type SendOtpDto = z.infer<typeof sendOtpSchema>;
export type ForgotPasswordDto = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordDto = z.infer<typeof resetPasswordSchema>;
export type GoogleAuthDto = z.infer<typeof googleAuthSchema>;
