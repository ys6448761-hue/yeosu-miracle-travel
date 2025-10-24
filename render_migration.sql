-- ═══════════════════════════════════════════════════════════
-- 여수 기적여행 Render PostgreSQL 마이그레이션
-- 전체 테이블 생성 + 마스터 데이터 삽입
-- ═══════════════════════════════════════════════════════════

-- UUID 확장 활성화
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════
-- 1. 사용자 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
  user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  phone VARCHAR(20) NOT NULL,
  password_hash VARCHAR(255),
  role VARCHAR(20) DEFAULT 'customer' CHECK (role IN ('customer', 'admin', 'partner')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ═══════════════════════════════════════════════════════════
-- 2. 숙소 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS accommodations (
  accommodation_id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  location VARCHAR(200),
  rating DECIMAL(2, 1) CHECK (rating >= 0 AND rating <= 5),
  rooms INT CHECK (rooms > 0),
  price_per_night DECIMAL(10, 2) NOT NULL CHECK (price_per_night >= 0),
  features TEXT,
  capacity INT DEFAULT 2,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accommodations_active ON accommodations(is_active);

-- ═══════════════════════════════════════════════════════════
-- 3. 활동 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS activities (
  activity_id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category VARCHAR(50) NOT NULL,
  duration VARCHAR(50),
  price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
  capacity INT CHECK (capacity > 0),
  rating DECIMAL(2, 1) CHECK (rating >= 0 AND rating <= 5),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_category ON activities(category);
CREATE INDEX IF NOT EXISTS idx_activities_active ON activities(is_active);

-- ═══════════════════════════════════════════════════════════
-- 4. 예약 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bookings (
  booking_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  package_id VARCHAR(50) NOT NULL,
  accommodation_id VARCHAR(50) NOT NULL REFERENCES accommodations(accommodation_id),
  check_in_date DATE NOT NULL,
  check_out_date DATE NOT NULL,
  num_people INT NOT NULL CHECK (num_people > 0),
  base_price DECIMAL(10, 2) NOT NULL,
  discount_amount DECIMAL(10, 2) DEFAULT 0,
  additional_cost DECIMAL(10, 2) DEFAULT 0,
  total_price DECIMAL(10, 2) NOT NULL CHECK (total_price >= 0),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT check_dates CHECK (check_out_date >= check_in_date)
);

CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_check_in_date ON bookings(check_in_date);

-- ═══════════════════════════════════════════════════════════
-- 5. 예약 활동 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS booking_activities (
  activity_booking_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
  activity_id VARCHAR(50) NOT NULL REFERENCES activities(activity_id),
  activity_date DATE NOT NULL,
  guide_assigned VARCHAR(100),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_booking_activities_booking_id ON booking_activities(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_activities_status ON booking_activities(status);

-- ═══════════════════════════════════════════════════════════
-- 6. 결제 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS payments (
  payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
  amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_method VARCHAR(50),
  transaction_id VARCHAR(100) UNIQUE,
  paid_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON payments(transaction_id);

-- ═══════════════════════════════════════════════════════════
-- 7. 정산 테이블
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS settlements (
  settlement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_type VARCHAR(50) NOT NULL CHECK (partner_type IN ('accommodation', 'activity', 'guide', 'other')),
  partner_name VARCHAR(100) NOT NULL,
  booking_id UUID NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
  amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
  komi_commission DECIMAL(10, 2) DEFAULT 0,
  net_amount DECIMAL(10, 2) NOT NULL CHECK (net_amount >= 0),
  settlement_date DATE,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'paid')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settlements_partner_type ON settlements(partner_type);
CREATE INDEX IF NOT EXISTS idx_settlements_status ON settlements(status);
CREATE INDEX IF NOT EXISTS idx_settlements_booking_id ON settlements(booking_id);

-- ═══════════════════════════════════════════════════════════
-- 트리거 함수
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 트리거 적용
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_accommodations_updated_at ON accommodations;
CREATE TRIGGER update_accommodations_updated_at BEFORE UPDATE ON accommodations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_activities_updated_at ON activities;
CREATE TRIGGER update_activities_updated_at BEFORE UPDATE ON activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_bookings_updated_at ON bookings;
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_booking_activities_updated_at ON booking_activities;
CREATE TRIGGER update_booking_activities_updated_at BEFORE UPDATE ON booking_activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_payments_updated_at ON payments;
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_settlements_updated_at ON settlements;
CREATE TRIGGER update_settlements_updated_at BEFORE UPDATE ON settlements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ═══════════════════════════════════════════════════════════
-- 마스터 데이터 삽입
-- ═══════════════════════════════════════════════════════════

-- 숙소 데이터
INSERT INTO accommodations (accommodation_id, name, location, rating, rooms, price_per_night, features, capacity) VALUES
('acc_premium', '여수 프리미엄 리조트', '여수시 종로동', 4.8, 50, 150000, '수영장, 스파, 해양 뷰, 컨시어지', 2),
('acc_comfort', '코지 게스트하우스', '여수시 쌍봉동', 4.6, 30, 80000, '공용 주방, 루프탑, 카페', 2),
('acc_deluxe', '해양 럭셔리 스위트', '여수시 해변로', 4.9, 20, 250000, '프라이빗 풀, 부티크, 셰프 서비스', 2),
('acc_standard', '여수 스테이 호텔', '여수시 중앙로', 4.4, 80, 120000, '피트니스, 비즈니스 센터', 2)
ON CONFLICT (accommodation_id) DO NOTHING;

-- 활동 데이터
INSERT INTO activities (activity_id, name, category, duration, price, capacity, rating) VALUES
('act_sunset_cruise', '해양 일몰 크루즈', '해양 스포츠', '2시간', 89000, 50, 4.9),
('act_diving', '스쿠버 다이빙', '해양 스포츠', '3시간', 120000, 20, 4.7),
('act_surfing', '서핑 레슨', '해양 스포츠', '2시간', 75000, 15, 4.6),
('act_trekking', '여수 케이블카 + 트레킹', '자연 탐방', '3시간', 45000, 100, 4.8),
('act_temple', '해상 사찰 투어', '문화', '2.5시간', 55000, 40, 4.7),
('act_pottery', '도자기 공예 체험', '체험', '2시간', 65000, 12, 4.8),
('act_cooking', '여수 해산물 요리 클래스', '식문화', '2.5시간', 95000, 20, 4.9),
('act_night_market', '여수 야시장 투어 + 저녁', '식문화', '2시간', 45000, 100, 4.7),
('act_island_hop', '다도해 아일랜드 호핑', '해양 스포츠', '4시간', 135000, 30, 4.8)
ON CONFLICT (activity_id) DO NOTHING;

-- 관리자 계정
INSERT INTO users (name, email, phone, password_hash, role) VALUES
('관리자', 'admin@yeosu-miracle.com', '010-0000-0000', '$2a$10$abcdefghijklmnopqrstuvwxyz', 'admin')
ON CONFLICT (email) DO NOTHING;

-- ═══════════════════════════════════════════════════════════
-- 완료 확인
-- ═══════════════════════════════════════════════════════════

SELECT 'Migration Complete!' AS status;
SELECT '테이블 생성: 7개' AS info;
SELECT 'Accommodations:', COUNT(*) AS count FROM accommodations;
SELECT 'Activities:', COUNT(*) AS count FROM activities;
SELECT 'Users:', COUNT(*) AS count FROM users;
