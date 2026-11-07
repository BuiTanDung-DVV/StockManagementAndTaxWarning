import { json } from 'express';

// The CSV itself is capped at 1 MB. Escaping quotes/newlines in JSON can
// double wire size. Other API routes keep their existing 256 KB limit.
export const productImportJson = json({ limit: '2200kb' });
