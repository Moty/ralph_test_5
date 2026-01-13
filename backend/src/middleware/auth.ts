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

/**
 * Optional auth middleware - sets user if valid token exists, but allows
 * unauthenticated requests to proceed (for guest mode features)
 */
export async function optionalAuthMiddleware(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const authHeader = request.headers.authorization;

    if (!authHeader) {
      // No auth header - proceed as guest (request.user will be undefined)
      return;
    }

    const token = authHeader.replace('Bearer ', '');

    if (!token) {
      // Empty token - proceed as guest
      return;
    }

    try {
      const payload = verifyToken(token);
      request.user = payload;
    } catch (error) {
      // Invalid/expired token - proceed as guest rather than rejecting
      console.log('[OptionalAuth] Token validation failed, proceeding as guest');
    }
  } catch (error) {
    // Auth error - proceed as guest
    console.log('[OptionalAuth] Auth error, proceeding as guest');
  }
}
