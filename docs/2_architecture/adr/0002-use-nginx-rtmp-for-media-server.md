# ADR-0002: 미디어 서버로 Nginx-RTMP 채택

## 상태 (Status)
Accepted

## 배경 (Context)
스트리머가 OBS로 RTMP 프로토콜을 통해 영상을 송출하면, 미디어 서버가 이를 수신하여 시청자가 재생 가능한 HLS(.m3u8/.ts)로 변환해야 한다. `mvp_scope.md`에서 다중 화질 트랜스코딩은 명시적으로 배제했으므로, **단일 원본 화질의 RTMP→HLS 변환**만 처리하면 된다. 후보는 Nginx-RTMP와 SRS(Simple Realtime Server) 두 가지를 검토했다.

## 검토한 대안 (Alternatives)

| 항목 | Nginx-RTMP | SRS |
|---|---|---|
| 성숙도/레퍼런스 | 매우 풍부, 표준 구성 예제 다수 | 상대적으로 적음 |
| 지원 프로토콜 | RTMP 수신 + HLS 변환(내장 모듈)에 집중 | RTMP/HLS/HTTP-FLV/WebRTC/SRT 등 멀티 프로토콜, 클러스터링 지원 |
| 설정 복잡도 | 단순 (nginx.conf 몇 줄로 구성 가능) | 기능이 많아 학습 곡선이 있음 |
| 저지연(LL-HLS) | 제한적 | 더 나은 저지연 옵션 제공 |
| 이 프로젝트와의 적합성 | 단일 화질 HLS 변환만 필요한 스코프에 충분 | 안 쓸 기능(멀티 프로토콜, 클러스터링)이 많아 오버스펙 |

## 결정 (Decision)
미디어 서버로 **Nginx-RTMP**를 채택한다. Streaming 서비스와는 별도 컨테이너로 분리하고, 스트림 키 검증은 Webhook(`on_publish` 콜백)으로 Streaming 서비스에 위임한다.

## 근거 (Rationale)
1. MVP 스코프(단일 원본 화질, 멀티 프로토콜/저지연 불필요)에서 SRS의 부가 기능은 사용하지 않을 가능성이 높음 — `.clauderules`의 "오버엔지니어링 방지" 원칙과 부합.
2. 레퍼런스가 풍부해 트러블슈팅이 쉽고, 포트폴리오 면접에서 "왜 이 도구를 선택했는가"에 대한 설명이 명확함.
3. RTMP→HLS 변환이라는 핵심 요구사항 하나에 집중된 도구이므로, Streaming 서비스는 Webhook 연동 하나로만 결합되어 서비스 간 결합도가 낮게 유지됨.

## 결과 (Consequences)
* 향후 초저지연(LL-HLS) 스트리밍이나 WebRTC 송출이 요구사항에 추가되면 SRS로 전환을 재검토해야 한다 (현재 스코프에서는 해당 없음).
* Nginx-RTMP가 생성한 HLS 세그먼트를 origin으로 두고, 필요 시 CDN이 이를 캐싱하는 구조로 자연스럽게 확장할 수 있다 (CDN 도입 여부는 별도 논의).
