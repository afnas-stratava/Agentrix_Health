import type { ImportErrorReason } from '@/schemas/connections';

/**
 * Lives in its own module so both the real client and the offline fixtures can
 * throw it without importing each other — `client.ts` imports the fixtures, so
 * the fixtures must not import back into `client.ts`.
 */
export class ImportFailed extends Error {
  constructor(
    readonly reason: ImportErrorReason,
    message: string,
  ) {
    super(message);
    this.name = 'ImportFailed';
  }
}
