export class AuthError extends Error {
  constructor(
    message: string,
    public readonly statusCode = 400,
    public readonly code = 'AUTH_ERROR',
  ) {
    super(message);
    this.name = 'AuthError';
  }
}
