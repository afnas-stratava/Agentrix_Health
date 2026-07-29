import * as AuthSession from 'expo-auth-session';
import * as WebBrowser from 'expo-web-browser';
import { env } from '@/lib/env';
import { log } from '@/lib/logger';

// Required so the in-app browser hands control back after the redirect.
WebBrowser.maybeCompleteAuthSession();

/**
 * We request read-only Gmail plus the user's address (to show which mailbox is
 * connected).
 *
 * `gmail.readonly` is a Google **Restricted** scope. Publishing with it
 * requires OAuth verification plus an annual third-party CASA security
 * assessment. Until that clears, the app works normally for accounts added as
 * test users in the Google Cloud console.
 *
 * `gmail.metadata` would be merely Sensitive rather than Restricted, but it
 * cannot read attachment bodies — which is the entire feature.
 */
export const GMAIL_SCOPES = [
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/userinfo.email',
  'openid',
] as const;

const DISCOVERY: AuthSession.DiscoveryDocument = {
  authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  tokenEndpoint: 'https://oauth2.googleapis.com/token',
  revocationEndpoint: 'https://oauth2.googleapis.com/revoke',
};

export class GmailAuthCancelled extends Error {
  constructor() {
    super('Google sign-in was cancelled');
    this.name = 'GmailAuthCancelled';
  }
}

export class GmailAuthFailed extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GmailAuthFailed';
  }
}

export class GmailNotConfigured extends Error {
  constructor() {
    super(
      'No Google OAuth client ID configured. Set EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID in your .env.',
    );
    this.name = 'GmailNotConfigured';
  }
}

export interface AuthorizationGrant {
  /** Short-lived authorization code, exchanged server-side. */
  code: string;
  /** PKCE verifier the backend needs to complete the exchange. */
  codeVerifier: string;
  redirectUri: string;
}

/**
 * Runs the authorization-code + PKCE flow and returns the grant.
 *
 * Deliberately stops at the code. The token exchange happens on the backend so
 * the long-lived refresh token — which grants read access to the user's entire
 * mailbox — never touches the device, is never written to AsyncStorage, and
 * cannot leak through a crash report or a state snapshot.
 */
export async function authorizeGmail(): Promise<AuthorizationGrant> {
  if (!env.googleClientId) throw new GmailNotConfigured();

  // Uses the app's `scheme` from app.config.ts, e.g. `vitals://oauth`.
  const redirectUri = AuthSession.makeRedirectUri({ scheme: 'vitals', path: 'oauth' });

  const request = new AuthSession.AuthRequest({
    clientId: env.googleClientId,
    redirectUri,
    scopes: [...GMAIL_SCOPES],
    responseType: AuthSession.ResponseType.Code,
    usePKCE: true,
    extraParams: {
      // Required together to receive a refresh token on the backend exchange.
      access_type: 'offline',
      prompt: 'consent',
      include_granted_scopes: 'true',
    },
  });

  const result = await request.promptAsync(DISCOVERY);

  if (result.type === 'cancel' || result.type === 'dismiss') {
    throw new GmailAuthCancelled();
  }

  if (result.type === 'error') {
    throw new GmailAuthFailed(
      result.error?.message ?? result.params['error_description'] ?? 'Google sign-in failed',
    );
  }

  if (result.type !== 'success' || !result.params['code']) {
    throw new GmailAuthFailed('Google did not return an authorization code');
  }

  if (!request.codeVerifier) {
    // Should be impossible with usePKCE, but exchanging without a verifier
    // would silently downgrade the flow's security.
    throw new GmailAuthFailed('PKCE verifier missing from the authorization request');
  }

  log.info('labs', 'Gmail authorization granted, forwarding code for exchange');

  return {
    code: result.params['code'],
    codeVerifier: request.codeVerifier,
    redirectUri,
  };
}

/** True when the granted scopes are enough to actually read attachments. */
export function hasRequiredScopes(granted: readonly string[]): boolean {
  return granted.some((scope) => scope.includes('gmail.readonly'));
}
