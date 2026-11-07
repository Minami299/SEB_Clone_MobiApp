const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

// Public
router.post('/login', authController.login);

// Authenticated
router.get('/me', authenticate, authController.getMe);

// Admin User Management & Role Assignment
router.get('/users', authenticate, authorize('ADMIN'), authController.getAllUsers);
router.get('/users/:id', authenticate, authorize('ADMIN'), authController.getUserById);
router.post('/users', authenticate, authorize('ADMIN'), authController.createUser);
router.put('/users/:id', authenticate, authorize('ADMIN'), authController.updateUser);
router.patch('/users/:id/role', authenticate, authorize('ADMIN'), authController.updateUserRole);
router.delete('/users/:id', authenticate, authorize('ADMIN'), authController.deleteUser);

module.exports = router;

