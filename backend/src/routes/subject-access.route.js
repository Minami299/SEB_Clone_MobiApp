const express = require('express');
const router = express.Router();
const controller = require('../controllers/subject-access.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.get('/subjects', authenticate, controller.getAllSubjects);
router.post('/request', authenticate, authorize('LECTURER'), controller.requestAccess);
router.get('/my-requests', authenticate, authorize('LECTURER'), controller.getMyRequests);
router.get('/pending', authenticate, authorize('HEAD_OF_SUBJECT', 'ADMIN'), controller.getPendingRequests);
router.patch('/:id/review', authenticate, authorize('HEAD_OF_SUBJECT', 'ADMIN'), controller.reviewRequest);

module.exports = router;

