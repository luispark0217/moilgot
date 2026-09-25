# 모일곳 MVP

모바일 웹 한 페이지(`index.html`) + Vercel 서버리스 함수 1개 + Supabase DB로 동작해요.
설정값을 비워두면 한 기기 안에서 도는 데모 모드, 채우면 친구들이 카톡 링크로 실제 참여하는 모드가 돼요.

```
index.html            앱 전체 (맨 위 CONFIG에서 연동을 켜요)
api/transit.js        카카오 대중교통 길찾기 프록시 (REST 키는 서버에만)
supabase/schema.sql   DB 테이블·권한·실시간 설정 (한 번 실행)
vercel.json           /j/코드 초대 링크를 앱으로 연결
og.png                카톡 링크 미리보기 이미지
places.sample.json    크롤링 장소 데이터 형식 예시
package.json          ESM 설정
```

## 동작 흐름 (온라인 모드)

1. 방장이 모임을 만들고 4단계(출발지)에 들어가는 순간 `meetings`에 모임, `participants`에 방장이 저장돼요.
2. 초대 링크 `https://도메인/j/코드`를 카톡으로 보내요. 카톡엔 `og.png` 카드가 떠요.
3. 친구가 링크를 열면 앱 설치·가입 없이 초대장 화면이 떠요. 여는 순간 방장 화면에 "링크 확인 · 입력하는 중"이 표시돼요.
4. 친구가 이름과 위치를 넣으면 방장 화면에 실시간으로 "입력 완료"가 떠요. 정확한 좌표는 저장하지 않고 역·동네 이름·접근 시간만 저장해요.
5. 방장은 전원을 기다리거나, 2명 이상이면 "지금 입력한 N명으로 찾기"로 진행할 수 있어요.
6. 방장이 장소를 확정하면 친구 화면이 바로 "약속 확정"으로 바뀌고, 내 출발 시간·카카오맵 길찾기·캘린더 추가(출발 알림 포함)·"다음 약속은 내가 잡기" 버튼이 보여요.
7. 방장이 카톡으로 갔다가 브라우저가 새로고침돼도, 홈의 "이어서 하기"로 만들던 모임에 돌아와요.

## 1. Supabase (10분)

1. supabase.com 가입 → New project (지역은 Northeast Asia (Seoul)).
2. SQL Editor → `supabase/schema.sql` 내용을 붙여넣고 Run.
3. Project Settings → API에서 Project URL과 anon public 키를 복사해 `index.html`의 CONFIG에 넣어요. anon 키는 공개용이라 브라우저에 있어도 괜찮아요.

## 2. 카카오 디벨로퍼스 (지도·검색·대중교통, 선택)

1. 앱 생성 → 플랫폼 > Web에 배포 도메인과 `http://localhost:3000` 등록.
2. 카카오맵 사용 설정 켜기.
3. JavaScript 키는 CONFIG의 `KAKAO_JS_KEY`에, REST API 키는 Vercel 환경변수 `KAKAO_REST_KEY`에만 넣어요.
4. 테스트 앱 상태에선 대중교통 API 한도가 아주 작아요. 실사용 테스트 전에 일반 앱으로 전환하세요.

## 3. index.html 설정

```js
const CONFIG = {
  KAKAO_JS_KEY: "",                       // 카카오 JavaScript 키
  TRANSIT_ENDPOINT: "/api/transit",       // 카카오 REST 키를 Vercel에 넣었다면
  INVITE_BASE: "https://moilgot.vercel.app/j/",  // 온라인 모드에선 자동으로 현재 도메인 사용
  PLACES_URL: "",                         // 크롤링 데이터 준비되면 "/places.json"
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJ...",
};
```

## 4. Vercel 배포

1. 이 폴더를 GitHub 저장소로 올려요.
2. vercel.com → Add New Project → 저장소 선택 → Framework Preset은 Other → Deploy.
3. (카카오 쓰는 경우) Settings → Environment Variables에 `KAKAO_REST_KEY` 추가 후 Redeploy.
4. 확인: 폰으로 사이트 열기 → 새 모임 → 4단계 → 링크 복사 → 다른 폰(또는 시크릿 창)에서 링크 열기 → 위치 입력 → 첫 폰에 바로 뜨면 성공.

카톡은 링크 미리보기를 캐시해요. 미리보기가 옛날 모습이면 카카오 디벨로퍼스의 "공유 디버거"에서 캐시를 지우세요.

## 5. 가설 지표 보기

앱의 주요 행동이 `events` 테이블에 쌓여요: `create_start`, `meeting_created`, `guest_opened`, `guest_done`, `result_view`, `places_view`, `vote_start`, `confirmed`(props.solo로 단독 결정 구분), `guest_to_host`, `ics`, `race_start`, `roulette`.
`schema.sql` 맨 아래에 확정률, 참여자→새 방장 전환율 조회 예시가 있어요.

## 6. 크롤링 장소 데이터 (개발팀)

`places.sample.json` 형식의 배열을 `places.json`으로 두고 `PLACES_URL`을 채우면 추천 지점 반경 800m 안의 실제 가게가 표시돼요.

| 필드 | 필수 | 설명 |
|---|---|---|
| name | O | 가게 이름 |
| category | O | `식당` `카페` `술집` `작업` `놀거리` `산책` 중 하나 |
| lat, lng | O | WGS84 좌표 |
| rating | | 평점(0~5) |
| reviews | | 리뷰 수 표시용 문자열 |
| tags | | `조용한` `가성비` `뷰 맛집` `오래 앉기` 등 |

## 7. 알아둘 한계

- 권한 정책은 "코드를 아는 사람은 읽고 쓸 수 있음"으로 열어뒀어요. 테스트엔 충분하지만 정식 출시 전엔 강화해야 해요.
- 투표와 도착 레이스는 아직 방장 기기 안의 시뮬레이션이에요. 레이스는 GPS 대신 "출발/도착" 버튼 방식으로 먼저 붙이는 걸 권해요 (위치정보법·배터리 부담).
