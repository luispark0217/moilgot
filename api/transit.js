// Vercel 서버리스 함수: GET /api/transit?sx=경도&sy=위도&ex=경도&ey=위도
// 카카오 대중교통 길찾기 API를 서버에서 호출해 REST 키를 브라우저에 노출하지 않아요.
// Vercel 프로젝트 환경변수 KAKAO_REST_KEY 에 카카오 REST API 키를 넣어주세요.
export default async function handler(req, res) {
  const { sx, sy, ex, ey } = req.query;
  if (![sx, sy, ex, ey].every((v) => v !== undefined && v !== "" && !isNaN(Number(v)))) {
    return res.status(400).json({ error: "sx, sy, ex, ey(경도·위도)가 필요해요" });
  }
  if (!process.env.KAKAO_REST_KEY) {
    return res.status(500).json({ error: "서버에 KAKAO_REST_KEY 환경변수가 없어요" });
  }
  const url = new URL("https://dapi.kakao.com/v2/routing/publictraffic");
  url.search = new URLSearchParams({ start_x: sx, start_y: sy, end_x: ex, end_y: ey }).toString();
  try {
    const r = await fetch(url, { headers: { Authorization: `KakaoAK ${process.env.KAKAO_REST_KEY}` } });
    const j = await r.json();
    if (!r.ok || !Array.isArray(j.routes) || j.routes.length === 0) {
      return res.status(502).json({ error: j.message || "경로를 찾지 못했어요", code: j.code });
    }
    const best = j.routes.reduce((a, b) => (a.properties.totalTime <= b.properties.totalTime ? a : b));
    res.setHeader("Cache-Control", "s-maxage=86400, stale-while-revalidate=604800");
    return res.status(200).json({
      minutes: Math.round(best.properties.totalTime / 60),
      transfers: best.properties.transfers ?? 0,
      fare: best.properties.fare?.value ?? null,
    });
  } catch (e) {
    return res.status(502).json({ error: "카카오 API 호출 실패" });
  }
}
