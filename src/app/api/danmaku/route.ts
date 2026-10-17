import { NextResponse } from 'next/server';
import { guardRequest } from '@/lib/api-guard';

export const runtime = 'nodejs';

/** 本地弹幕聚合服务（danmu_api）地址，可用 DANMU_API_BASE 覆盖 */
const DANMU_API_BASE = (process.env.DANMU_API_BASE || 'http://127.0.0.1:9321').replace(/\/+$/, '');

interface DanmuJsonComment {
  cid?: number;
  /** danmu_api JSON 格式："时间,模式,颜色,来源" */
  p?: string;
  m?: string;
  t?: number;
  like?: number;
}

interface ArtplayerComment {
  text: string;
  time: number;
  color: string;
  mode: 0 | 1 | 2;
  border: boolean;
}

/** B 站式模式 → ArtPlayer 插件模式（0 滚动 / 1 顶部 / 2 底部） */
function toArtplayerMode(mode: number): 0 | 1 | 2 {
  if (mode === 4) return 2; // 底部
  if (mode === 5) return 1; // 顶部
  return 0; // 滚动
}

export async function GET(req: Request) {
  const guarded = guardRequest(req);
  if (guarded) return guarded;

  const url = new URL(req.url);
  const title = (url.searchParams.get('title') || '').trim();
  const episode = parseInt(url.searchParams.get('episode') || '0', 10) || 0;
  const total = parseInt(url.searchParams.get('total') || '0', 10) || 0;
  const year = (url.searchParams.get('year') || '').trim();

  if (!title) {
    return NextResponse.json({ matched: false, comments: [], error: '缺少 title 参数' }, { status: 400 });
  }

  // 多集 → 标题 S01E01；单集/电影 → 标题（带年份）
  const fileName = total > 1 && episode > 0
    ? `${title} S01E${String(episode).padStart(2, '0')}`
    : (year ? `${title} (${year})` : title);

  try {
    const matchRes = await fetch(`${DANMU_API_BASE}/api/v2/match`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fileName }),
      signal: AbortSignal.timeout(90000),
    });
    if (!matchRes.ok) {
      return NextResponse.json({ matched: false, fileName, comments: [], error: `match HTTP ${matchRes.status}` });
    }
    const match = await matchRes.json();
    const first = Array.isArray(match?.matches) ? match.matches[0] : null;
    if (!first?.episodeId) {
      return NextResponse.json({ matched: false, fileName, comments: [] });
    }

    const commentRes = await fetch(`${DANMU_API_BASE}/api/v2/comment/${first.episodeId}?format=json`, {
      signal: AbortSignal.timeout(90000),
    });
    if (!commentRes.ok) {
      return NextResponse.json({
        matched: false,
        fileName,
        source: first.animeTitle,
        episodeTitle: first.episodeTitle,
        comments: [],
        error: `comment HTTP ${commentRes.status}`,
      });
    }

    const data = await commentRes.json();
    const raw: DanmuJsonComment[] = Array.isArray(data?.comments) ? data.comments : [];
    const comments: ArtplayerComment[] = raw
      .map((c) => {
        const parts = String(c.p || '').split(',');
        const time = parseFloat(parts[0] || '0');
        const modeNum = parseInt(parts[1] || '1', 10);
        const colorNum = parseInt(parts[2] || '16777215', 10);
        const hex = Number.isFinite(colorNum)
          ? `#${Math.max(0, Math.min(0xffffff, colorNum)).toString(16).padStart(6, '0')}`
          : '#FFFFFF';
        return {
          text: String(c.m ?? '').trim(),
          time: Number.isFinite(time) ? time : 0,
          color: hex,
          mode: toArtplayerMode(modeNum),
          border: false,
        };
      })
      .filter((c) => c.text && c.time >= 0);

    return NextResponse.json({
      matched: true,
      fileName,
      source: first.animeTitle,
      episodeTitle: first.episodeTitle,
      count: comments.length,
      comments,
    });
  } catch (err) {
    return NextResponse.json({
      matched: false,
      fileName,
      comments: [],
      error: err instanceof Error ? err.message : String(err),
    });
  }
}