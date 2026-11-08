import { createContext, useContext, useMemo, type ReactNode } from 'react';
import { ApiClient, type FetchLike } from './client';
import { createEndpoints, type Endpoints } from './endpoints';
import type { TokenStore } from './tokenStore';

export interface ApiContextValue {
  client: ApiClient;
  api: Endpoints;
  isMock: boolean;
}

const ApiContext = createContext<ApiContextValue | null>(null);

export function createApi(options: {
  baseUrl: string;
  tokenStore: TokenStore;
  fetchImpl?: FetchLike;
  isMock?: boolean;
}): ApiContextValue {
  const client = new ApiClient(options);
  return { client, api: createEndpoints(client), isMock: options.isMock ?? false };
}

export function ApiProvider({ value, children }: { value: ApiContextValue; children: ReactNode }) {
  const memo = useMemo(() => value, [value]);
  return <ApiContext.Provider value={memo}>{children}</ApiContext.Provider>;
}

export function useApiContext(): ApiContextValue {
  const ctx = useContext(ApiContext);
  if (!ctx) throw new Error('useApiContext doit être utilisé sous <ApiProvider>.');
  return ctx;
}

export function useApi(): Endpoints {
  return useApiContext().api;
}
