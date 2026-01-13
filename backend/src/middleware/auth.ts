import { FastifyRequest, FastifyReply } from 'fastify';
import { verifyToken } from '../services/auth.js';

declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      userId: string;
      email: string;
    };
  }
}

export async function authMiddleware(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const authHeader = request.headers.authorization;

    if (!authHeader) {
      return reply.code(401).send({ error: 'No authorization header provided' });
    }

    const token = authHeader.replace('Bearer ', '');

    if (!token) {
      return reply.code(401).send({ error: 'No token provided' });
    }

    try {
      const payload = verifyToken(token);
      request.user = payload;
    } catch (error) {
      if (error instanceof Error && error.name === 'TokenExpiredError') {
        return reply.code(403).send({ error: 'Token has expired' });
      }
      return reply.code(401).send({ error: 'Invalid token' });
    }
  } catch (error) {
    return reply.code(500).send({ error: 'Authentication failed' });
  }
}
