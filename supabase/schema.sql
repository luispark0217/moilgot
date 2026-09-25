-- 모일곳 MVP 스키마: Supabase > SQL Editor 에 통째로 붙여넣고 Run
create extension if not exists pgcrypto;

create table if not exists meetings (
  code        text primary key,               -- 초대 링크 코드 (/j/코드)
  host_name   text not null,
  name        text,
  date_ts     bigint not null,                -- 약속 날짜 (자정 기준 ms)
  time_min    int not null,                   -- 약속 시간 (0~1439분)
  purposes    int[] default '{}',
  vibes       int[] default '{}',
  count       int not null default 2,
  status      text not null default 'gathering',  -- gathering | confirmed
  hub         text,
  place       text,
  place_cat   int,
  legs        jsonb,                          -- { 참여자 id: 이동 분 }
  solo        boolean default false,          -- 방장 단독 결정 여부
  created_at  timestamptz default now()
);

create table if not exists participants (
  id          uuid primary key default gen_random_uuid(),
  code        text not null references meetings(code) on delete cascade,
  device_id   text not null,                  -- 로그인 없이 기기별 식별
  name        text not null default '',
  is_host     boolean default false,
  state       text default 'opened',          -- opened | done
  st          text,                           -- 출발역
  acc         int,                            -- 역까지 접근 시간(분)
  loc         jsonb,                          -- { label: 동네 이름, accMode } ※ 정확한 좌표는 저장 안 함
  race        boolean default true,
  push        boolean default true,
  created_at  timestamptz default now(),
  unique (code, device_id)
);

create table if not exists events (
  id          bigserial primary key,
  code        text,
  device_id   text,
  name        text not null,
  props       jsonb,
  created_at  timestamptz default now()
);

create index if not exists participants_code_idx on participants(code);
create index if not exists events_name_idx on events(name, created_at);

-- MVP용 접근 정책: 링크(코드)를 아는 사람은 읽고 쓸 수 있음. 정식 출시 전엔 강화 필요.
alter table meetings enable row level security;
alter table participants enable row level security;
alter table events enable row level security;

drop policy if exists "meetings rw" on meetings;
create policy "meetings rw" on meetings for all using (true) with check (true);
drop policy if exists "participants rw" on participants;
create policy "participants rw" on participants for all using (true) with check (true);
drop policy if exists "events insert" on events;
create policy "events insert" on events for insert with check (true);

-- 실시간 반영 켜기
alter publication supabase_realtime add table meetings;
alter publication supabase_realtime add table participants;

-- 가설 검증용 조회 예시
-- 1) 모임별 퍼널
-- select name, count(distinct code) from events group by name order by 2 desc;
-- 2) 약속 확정률
-- select count(*) filter (where status='confirmed')::float / count(*) from meetings;
-- 3) 참여자 → 새 방장 전환 (참여했던 기기가 나중에 방장이 된 비율)
-- select count(distinct g.device_id) filter (where h.device_id is not null)::float / count(distinct g.device_id)
-- from participants g left join participants h on h.device_id = g.device_id and h.is_host and h.created_at > g.created_at
-- where not g.is_host;

-- v4: 후보 시간 투표(when2meet) — 기존 DB에도 그대로 실행 가능
alter table meetings add column if not exists mode text default 'fixed';   -- fixed | poll
alter table meetings add column if not exists slots jsonb default '[]';    -- [{date, time}]
alter table participants add column if not exists avail int[] default '{}'; -- 가능한 후보 인덱스

-- v5: 약속 당일 실데이터 (진행 상태 + 채팅)
alter table participants add column if not exists phase text default 'idle';      -- idle | prep | moving | arrived
alter table participants add column if not exists prep_step int default 0;
alter table participants add column if not exists status text;
alter table participants add column if not exists progress real default 0;         -- 0~1, 정확한 좌표는 저장 안 함
alter table participants add column if not exists departed_at bigint;
alter table participants add column if not exists arrived_at bigint;
alter table participants add column if not exists eta int;                         -- 남은 분
alter table participants add column if not exists gps boolean default false;

create table if not exists messages (
  id          bigserial primary key,
  code        text not null references meetings(code) on delete cascade,
  device_id   text,
  name        text,
  text        text not null,
  sys         boolean default false,
  created_at  timestamptz default now()
);
create index if not exists messages_code_idx on messages(code, id);
alter table messages enable row level security;
drop policy if exists "messages rw" on messages;
create policy "messages rw" on messages for all using (true) with check (true);
alter publication supabase_realtime add table messages;
