import { NextResponse } from 'next/server';
import { isPasswordConfigured, sessionFromCookieHeader } from './auth';

/** API Route 共享守卫：未配置密码=公开访问直接放行；已配置密码时未登录返回 401 */
export function guardRequest(req: Request): NextResponse | null {
  // 未配置密码 = 公开访问，直接放行（无需登录）
  if (!isPasswordConfigured()) return null;
  if (!sessionFromCookieHeader(req.headers.get('cookie'))) {
    return NextResponse.json({ error: '未登录' }, { status: 401 });
  }
  return null;
}

export function jsonError(message: string, status: number): NextResponse {
  return NextResponse.json({ error: message }, { status });
}
