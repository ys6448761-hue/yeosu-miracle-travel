// 여수 기적여행 - 견적 계산 API
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

// PostgreSQL 연결
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// 패키지 정의 (마스터 데이터)
const PACKAGES = {
  'pkg_1night': {
    id: 'pkg_1night',
    name: '소원 1박 패키지',
    nights: 1,
    basePrice: 249900,
    included: [
      '개인화 여행 기획',
      '숙소 + 조식',
      '1가지 레저 (선택)',
      '저녁 식사'
    ]
  },
  'pkg_2night': {
    id: 'pkg_2night',
    name: '소원 2박 패키지',
    nights: 2,
    basePrice: 449900,
    included: [
      '개인화 여행 기획',
      '숙소 + 조식 2일',
      '2가지 레저 (선택)',
      '중식 1회, 저녁 식사 2회'
    ]
  },
  'pkg_3night': {
    id: 'pkg_3night',
    name: '소원 3박 패키지',
    nights: 3,
    basePrice: 649900,
    included: [
      '개인화 여행 기획',
      '숙소 + 조식 3일',
      '3가지 레저 (선택)',
      '전 식사 포함'
    ]
  }
};

// POST /api/quotes/calculate - 견적 자동 생성
router.post('/calculate', async (req, res) => {
  const client = await pool.connect();

  try {
    const {
      packageId,
      accommodationId,
      activityIds = [],
      numPeople = 1,
      options = {}
    } = req.body;

    // 1. 패키지 확인
    const package = PACKAGES[packageId];
    if (!package) {
      return res.status(400).json({
        success: false,
        error: 'invalid_package',
        message: '유효하지 않은 패키지 ID입니다'
      });
    }

    // 2. 숙소 정보 조회
    const accommodationResult = await client.query(
      'SELECT * FROM accommodations WHERE accommodation_id = $1 AND is_active = true',
      [accommodationId]
    );

    if (accommodationResult.rows.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'accommodation_not_found',
        message: '숙소를 찾을 수 없습니다'
      });
    }

    const accommodation = accommodationResult.rows[0];

    // 3. 레저 활동 정보 조회
    let activities = [];
    let activitiesTotal = 0;

    if (activityIds.length > 0) {
      const activitiesResult = await client.query(
        'SELECT * FROM activities WHERE activity_id = ANY($1) AND is_active = true',
        [activityIds]
      );

      activities = activitiesResult.rows;
      activitiesTotal = activities.reduce((sum, act) => sum + parseFloat(act.price), 0);
    }

    // 4. 가격 계산
    const basePrice = package.basePrice;
    const accommodationCost = accommodation.price_per_night * package.nights * numPeople;
    const activitiesCost = activitiesTotal * numPeople;

    // 추가 옵션
    const pickupCost = options.pickup ? 30000 : 0;
    const guideCost = options.guide ? 50000 : 0;
    const insuranceCost = options.insurance ? 20000 * numPeople : 0;

    const subtotal = basePrice + accommodationCost + activitiesCost + pickupCost + guideCost + insuranceCost;

    // 할인 적용
    let discountRate = 0;
    let discountReason = '';

    if (options.earlyBooking) {
      discountRate = 0.10; // 10% 조기 예약 할인
      discountReason = '조기 예약 할인';
    }

    if (numPeople >= 4) {
      discountRate = Math.max(discountRate, 0.15); // 15% 단체 할인
      discountReason = '단체 할인 (4인 이상)';
    }

    const discountAmount = Math.floor(subtotal * discountRate);
    const totalPrice = subtotal - discountAmount;

    // 5. 견적 응답
    return res.status(200).json({
      success: true,
      quote: {
        package: {
          id: package.id,
          name: package.name,
          nights: package.nights,
          basePrice: basePrice,
          included: package.included
        },
        accommodation: {
          id: accommodation.accommodation_id,
          name: accommodation.name,
          pricePerNight: parseFloat(accommodation.price_per_night),
          nights: package.nights,
          total: accommodationCost
        },
        activities: activities.map(act => ({
          id: act.activity_id,
          name: act.name,
          price: parseFloat(act.price)
        })),
        options: {
          pickup: options.pickup ? { included: true, cost: pickupCost } : { included: false },
          guide: options.guide ? { included: true, cost: guideCost } : { included: false },
          insurance: options.insurance ? { included: true, cost: insuranceCost } : { included: false }
        },
        pricing: {
          basePrice: basePrice,
          accommodationCost: accommodationCost,
          activitiesCost: activitiesCost,
          additionalCost: pickupCost + guideCost + insuranceCost,
          subtotal: subtotal,
          discountRate: discountRate,
          discountReason: discountReason,
          discountAmount: discountAmount,
          totalPrice: totalPrice
        },
        numPeople: numPeople
      },
      message: '견적이 성공적으로 생성되었습니다'
    });

  } catch (error) {
    console.error('견적 계산 오류:', error);
    res.status(500).json({
      success: false,
      error: 'server_error',
      message: error.message
    });
  } finally {
    client.release();
  }
});

// GET /api/quotes/packages - 패키지 목록 조회
router.get('/packages', (req, res) => {
  const packagesList = Object.values(PACKAGES);
  res.json({
    success: true,
    packages: packagesList
  });
});

module.exports = router;
