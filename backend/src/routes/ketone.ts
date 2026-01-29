import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getDb } from '../services/database.js';
import { isInKetosis } from '../services/dietCompliance.js';
import { authMiddleware } from '../middleware/auth.js';

interface KetoneLogBody {
  ketoneLevel: number;
  measurementType?: string;
  notes?: string;
}

export default async function ketoneRoutes(fastify: FastifyInstance) {
  const db = getDb();

  // Log a ketone measurement
  fastify.post<{ Body: KetoneLogBody }>('/api/ketone', { preHandler: authMiddleware }, async (
    request,
    reply
  ) => {
    const userId = request.user!.userId;

    const { ketoneLevel, measurementType = 'blood', notes } = request.body;

    if (ketoneLevel === undefined || ketoneLevel < 0) {
      return reply.status(400).send({ error: 'Valid ketone level required' });
    }

    // Validate ketone level range (0-10 mmol/L is reasonable)
    if (ketoneLevel > 10) {
      return reply.status(400).send({ error: 'Ketone level seems too high. Please verify.' });
    }

    const log = await db.createKetoneLog({
      userId,
      ketoneLevel,
      measurementType,
      notes: notes || null,
      timestamp: new Date()
    });

    // Calculate ketosis status
    const ketosisStatus = isInKetosis(ketoneLevel);

    return {
      log,
      ketosisStatus
    };
  });

  // Get recent ketone logs (last 30 days by default)
  fastify.get<{ Querystring: { limit?: string } }>('/api/ketone/recent', { preHandler: authMiddleware }, async (
    request,
    reply
  ) => {
    const userId = request.user!.userId;

    const limit = parseInt(request.query.limit || '30', 10);
    const logs = await db.findKetoneLogsByUser(userId, Math.min(limit, 100));

    // Calculate stats
    const stats = calculateKetoneStats(logs);

    return {
      logs,
      stats
    };
  });

  // Get the latest ketone reading
  fastify.get('/api/ketone/latest', { preHandler: authMiddleware }, async (request: FastifyRequest, reply: FastifyReply) => {
    const userId = request.user!.userId;

    const log = await db.findRecentKetoneLog(userId);

    if (!log) {
      return { log: null, ketosisStatus: null };
    }

    const ketosisStatus = isInKetosis(log.ketoneLevel);

    return {
      log,
      ketosisStatus
    };
  });

  // Delete a ketone log
  fastify.delete<{ Params: { id: string } }>('/api/ketone/:id', { preHandler: authMiddleware }, async (
    request,
    reply
  ) => {
    const userId = request.user!.userId;

    const { id } = request.params;

    try {
      await db.deleteKetoneLog(id);
      return { success: true };
    } catch (error) {
      return reply.status(404).send({ error: 'Log not found' });
    }
  });
}

// Helper function to calculate ketone statistics
function calculateKetoneStats(logs: Array<{ ketoneLevel: number; timestamp: Date }>) {
  if (logs.length === 0) {
    return {
      avgLevel: 0,
      minLevel: 0,
      maxLevel: 0,
      daysInKetosis: 0,
      totalDays: 0,
      ketosisRate: 0,
      trend: 'none' as const
    };
  }

  const levels = logs.map(l => l.ketoneLevel);
  const avgLevel = levels.reduce((a, b) => a + b, 0) / levels.length;
  const minLevel = Math.min(...levels);
  const maxLevel = Math.max(...levels);

  // Count unique days with readings in ketosis (>= 0.5 mmol/L)
  const daysMap = new Map<string, boolean>();
  for (const log of logs) {
    const dateStr = log.timestamp.toISOString().split('T')[0];
    const inKetosis = log.ketoneLevel >= 0.5;
    if (!daysMap.has(dateStr) || inKetosis) {
      daysMap.set(dateStr, inKetosis);
    }
  }

  const totalDays = daysMap.size;
  const daysInKetosis = Array.from(daysMap.values()).filter(v => v).length;
  const ketosisRate = totalDays > 0 ? daysInKetosis / totalDays : 0;

  // Calculate trend (compare recent vs older readings)
  let trend: 'improving' | 'declining' | 'stable' | 'none' = 'none';
  if (logs.length >= 6) {
    const recent = logs.slice(0, 3);
    const older = logs.slice(3, 6);
    const recentAvg = recent.reduce((sum, l) => sum + l.ketoneLevel, 0) / 3;
    const olderAvg = older.reduce((sum, l) => sum + l.ketoneLevel, 0) / 3;

    if (recentAvg > olderAvg + 0.2) trend = 'improving';
    else if (recentAvg < olderAvg - 0.2) trend = 'declining';
    else trend = 'stable';
  }

  return {
    avgLevel: Math.round(avgLevel * 100) / 100,
    minLevel: Math.round(minLevel * 100) / 100,
    maxLevel: Math.round(maxLevel * 100) / 100,
    daysInKetosis,
    totalDays,
    ketosisRate: Math.round(ketosisRate * 100) / 100,
    trend
  };
}
