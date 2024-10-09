// this is a workaround to get prisma run in node
import type { PrismaClient as PrismaClientType } from '@prisma/client';
import { createRequire } from 'module';

const require = createRequire(import.meta.url ?? __filename);

const { PrismaClient: PrismaClientImpl } = require('@prisma/client');

export class PrismaClient extends (PrismaClientImpl as typeof PrismaClientType) {}

const prisma = new PrismaClient({
    log: ['query']
})
export default prisma