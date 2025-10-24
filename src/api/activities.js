// 활동 API
const express = require('express');
const router = express.Router();
const db = require('../../database/db');

// 활동 목록 조회
router.get('/', async (req, res) => {
    try {
        const { category } = req.query;

        let query = `
            SELECT id, name, category, description, price, duration_minutes, max_participants, location, image_url
            FROM activities
            WHERE is_active = true
        `;

        const params = [];

        if (category) {
            query += ` AND category = $1`;
            params.push(category);
        }

        query += ` ORDER BY category, price ASC`;

        const result = await db.query(query, params);

        res.json({
            success: true,
            count: result.rows.length,
            activities: result.rows
        });
    } catch (error) {
        console.error('활동 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: 'activities_fetch_failed',
            message: '활동 목록을 불러오는데 실패했습니다'
        });
    }
});

// 특정 활동 조회
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await db.query(`
            SELECT id, name, category, description, price, duration_minutes, max_participants, location, image_url, created_at
            FROM activities
            WHERE id = $1 AND is_active = true
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'activity_not_found',
                message: '활동을 찾을 수 없습니다'
            });
        }

        res.json({
            success: true,
            activity: result.rows[0]
        });
    } catch (error) {
        console.error('활동 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: 'activity_fetch_failed',
            message: '활동 정보를 불러오는데 실패했습니다'
        });
    }
});

// 카테고리 목록 조회
router.get('/categories/list', async (req, res) => {
    try {
        const result = await db.query(`
            SELECT DISTINCT category
            FROM activities
            WHERE is_active = true
            ORDER BY category
        `);

        res.json({
            success: true,
            categories: result.rows.map(row => row.category)
        });
    } catch (error) {
        console.error('카테고리 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: 'categories_fetch_failed',
            message: '카테고리 목록을 불러오는데 실패했습니다'
        });
    }
});

module.exports = router;
