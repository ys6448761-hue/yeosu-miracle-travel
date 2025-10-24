// 숙소 API
const express = require('express');
const router = express.Router();
const db = require('../../database/db');

// 숙소 목록 조회
router.get('/', async (req, res) => {
    try {
        const result = await db.query(`
            SELECT id, name, type, description, price_per_night, max_guests, amenities, image_url
            FROM accommodations
            WHERE is_active = true
            ORDER BY price_per_night ASC
        `);

        res.json({
            success: true,
            count: result.rows.length,
            accommodations: result.rows
        });
    } catch (error) {
        console.error('숙소 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: 'accommodations_fetch_failed',
            message: '숙소 목록을 불러오는데 실패했습니다'
        });
    }
});

// 특정 숙소 조회
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await db.query(`
            SELECT id, name, type, description, price_per_night, max_guests, amenities, image_url, created_at
            FROM accommodations
            WHERE id = $1 AND is_active = true
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'accommodation_not_found',
                message: '숙소를 찾을 수 없습니다'
            });
        }

        res.json({
            success: true,
            accommodation: result.rows[0]
        });
    } catch (error) {
        console.error('숙소 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: 'accommodation_fetch_failed',
            message: '숙소 정보를 불러오는데 실패했습니다'
        });
    }
});

module.exports = router;
