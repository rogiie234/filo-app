// Bound every database/Storage request, including response-body reads.
export function purgeFetch(deadline: number, http: typeof fetch = fetch): typeof fetch {
  return (input, init) => {
    const remaining = deadline - Date.now();
    if (remaining <= 0) return Promise.reject(new DOMException("Purge deadline reached", "TimeoutError"));
    const timeout = AbortSignal.timeout(Math.min(10000, remaining));
    const original = init?.signal ?? (input instanceof Request ? input.signal : undefined);
    return http(input, { ...init, signal: original ? AbortSignal.any([original, timeout]) : timeout });
  };
}
