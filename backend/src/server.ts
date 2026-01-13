import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import rateLimit from '@fastify/rate-limit';
import { config } from 'dotenv';
import { analyzeRoutes } from './routes/analyze.js';
import { authRoutes } from './routes/auth.js';
import { userRoutes } from './routes/user.js';

config();

// Validate required environment variables
if (!process.env.GEMINI_API_KEY) {
  console.error('Error: GEMINI_API_KEY environment variable is required');
  process.exit(1);
}

const PORT = process.env.PORT || 3000;

const server = Fastify({
  logger: true
});

await server.register(cors, {
  origin: true
});

await server.register(multipart, {
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  }
});

await server.register(rateLimit, {
  max: 100, // 100 requests
  timeWindow: 60 * 60 * 1000, // per hour (in milliseconds)
  errorResponseBuilder: (request, context) => {
    return {
      statusCode: 429,
      error: 'Too Many Requests',
      message: `Rate limit exceeded, retry in ${Math.ceil(context.ttl / 1000)} seconds`
    };
  },
  addHeaders: {
    'x-ratelimit-limit': true,
    'x-ratelimit-remaining': true,
    'x-ratelimit-reset': true,
    'retry-after': true
  }
});

server.get('/health', async (request, reply) => {
  return { status: 'ok' };
});

await server.register(authRoutes);
await server.register(userRoutes);
await server.register(analyzeRoutes);

const start = async () => {
  try {
    await server.listen({ port: Number(PORT), host: '0.0.0.0' });
    console.log(`Server listening on port ${PORT}`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();
