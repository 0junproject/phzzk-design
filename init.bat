#!/bin/bash

# 1. 디렉토리 생성
mkdir -p docs/1_requirements
mkdir -p docs/2_architecture/adr
mkdir -p docs/3_design

# 2. 액터 정의서 생성
cat << 'EOF' > docs/1_requirements/actor_definition.md
# 📌 액터 (Actor) 정의서

## 1. 유저 (User)
플랫폼에 접속하여 시스템과 상호작용하는 모든 사람을 의미하는 최상위 개념.
* **비회원 (Guest):** 인증을 거치지 않은 유저. (권한: 메인 화면 조회, 영상 시청)
* **회원 (Member):** JWT 인증을 완료한 유저. (권한: Guest 권한 + 스트리머 팔로우)

## 2. 시청자 (Viewer)
특정 스트리머의 채널에 입장하여 콘텐츠를 소비하는 로그인된 유저.
* **역할 및 권한:** HLS 영상을 수신하며, 채팅 채널(웹소켓)에 접속하여 실시간 채팅 메시지를 송수신함.

## 3. 스트리머 (Streamer)
방송 시스템을 통해 콘텐츠를 생산하고 송출하는 주체.
* **역할 및 권한:** 고유한 스트림 키를 발급/관리하며, 방송 시작(ON) 및 종료(OFF) 상태를 제어하여 팔로워 알림을 트리거함.
EOF

# 3. 유비쿼터스 언어 사전 생성
cat << 'EOF' > docs/1_requirements/ubiquitous_language.md
# 📌 유비쿼터스 용어 (Ubiquitous Language)

## 핵심 도메인 (Core Domain)
* **채널 (Channel):** 스트리머가 방송을 진행하는 고유한 공간.
* **라이브 스트림 (Live Stream):** 스트리머가 현재 실시간으로 송출하고 있는 영상 및 음성 데이터.
* **스트림 키 (Stream Key):** 스트리머가 외부 송출 프로그램(OBS 등)을 통해 플랫폼 서버로 영상을 보낼 때 사용하는 고유 인증 암호.
* **채팅 (Chat):** 라이브 스트림 진행 중 채널 내에서 시청자와 스트리머가 주고받는 실시간 텍스트 메시지.
* **라이브 상태 (Live Status):** 채널의 현재 방송 진행 여부 (ON/OFF).
EOF

# 4. MVP 스코프 정의서 생성
cat << 'EOF' > docs/1_requirements/mvp_scope.md
# 📌 MVP (Minimum Viable Product) 기능 스코프

## 1. 포함된 핵심 기능
대규모 트래픽 환경에서의 실시간성(Real-time)과 안정성을 증명하기 위한 핵심 기능.
1. **인증/유저:** JWT 로그인, 팔로우/언팔로우
2. **스트리밍:** 스트림 키 발급/검증, RTMP 수신 및 HLS 변환, 라이브 상태 관리
3. **채널:** Redis 캐싱 기반 현재 라이브 중인 방송 목록 제공
4. **실시간 채팅:** 웹소켓, Redis Pub/Sub을 활용한 멀티 서버 브로드캐스팅, 도배 방지(Rate Limiting) 적용
5. **실시간 알림:** SSE 기반 비동기 팔로워 방송 시작 알림 (메시지 큐 활용)

## 2. 제외된 기능 (제외 사유)
* **결제/후원/구독:** 금융 도메인 특성상 비즈니스 로직이 과도하게 커짐. 트래픽 분산이라는 본질적 목표에 집중하기 위해 배제.
* **VOD (다시보기):** 동영상 파일 스토리지 인프라 관리 공수가 커 실시간성 처리에 집중하기 위해 배제.
* **커뮤니티/댓글:** 단순 CRUD 위주의 기능으로 백엔드 아키텍처 어필에 부적합.
* **다중 화질 트랜스코딩:** 인프라 자원 소모가 크고 미디어 엔지니어링 영역에 가까워 단일 원본 화질로 대체.
EOF

# 5. 빈 문서 파일 생성 (Placeholder)
touch docs/1_requirements/user_scenario.md
touch docs/2_architecture/event_storming.md
touch docs/2_architecture/system_architecture.md
touch docs/2_architecture/tech_stack.md
touch docs/3_design/api_specification.md
touch docs/3_design/erd.md
touch docs/3_design/sequence_diagram.md

echo "✅ 문서 디렉토리 및 초기 파일 생성 완료!"