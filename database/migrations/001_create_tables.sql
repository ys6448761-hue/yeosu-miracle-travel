-- ═══════════════════════════════════════════════════════════
-- 여수 기적여행 예약·배정·정산 시스템 - Database Migration
-- Phase 1: 테이블 생성
-- PostgreSQL 14+
-- ═══════════════════════════════════════════════════════════

-- UUID 확장 활성화
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════
-- 1. 사용자 (Users)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE users (
  user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  phone VARCHAR(20) NOT NULL,
  password_hash VARCHAR(255),
  role VARCHAR(20) DEFAULT 'customer' CHECK (role IN ('customer', 'admin', 'partner')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

COMMENT ON TABLE users IS '사용자 테이블 (고객, 관리자, 파트너)';

-- ═══════════════════════════════════════════════════════════
-- 2. 숙소 (Accommodations) - 마스터 데이터
-- ═══════════════════════════════════════════════════════════

CREATE TABLE accommodations (
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

CREATE INDEX idx_accommodations_active ON accommodations(is_active);

COMMENT ON TABLE accommodations IS '숙소 마스터 데이터';

-- ═══════════════════════════════════════════════════════════
-- 3. 활동 (Activities) - 마스터 데이터
-- ═══════════════════════════════════════════════════════════

CREATE TABLE activities (
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

CREATE INDEX idx_activities_category ON activities(category);
CREATE INDEX idx_activities_active ON activities(is_active);

COMMENT ON TABLE activities IS '레저 활동 마스터 데이터';

-- ═══════════════════════════════════════════════════════════
-- 4. 예약 (Bookings)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE bookings (
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

CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_check_in_date ON bookings(check_in_date);

COMMENT ON TABLE bookings IS '예약 정보 테이블';

-- ═══════════════════════════════════════════════════════════
-- 5. 예약 활동 (Booking_Activities)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE booking_activities (
  activity_booking_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
  activity_id VARCHAR(50) NOT NULL REFERENCES activities(activity_id),
  activity_date DATE NOT NULL,
  guide_assigned VARCHAR(100),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_booking_activities_booking_id ON booking_activities(booking_id);
CREATE INDEX idx_booking_activities_status ON booking_activities(status);

COMMENT ON TABLE booking_activities IS '예약별 레저 활동 배정';

-- ═══════════════════════════════════════════════════════════
-- 6. 결제 (Payments)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE payments (
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

CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);

COMMENT ON TABLE payments IS '결제 정보 테이블';

-- ═══════════════════════════════════════════════════════════
-- 7. 정산 (Settlements)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE settlements (
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

CREATE INDEX idx_settlements_partner_type ON settlements(partner_type);
CREATE INDEX idx_settlements_status ON settlements(status);
CREATE INDEX idx_settlements_booking_id ON settlements(booking_id);

COMMENT ON TABLE settlements IS '정산 정보 테이블';

-- ═══════════════════════════════════════════════════════════
-- 트리거: updated_at 자동 업데이트
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $func$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$func$ language 'plpgsql';

-- 트리거 적용
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accommodations_updated_at BEFORE UPDATE ON accommodations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_activities_updated_at BEFORE UPDATE ON activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_booking_activities_updated_at BEFORE UPDATE ON booking_activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settlements_updated_at BEFORE UPDATE ON settlements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
