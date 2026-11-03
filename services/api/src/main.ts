import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { json } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(json({ limit: '40mb' })); // CMS media uploads (PhET pages are a few MB)
  app.enableCors({ origin: (process.env.WEB_ORIGINS ?? 'http://localhost:3001,http://localhost:3002').split(',') });
  await app.listen(Number(process.env.PORT ?? 4000));
}
bootstrap();
