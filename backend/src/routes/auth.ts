import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { hashPassword, verifyPassword, generateToken } from '../services/auth.js';
import { getDb } from '../services/database.js';

interface RegisterBody {
  email: string;
  password: string;
  name: string;
}

interface LoginBody {
  email: string;
  password: string;
}

function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function validatePassword(password: string): boolean {
  return password.length >= 8;
}

export async function authRoutes(server: FastifyInstance) {
  const db = getDb();
  
  server.post('/api/auth/register', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { email, password, name } = request.body as RegisterBody;

      if (!email || !password || !name) {
        return reply.code(400).send({ error: 'Email, password, and name are required' });
      }

      if (!validateEmail(email)) {
        return reply.code(400).send({ error: 'Invalid email format' });
      }

      if (!validatePassword(password)) {
        return reply.code(400).send({ error: 'Password must be at least 8 characters' });
      }

      // Check if user already exists
      const existingUser = await db.findUserByEmail(email);

      if (existingUser) {
        return reply.code(400).send({ error: 'User with this email already exists' });
      }

      // Hash password
      const passwordHash = await hashPassword(password);

      // Create user
      const user = await db.createUser({
        email,
        passwordHash,
        name,
      });

      // Generate token
      const token = generateToken({
        userId: user.id,
        email: user.email,
      });

      return reply.code(201).send({
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
        },
      });
    } catch (error) {
      server.log.error(error);
      return reply.code(500).send({ error: 'Registration failed' });
    }
  });

  server.post('/api/auth/login', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { email, password } = request.body as LoginBody;

      if (!email || !password) {
        return reply.code(400).send({ error: 'Email and password are required' });
      }

      // Find user
      const user = await db.findUserByEmail(email);

      if (!user) {
        return reply.code(401).send({ error: 'Invalid email or password' });
      }

      // Verify password
      const isValid = await verifyPassword(password, user.passwordHash);

      if (!isValid) {
        return reply.code(401).send({ error: 'Invalid email or password' });
      }

      // Generate token
      const token = generateToken({
        userId: user.id,
        email: user.email,
      });

      return reply.code(200).send({
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
        },
      });
    } catch (error) {
      server.log.error(error);
      return reply.code(500).send({ error: 'Login failed' });
    }
  });
}
