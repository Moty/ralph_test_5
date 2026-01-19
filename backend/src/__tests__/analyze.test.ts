import { test } from 'node:test';
import assert from 'node:assert';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import { analyzeRoutes } from '../routes/analyze.js';

test('POST /api/analyze - missing file', async () => {
  const server = Fastify();
  await server.register(cors);
  await server.register(multipart);
  await server.register(analyzeRoutes);

  const response = await server.inject({
    method: 'POST',
    url: '/api/analyze'
  });

  assert.strictEqual(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.strictEqual(body.error, 'No image file provided');
});

test('POST /api/analyze - invalid file type', async () => {
  const server = Fastify();
  await server.register(cors);
  await server.register(multipart);
  await server.register(analyzeRoutes);

  const form = new FormData();
  const blob = new Blob(['test'], { type: 'text/plain' });
  form.append('file', blob, 'test.txt');

  const response = await server.inject({
    method: 'POST',
    url: '/api/analyze',
    payload: form,
    headers: form instanceof FormData ? {} : { 'content-type': 'multipart/form-data' }
  });

  assert.strictEqual(response.statusCode, 400);
  const body = JSON.parse(response.body);
  assert.ok(body.error.includes('Invalid file format'));
});

test('POST /api/analyze - file too large', async () => {
  const server = Fastify();
  await server.register(cors);
  await server.register(multipart);
  await server.register(analyzeRoutes);

  // Create a buffer larger than 5MB
  const largeBuffer = Buffer.alloc(6 * 1024 * 1024);
  const form = new FormData();
  const blob = new Blob([largeBuffer], { type: 'image/jpeg' });
  form.append('file', blob, 'large.jpg');

  const response = await server.inject({
    method: 'POST',
    url: '/api/analyze',
    payload: form,
    headers: form instanceof FormData ? {} : { 'content-type': 'multipart/form-data' }
  });

  // Should fail due to Fastify multipart limits or our validation
  assert.ok(response.statusCode >= 400);
});
