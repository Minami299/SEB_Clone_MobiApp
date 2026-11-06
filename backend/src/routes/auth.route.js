const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.post('/login', authController.login);
router.get('/me', authenticate, authController.getMe);
router.post('/users', authenticate, authorize('ADMIN'), authController.createUser);

module.exports = router;

