import { env } from './env';

type Scope = 'health' | 'labs' | 'engine' | 'api' | 'store' | 'nutrition' | 'dining';

const isDev = env.appEnv === 'development';

function emit(level: 'debug' | 'info' | 'warn' | 'error', scope: Scope, msg: string, meta?: unknown) {
  if (level === 'debug' && !env.debugTelemetry) return;
  if ((level === 'debug' || level === 'info') && !isDev) return;

  const line = `[${scope}] ${msg}`;
  if (level === 'error') console.error(line, meta ?? '');
  else if (level === 'warn') console.warn(line, meta ?? '');
  else console.log(line, meta ?? '');
}

export const log = {
  debug: (scope: Scope, msg: string, meta?: unknown) => emit('debug', scope, msg, meta),
  info: (scope: Scope, msg: string, meta?: unknown) => emit('info', scope, msg, meta),
  warn: (scope: Scope, msg: string, meta?: unknown) => emit('warn', scope, msg, meta),
  error: (scope: Scope, msg: string, meta?: unknown) => emit('error', scope, msg, meta),
};
