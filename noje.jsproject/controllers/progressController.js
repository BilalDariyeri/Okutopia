// controllers/progressController.js - İlerleme Takibi Controller'ı

const Progress = require('../models/Progress');
const User = require('../models/user');
const Activity = require('../models/activity');

// ---------------------------------------------------------------------
// 1. Öğrenci İlerlemesini Getirme
// GET /api/progress/student/:studentId
// ---------------------------------------------------------------------
exports.getStudentProgress = async (req, res) => {
    const { studentId } = req.params;

    try {
        // Öğrenciyi kontrol et
        const student = await User.findById(studentId).select('firstName lastName role').lean();
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Öğrenci bulunamadı.'
            });
        }

        if (student.role !== 'Student') {
            return res.status(400).json({
                success: false,
                message: 'Bu kullanıcı bir öğrenci değil.'
            });
        }

        // İlerlemeyi çek ve aktiviteleri populate et
        const progress = await Progress.findOne({ student: studentId })
            .populate('classroom', 'name teacher')
            .populate({
                path: 'activityRecords.activityId',
                select: 'title type lesson',
                populate: {
                    path: 'lesson',
                    select: 'title group targetContent',
                    populate: {
                        path: 'group',
                        select: 'name category orderIndex'
                    }
                }
            })
            .lean();

        if (!progress) {
            return res.status(200).json({
                success: true,
                student: {
                    id: student._id,
                    firstName: student.firstName,
                    lastName: student.lastName
                },
                progress: {
                    overallScore: 0,
                    completedActivities: 0,
                    activityRecords: []
                },
                message: 'Henüz ilerleme kaydı yok.'
            });
        }

        // İstatistikleri hesapla
        const completedCount = progress.activityRecords?.length || 0;
        const averageScore = completedCount > 0
            ? progress.activityRecords.reduce((sum, record) => sum + (record.finalScore || 0), 0) / completedCount
            : 0;

        res.status(200).json({
            success: true,
            student: {
                id: student._id,
                firstName: student.firstName,
                lastName: student.lastName
            },
            classroom: progress.classroom,
            progress: {
                overallScore: progress.overallScore || 0,
                completedActivities: completedCount,
                averageScore: Math.round(averageScore * 100) / 100,
                activityRecords: progress.activityRecords || []
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'İlerleme bilgisi yüklenemedi.',
            error: error.message
        });
    }
};

// ---------------------------------------------------------------------
// 2. Sınıf İlerleme Özeti
// GET /api/progress/classroom/:classId/summary
// ---------------------------------------------------------------------
exports.getClassroomProgressSummary = async (req, res) => {
    const { classId } = req.params;
    const Classroom = require('../models/classroom');

    try {
        // Sınıfı bul
        const classroom = await Classroom.findById(classId)
            .populate('teacher', 'firstName lastName')
            .populate('students', 'firstName lastName')
            .lean();

        if (!classroom) {
            return res.status(404).json({
                success: false,
                message: 'Sınıf bulunamadı.'
            });
        }

        // Tüm öğrencilerin ilerlemelerini çek
        const studentsProgress = await Progress.find({ classroom: classId })
            .populate('student', 'firstName lastName')
            .lean();

        // İstatistikleri hesapla
        const totalStudents = classroom.students?.length || 0;
        const studentsWithProgress = studentsProgress.length;
        const totalCompletedActivities = studentsProgress.reduce((sum, p) => {
            return sum + (p.activityRecords?.length || 0);
        }, 0);
        const averageOverallScore = studentsWithProgress > 0
            ? studentsProgress.reduce((sum, p) => sum + (p.overallScore || 0), 0) / studentsWithProgress
            : 0;

        // Öğrenci bazlı özet
        const studentsSummary = (classroom.students || []).map(student => {
            const studentProgress = studentsProgress.find(p => 
                p.student && p.student._id.toString() === student._id.toString()
            );

            return {
                id: student._id,
                firstName: student.firstName,
                lastName: student.lastName,
                progress: studentProgress ? {
                    overallScore: studentProgress.overallScore || 0,
                    completedActivities: studentProgress.activityRecords?.length || 0
                } : {
                    overallScore: 0,
                    completedActivities: 0
                }
            };
        });

        res.status(200).json({
            success: true,
            classroom: {
                id: classroom._id,
                name: classroom.name,
                teacher: classroom.teacher
            },
            summary: {
                totalStudents,
                studentsWithProgress,
                totalCompletedActivities,
                averageOverallScore: Math.round(averageOverallScore * 100) / 100
            },
            students: studentsSummary
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'İlerleme özeti yüklenemedi.',
            error: error.message
        });
    }
};

