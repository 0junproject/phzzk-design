# 📌 기술 스택 명세 (Tech Stack)

> 각 기술 선택의 상세 근거는 `adr/` 하위 문서를 참조. 이 문서는 전체 스택을 한눈에 보기 위한 요약이다.

## 공통 인프라

| 구분 | 선택 | 근거 |
|---|---|---|
| API Gateway | Spring Cloud Gateway | `system_architecture.md` §1 참조 |
| Service Discovery | Eureka | `system_architecture.md` §1 참조 |
| Config 관리 | Docker Compose `.env` + `application.yml` profile (Config Server 미도입) | `.clauderules` 5번 |
| 캐시 | Redis (단일 인스턴스, 캐시 + Pub/Sub 겸용) | `system_architecture.md` §5 |
| DB | MySQL 단일 인스턴스, 서비스별 스키마 분리 | `system_architecture.md` §5 |
| 미디어 서버 | **Nginx-RTMP** | [ADR-0002](adr/0002-use-nginx-rtmp-for-media-server.md) |
| 메시지 브로커 | **Kafka** (토픽: `broadcast-events`, `chat-message-log` 분리) | [ADR-0004](adr/0004-message-broker-selection.md) |
| Observability | 미도입 (MVP 스코프 제외) | `system_architecture.md` §5 |

## 서비스별 스택

| 서비스 | 통신 | 저장소 | 미디어/외부 연동 |
|---|---|---|---|
| Auth | REST | MySQL (Member) | - |
| Channel | REST | MySQL (Channel/Follow) + Redis | - |
| Streaming | REST + Webhook | MySQL (LiveStream) | Nginx-RTMP `on_publish` 콜백으로 스트림 키 검증 |
| Chat | WebSocket | Redis(Pub/Sub, 필수) + MySQL(영속화 optional, MQ 배치 저장) | 프레임워크(Spring Boot/WebFlux/Node.js) 미확정, [ADR-0003](adr/0003-chat-service-framework-selection.md) |
| Notification | SSE | 커넥션 레지스트리 | - |

## ADR 목록

| 번호 | 제목 | 상태 |
|---|---|---|
| [0001](adr/0001-use-sse-for-notification.md) | 알림 전달에 SSE 사용 | ⬜ 문서 작성 대기 (결정 자체는 `mvp_scope.md`에 이미 반영됨) |
| [0002](adr/0002-use-nginx-rtmp-for-media-server.md) | 미디어 서버로 Nginx-RTMP 채택 | ✅ 작성 완료 |
| [0003](adr/0003-chat-service-framework-selection.md) | Chat 서비스 프레임워크 선정 (Spring Boot vs WebFlux vs Node.js) | 🟡 검토 중 (최종 선택 보류) |
| [0004](adr/0004-message-broker-selection.md) | 메시지 브로커로 Kafka 채택 + 토픽 분리 전략 | ✅ 작성 완료 |

## 남은 결정 사항

* **CDN 도입 여부:** HLS 배포용 확장 지점으로 논의 중 (아직 architecture 다이어그램에 미반영).
* **Chat 서비스 프레임워크:** [ADR-0003](adr/0003-chat-service-framework-selection.md) — Spring Boot / WebFlux / Node.js 중 미확정.
