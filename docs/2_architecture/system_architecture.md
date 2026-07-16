# 📌 시스템 아키텍처 (System Architecture)

> `event_storming.md`에서 도출한 5개 Bounded Context(Auth, Channel, Streaming, Chat, Notification)를 물리적 서비스로 배치하고, 인프라 구성 요소와 통신 방식을 정의한다.

## 1. 전체 구조 개요

* **기반:** Spring Cloud 기반 MSA
* **기본 구축 인프라:** API Gateway(Spring Cloud Gateway) + Eureka(Service Discovery)
  * 근거: Chat/Streaming처럼 트래픽에 따라 수평 확장되는 서비스의 동적 인스턴스 탐색, 단일 진입점 라우팅 및 JWT 1차 검증이 이 프로젝트의 핵심 가치(대규모 트래픽 처리)와 직결되기 때문.
* **보류:** Spring Cloud Config Server → 로컬 단일 환경에서는 중앙 설정관리 이점이 작고 부팅 순서 의존성(SPOF)만 늘어남. Docker Compose `.env` + 서비스별 `application.yml` profile로 대체. (`.clauderules` 5번 반영)

## 2. 아키텍처 다이어그램

```mermaid
flowchart TB
    subgraph Client["클라이언트"]
        OBS["🎥 OBS (스트리머)"]
        Web["👤 웹/앱 (시청자)"]
    end

    subgraph Edge["진입 계층"]
        GW["API Gateway\n(라우팅 + JWT 1차 검증)"]
        Eureka["Eureka\n(Service Discovery)"]
    end

    subgraph Media["미디어 계층 (Non-Spring)"]
        MediaSrv["Nginx-RTMP / SRS\n(RTMP 수신 → HLS 변환)"]
    end

    subgraph Services["비즈니스 서비스"]
        Auth["Auth Service"]
        Channel["Channel Service"]
        Streaming["Streaming Service"]
        Chat["Chat Service\n(WebSocket)"]
        Notification["Notification Service\n(SSE)"]
    end

    subgraph Data["데이터 / 브로커 계층"]
        MySQL[("MySQL\n(서비스별 스키마 분리)")]
        Redis[("Redis\n(캐시 + Pub/Sub)")]
        Broker{{"Message Broker\n(Kafka/RabbitMQ - tech_stack.md에서 확정)"}}
    end

    OBS -->|RTMP 송출| MediaSrv
    MediaSrv -->|스트림 키 검증 Webhook| Streaming
    Web -->|HLS 재생 (.m3u8/.ts)| MediaSrv

    Web -->|REST / WS| GW
    GW -.서비스 인스턴스 조회.-> Eureka
    Auth -.등록.-> Eureka
    Channel -.등록.-> Eureka
    Streaming -.등록.-> Eureka
    Chat -.등록.-> Eureka
    Notification -.등록.-> Eureka

    GW --> Auth
    GW --> Channel
    GW --> Streaming
    GW -->|WS 라우팅 (Sticky Session 불필요)| Chat
    GW --> Notification

    Auth --> MySQL
    Channel --> MySQL
    Channel --> Redis
    Streaming --> MySQL
    Chat --> Redis
    Chat -.영속화 optional.-> MySQL

    Streaming -->|방송_시작됨/종료됨 발행| Broker
    Broker -->|구독| Channel
    Broker -->|구독| Chat
    Broker -->|구독| Notification
```

## 3. 서비스 배치 및 책임

| 서비스 | 책임 | DB | 비고 |
|---|---|---|---|
| **API Gateway** | 라우팅, JWT 1차 검증, WebSocket 프록시 | - | Rate Limiting은 Gateway가 아닌 Chat 서비스 담당 (공통 레이어 과설계 방지) |
| **Eureka** | 서비스 인스턴스 등록/탐색 | - | 수평 확장되는 Chat/Streaming 인스턴스 탐색 용도 |
| **Auth** | 회원가입/로그인, JWT 발급 | MySQL (Member 스키마) | |
| **Channel** | 채널 정보, 스트림 키 발급, 팔로우, 라이브 목록 캐시 | MySQL (Channel/Follow 스키마) + Redis | 라이브 목록은 Redis Read Model로 제공 (RDBMS 조회 회피) |
| **Streaming** | 스트림 키 검증, 라이브 상태 관리, 이벤트 발행 주체 | MySQL (LiveStream 스키마) | 실제 RTMP/HLS 처리는 Media 컨테이너가 담당, 이 서비스는 검증/상태관리만 |
| **Chat** | WebSocket 세션, 도배 방지, Redis Pub/Sub 브로드캐스팅 | Redis (필수) + MySQL (영속화 optional) | DB 부하 시 저장 포기, 브로드캐스팅 유지 (Fallback) |
| **Notification** | 방송 시작 이벤트 구독 → SSE 팬아웃 | - | 온라인 유저 판별은 SSE 커넥션 레지스트리(인메모리 or Redis)로 관리 |

## 4. 통신 방식

* **동기 (Sync, REST/WS):** 클라이언트 ↔ Gateway ↔ 각 서비스. 사용자 요청-응답이 즉시 필요한 경우 (로그인, 채널 조회, 채팅 세션 연결 등).
* **비동기 (Async, Message Broker):** `event_storming.md`의 "서비스 간 이벤트 흐름" 표와 동일 — Streaming이 발행자, Channel/Chat/Notification이 구독자. 방송 시작/종료 시 팬아웃 처리에 사용하여 Streaming 서비스가 후속 처리 지연에 영향받지 않도록 격리.
* **미디어 계층:** OBS ↔ Media 컨테이너는 Gateway를 거치지 않는 별도 경로(RTMP 포트 직접 연결). 시청자의 HLS 재생도 Media 컨테이너에서 직접 서빙 (Gateway를 통한 세그먼트 파일 프록시는 불필요한 오버헤드).

## 5. 주요 설계 결정 사항

* **WebSocket + Gateway:** Chat 서비스는 Redis Pub/Sub으로 멀티 인스턴스 브로드캐스팅을 하므로, Gateway 단에서 Sticky Session이 불필요함 — 단순 라운드로빈 라우팅으로 충분.
* **DB 전략:** Database-per-Service 원칙 유지. 로컬 환경에서는 MySQL 컨테이너 1개에 서비스별 스키마를 분리하여 논리적 격리를 확보 (물리적으로는 단일 인스턴스로 리소스 절약).
* **Observability:** Prometheus/Grafana 등은 MVP 스코프 밖 — 오버엔지니어링 방지 원칙에 따라 제외. 향후 확장 지점으로만 남김.

## 6. 배포 구조 (Deployment View)

> §2 다이어그램이 서비스 간 논리적 관계(누가 누구를 호출/구독하는가)를 보여준다면, 이 섹션은 실제로 어떤 단위(컨테이너)로 떠서 어떤 네트워크·포트로 연결되는지를 다룬다. CDN은 로컬 Docker Compose 환경에 실제로 구축하지 않는 **확장 지점**이므로 점선으로 표기한다.

```mermaid
flowchart TB
    Viewer["👤 시청자"]
    OBS["🎥 OBS"]

    CDN{{"CDN Edge (확장 지점, 미구축)"}}

    subgraph Compose["Docker Compose Network (bridge)"]
        direction TB
        GW["gateway :8080"]
        Eureka["eureka :8761"]
        MediaSrv["nginx-rtmp\nRTMP :1935 / HLS :8081"]
        AuthSvc["auth-service"]
        ChannelSvc["channel-service"]
        StreamingSvc["streaming-service"]
        ChatSvc["chat-service"]
        NotiSvc["notification-service"]
        MySQL[("mysql :3306\n(internal only)")]
        Redis[("redis :6379\n(internal only)")]
        Broker{{"message-broker\n(internal only)"}}
    end

    OBS -->|RTMP :1935| MediaSrv
    Viewer -.HLS 요청 (확장 시 CDN 경유).-> CDN
    CDN -.origin pull.-> MediaSrv
    Viewer -->|"HLS 직접 요청 (현재 MVP)"| MediaSrv

    Viewer -->|:8080| GW
    GW --> AuthSvc & ChannelSvc & StreamingSvc & ChatSvc & NotiSvc
    AuthSvc & ChannelSvc & StreamingSvc & ChatSvc & NotiSvc -.등록/탐색.-> Eureka

    AuthSvc --> MySQL
    ChannelSvc --> MySQL & Redis
    StreamingSvc --> MySQL
    ChatSvc --> Redis
    StreamingSvc --> Broker
    Broker --> ChannelSvc & ChatSvc & NotiSvc
```

* **외부 노출 포트:** `gateway:8080`(REST/WS), `nginx-rtmp:1935`(RTMP 송출용), `nginx-rtmp:8081`(HLS 서빙용) — 이 세 개만 호스트에 바인딩하면 되고, 나머지(Eureka, MySQL, Redis, Broker, 각 비즈니스 서비스)는 Compose 내부 네트워크에서만 통신.
* **CDN 확장 지점:** 실제 구축 대상이 아니며, 트래픽 급증 시 Nginx-RTMP의 HLS 출력 포트(`:8081`)를 origin으로 두고 CDN이 세그먼트를 캐싱하는 구조로 확장 가능함을 보여주기 위한 설계 근거 자료. 로컬 MVP에서는 시청자가 `nginx-rtmp`에 직접 요청하는 경로를 사용한다.
* **Eureka 노출 범위:** 대시보드 확인 등 개발 편의를 위해 로컬에서는 호스트에 바인딩해도 무방하나, 실제 운영에서는 내부 전용으로 제한하는 것이 원칙.

## 7. Hot Spot 해소 현황 (`event_storming.md` 대비)

| # | 이슈 | 이 문서에서의 해소 |
|---|---|---|
| 1 | 알림 대상(온라인 유저) 판별 방식 | Notification 서비스 내 SSE 커넥션 레지스트리로 관리 (구체 구현은 이후 설계 단계) |
| 2 | MQ 종류 선택 (Kafka vs RabbitMQ) | 이 문서에서는 "Message Broker"로 추상화, `tech_stack.md`에서 ADR로 확정 예정 |
| 3 | Rate Limit 초과 시 처리 | `api_specification.md`에서 상세 정의 예정 |
| 4 | DB 부하 시 채팅 영속화 포기 기준선 | Chat 서비스 DB를 "optional 영속화"로 설계 확정. 구체적 트리거 조건(예: DB 응답 지연 임계치)은 `api_specification.md`/구현 단계에서 확정 |
| 5 | 스트림 키 검증 책임 주체 | **Streaming 서비스가 자체 검증**하는 것으로 확정 (Media 컨테이너 → Streaming Webhook 호출) — Auth 위임 시 불필요한 서비스 간 동기 호출이 하나 더 늘어나므로 배제 |
