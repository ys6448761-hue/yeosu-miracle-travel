# 🚀 여수 기적여행 (Yeosu Miracle Travel)

B2B2C 패키지 예약·배정·정산 시스템

## 📋 프로젝트 개요

- **목표**: 여수 지역 소원 여행객을 위한 완전 자동화된 예약 시스템
- **기능**: 견적 생성, 예약 관리, 자동 배정, 정산 자동화
- **매출 모델**: 15% 수수료
- **확장성**: 다른 지역 복제 가능

## 🎯 핵심 기능

### 1. 패키지 옵션
- **1박 패키지**: 249,900원
- **2박 패키지**: 449,900원
- **3박 패키지**: 649,900원

### 2. 숙소 (4가지)
- 여수 프리미엄 리조트 (150,000원/박)
- 코지 게스트하우스 (80,000원/박)
- 해양 럭셔리 스위트 (250,000원/박)
- 여수 스테이 호텔 (120,000원/박)

### 3. 레저 활동 (9가지)
- 해양 일몰 크루즈
- 스쿠버 다이빙
- 서핑 레슨
- 여수 케이블카 + 트레킹
- 해상 사찰 투어
- 도자기 공예 체험
- 여수 해산물 요리 클래스
- 여수 야시장 투어
- 다도해 아일랜드 호핑

## 🗄️ 데이터베이스 구조

### 7개 테이블
1. `users` - 사용자 (고객, 관리자, 파트너)
2. `accommodations` - 숙소 마스터 데이터
3. `activities` - 레저 활동 마스터 데이터
4. `bookings` - 예약 정보
5. `booking_activities` - 예약별 활동 배정
6. `payments` - 결제 정보
7. `settlements` - 정산 정보

## 🛠️ 기술 스펙

- **Backend**: Node.js + Express
- **Database**: PostgreSQL
- **API**: RESTful
- **Deployment**: Render

## 📡 API 엔드포인트

### 견적 계산
```
POST /api/quotes/calculate
GET /api/quotes/packages
```

### 예약 관리
```
POST /api/bookings/create
GET /api/bookings/:bookingId
PUT /api/bookings/:bookingId/status
GET /api/bookings
```

## 🚀 시작하기

### 1. 의존성 설치
```bash
npm install
```

### 2. 환경 변수 설정
`.env` 파일에 다음 설정:
```
DATABASE_URL=postgresql://...
PORT=8081
NODE_ENV=development
```

### 3. 데이터베이스 마이그레이션
```bash
psql $DATABASE_URL -f database/migrations/001_create_tables.sql
psql $DATABASE_URL -f database/seeds/001_master_data.sql
```

### 4. 서버 실행
```bash
npm start          # 프로덕션
npm run dev        # 개발 모드
```

## 📊 진행 상황

### ✅ Day 1-2 완료
- [x] 프로젝트 구조 생성
- [x] 데이터베이스 스키마 (7개 테이블)
- [x] 마스터 데이터 (숙소 4개, 활동 9개)
- [x] 견적 계산 API
- [x] 예약 관리 API

### ⏳ 다음 단계 (Day 3-4)
- [ ] 프론트엔드 기본 구조
- [ ] 홈 + 패키지 선택 페이지
- [ ] 결제 연동 (토스/카카오페이)

## 👥 팀

- **CEO**: 푸르미르
- **AI Manager**: 코미
- **Developer**: Claude Code

## 📄 라이선스

ISC

---

**Version**: 1.0.0
**Status**: Day 1-2 완료
**Next**: 프론트엔드 개발 시작
