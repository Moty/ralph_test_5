import Fastify from 'fastify';
import cors from '@fastify/cors';
import { config } from 'dotenv';

config();

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
