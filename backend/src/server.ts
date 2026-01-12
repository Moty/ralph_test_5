import Fastify from 'fastify';
import cors from '@fastify/cors';
import { config } from 'dotenv';

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

server.get('/health', async (request, reply) => {
  return { status: 'ok' };
});

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
