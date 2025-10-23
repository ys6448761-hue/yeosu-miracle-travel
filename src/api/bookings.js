// 여수 기적여행 - 예약 관리 API
const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

// PostgreSQL 연결
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// POST /api/bookings/create - 예약 생성
router.post('/create', async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const {
      userId,
      packageId,
      accommodationId,
      activityIds = [],
      checkInDate,
      checkOutDate,
      numPeople,
      basePrice,
      discountAmount = 0,
      additionalCost = 0,
      totalPrice
    } = req.body;

    // 입력값 검증
    if (!userId || !packageId || !accommodationId || !checkInDate || !checkOutDate || !totalPrice) {
      return res.status(400).json({
        success: false,
        error: 'invalid_input',
        message: '필수 필드가 누락되었습니다'
      });
    }

    // 1. 예약 생성
    const bookingResult = await client.query(
      `INSERT INTO bookings (
        user_id, package_id, accommodation_id,
        check_in_date, check_out_date, num_people,
        base_price, discount_amount, additional_cost, total_price,
        status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *`,
      [
        userId,
        packageId,
        accommodationId,
        checkInDate,
        checkOutDate,
        numPeople,
        basePrice,
        discountAmount,
        additionalCost,
        totalPrice,
        'pending'
      ]
    );

    const booking = bookingResult.rows[0];

    // 2. 레저 활동 배정
    const activityBookings = [];
    if (activityIds.length > 0) {
      for (const activityId of activityIds) {
        const activityResult = await client.query(
          `INSERT INTO booking_activities (
            booking_id, activity_id, activity_date, status
          ) VALUES ($1, $2, $3, $4)
          RETURNING *`,
          [booking.booking_id, activityId, checkInDate, 'pending']
        );
        activityBookings.push(activityResult.rows[0]);
      }
    }

    // 3. 결제 레코드 생성
    await client.query(
      `INSERT INTO payments (
        booking_id, amount, status
      ) VALUES ($1, $2, $3)`,
      [booking.booking_id, totalPrice, 'pending']
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      booking: {
        bookingId: booking.booking_id,
        status: booking.status,
        packageId: booking.package_id,
        accommodationId: booking.accommodation_id,
        checkInDate: booking.check_in_date,
        checkOutDate: booking.check_out_date,
        numPeople: booking.num_people,
        totalPrice: parseFloat(booking.total_price),
        activities: activityBookings.map(ab => ({
          activityId: ab.activity_id,
          activityDate: ab.activity_date
        })),
        createdAt: booking.created_at
      },
      message: '예약이 성공적으로 생성되었습니다'
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('예약 생성 오류:', error);
    res.status(500).json({
      success: false,
      error: 'server_error',
      message: error.message
    });
  } finally {
    client.release();
  }
});

// GET /api/bookings/:bookingId - 예약 조회
router.get('/:bookingId', async (req, res) => {
  const client = await pool.connect();

  try {
    const { bookingId } = req.params;

    // 예약 정보 조회
    const bookingResult = await client.query(
      'SELECT * FROM bookings WHERE booking_id = $1',
      [bookingId]
    );

    if (bookingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'booking_not_found',
        message: '예약을 찾을 수 없습니다'
      });
    }

    const booking = bookingResult.rows[0];

    // 예약 활동 조회
    const activitiesResult = await client.query(
      'SELECT * FROM booking_activities WHERE booking_id = $1',
      [bookingId]
    );

    // 결제 정보 조회
    const paymentResult = await client.query(
      'SELECT * FROM payments WHERE booking_id = $1',
      [bookingId]
    );

    return res.json({
      success: true,
      booking: {
        bookingId: booking.booking_id,
        userId: booking.user_id,
        packageId: booking.package_id,
        accommodationId: booking.accommodation_id,
        checkInDate: booking.check_in_date,
        checkOutDate: booking.check_out_date,
        numPeople: booking.num_people,
        basePrice: parseFloat(booking.base_price),
        discountAmount: parseFloat(booking.discount_amount),
        additionalCost: parseFloat(booking.additional_cost),
        totalPrice: parseFloat(booking.total_price),
        status: booking.status,
        activities: activitiesResult.rows,
        payment: paymentResult.rows[0] || null,
        createdAt: booking.created_at
      }
    });

  } catch (error) {
    console.error('예약 조회 오류:', error);
    res.status(500).json({
      success: false,
      error: 'server_error',
      message: error.message
    });
  } finally {
    client.release();
  }
});

// PUT /api/bookings/:bookingId/status - 예약 상태 변경
router.put('/:bookingId/status', async (req, res) => {
  const client = await pool.connect();

  try {
    const { bookingId } = req.params;
    const { status } = req.body;

    const validStatuses = ['pending', 'confirmed', 'completed', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        error: 'invalid_status',
        message: '유효하지 않은 상태입니다'
      });
    }

    const result = await client.query(
      'UPDATE bookings SET status = $1 WHERE booking_id = $2 RETURNING *',
      [status, bookingId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'booking_not_found',
        message: '예약을 찾을 수 없습니다'
      });
    }

    return res.json({
      success: true,
      booking: result.rows[0],
      message: '예약 상태가 변경되었습니다'
    });

  } catch (error) {
    console.error('예약 상태 변경 오류:', error);
    res.status(500).json({
      success: false,
      error: 'server_error',
      message: error.message
    });
  } finally {
    client.release();
  }
});

// GET /api/bookings - 예약 목록 조회 (관리자용)
router.get('/', async (req, res) => {
  const client = await pool.connect();

  try {
    const { status, limit = 50, offset = 0 } = req.query;

    let query = 'SELECT * FROM bookings';
    const params = [];

    if (status) {
      query += ' WHERE status = $1';
      params.push(status);
    }

    query += ' ORDER BY created_at DESC LIMIT $' + (params.length + 1) + ' OFFSET $' + (params.length + 2);
    params.push(limit, offset);

    const result = await client.query(query, params);

    return res.json({
      success: true,
      bookings: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('예약 목록 조회 오류:', error);
    res.status(500).json({
      success: false,
      error: 'server_error',
      message: error.message
    });
  } finally {
    client.release();
  }
});

module.exports = router;
