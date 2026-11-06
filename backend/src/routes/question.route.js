const express = require('express');
const router = express.Router();
const controller = require('../controllers/question.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.post('/', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.createQuestion);
router.get('/subject/:subject_id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getQuestionsBySubject);
router.get('/:id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getQuestionDetail);

module.exports = router;

