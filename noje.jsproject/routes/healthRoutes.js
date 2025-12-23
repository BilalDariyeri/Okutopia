// routes/healthRoutes.js - Health Check Endpoints

const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');

/**
 * @swagger
 * /api/health:
 *   get:
 *     summary: API Sağlık Kontrolü
 *     tags: [Health]
 *     description: API'nin çalışıp çalışmadığını kontrol eder
 *     responses:
 *       '200':
 *         description: API çalışıyor
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: ok
 *                 timestamp:
 *                   type: string
 *                 uptime:
 *                   type: number
 *                 environment:
 *                   type: string
 */
router.get('/', (req, res) => {
    res.status(200).json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development'
    });
});

/**
 * @swagger
 * /api/health/detailed:
 *   get:
 *     summary: Detaylı Sağlık Kontrolü
 *     tags: [Health]
 *     description: API, veritabanı ve sistem durumunu kontrol eder
 *     responses:
 *       '200':
 *         description: Sistem sağlıklı
 *       '503':
 *         description: Sistem sorunlu
 */
router.get('/detailed', async (req, res) => {
    const healthCheck = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        checks: {
            database: {
                status: 'unknown',
                responseTime: null
            },
            memory: {
                used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
                total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
                percentage: Math.round((process.memoryUsage().heapUsed / process.memoryUsage().heapTotal) * 100)
            }
        }
    };

    // Veritabanı bağlantı kontrolü
    const dbStartTime = Date.now();
    try {
        const dbState = mongoose.connection.readyState;
        const dbResponseTime = Date.now() - dbStartTime;

        if (dbState === 1) { // 1 = connected
            healthCheck.checks.database = {
                status: 'connected',
                responseTime: `${dbResponseTime}ms`,
                host: mongoose.connection.host,
                database: mongoose.connection.name
            };
        } else {
            healthCheck.checks.database = {
                status: 'disconnected',
                state: dbState
            };
            healthCheck.status = 'degraded';
        }
    } catch (error) {
        healthCheck.checks.database = {
            status: 'error',
            error: error.message
        };
        healthCheck.status = 'error';
    }

    // Status code belirleme
    const statusCode = healthCheck.status === 'ok' ? 200 : 503;

    res.status(statusCode).json(healthCheck);
});

module.exports = router;

