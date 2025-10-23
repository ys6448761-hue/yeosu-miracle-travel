// 여수 기적여행 - Express 앱 설정
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const quoteRoutes = require('./api/quotes');
const bookingRoutes = require('./api/bookings');

const app = express();

// 미들웨어
app.use(express.json());
app.use(cors());

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: '여수 기적여행 API 서버가 정상 작동 중입니다',
    timestamp: new Date().toISOString(),
    database: process.env.DATABASE_URL ? '연결됨' : '미설정'
  });
});

// API 라우트
app.use('/api/quotes', quoteRoutes);
app.use('/api/bookings', bookingRoutes);

// 404 처리
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'route_not_found',
    message: '요청하신 API 경로를 찾을 수 없습니다'
  });
});

// 에러 핸들러
app.use((err, req, res, next) => {
  console.error('서버 오류:', err);
  res.status(500).json({
    success: false,
    error: 'server_error',
    message: err.message || '서버 내부 오류가 발생했습니다'
  });
});

module.exports = app;
