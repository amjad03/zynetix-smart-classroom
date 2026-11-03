import { CanActivate, Controller, ExecutionContext, Inject, Injectable, Post, Body, SetMetadata, UnauthorizedException, ForbiddenException, createParamDecorator } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import * as bcrypt from 'bcryptjs';
import { SignJWT, jwtVerify } from 'jose';
import { z } from 'zod';
import { DB, Db } from './db/db';
import { Zod, sha256 } from './infra';

export type Role = 'admin' | 'editor' | 'super';
export interface Staff { id: number; email: string; role: Role; collegeId: string | null }
export interface Device { id: string; collegeId: string; sectionId: string }

const secret = () => new TextEncoder().encode(process.env.JWT_SECRET ?? 'dev-secret-change-me');

export const Roles = (...roles: Role[]) => SetMetadata('roles', roles);
export const CurrentStaff = createParamDecorator((_: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest().staff as Staff);
export const CurrentDevice = createParamDecorator((_: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest().device as Device);

const bearer = (req: any) => (req.headers.authorization ?? '').replace(/^Bearer /, '');

/** Staff JWT; `super` passes every role check. College admins only ever see their college. */
@Injectable()
export class StaffGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  async canActivate(ctx: ExecutionContext) {
    const req = ctx.switchToHttp().getRequest();
    try {
      const { payload } = await jwtVerify(bearer(req), secret());
      req.staff = payload.staff as Staff;
    } catch {
      throw new UnauthorizedException({ code: 'unauthenticated' });
    }
    const roles = this.reflector.getAllAndOverride<Role[]>('roles', [ctx.getHandler(), ctx.getClass()]) ?? [];
    if (roles.length && req.staff.role !== 'super' && !roles.includes(req.staff.role)) throw new ForbiddenException({ code: 'forbidden' });
    return true;
  }
}

/** A board's device token (issued at activation; only its hash is stored). */
@Injectable()
export class DeviceGuard implements CanActivate {
  constructor(@Inject(DB) private db: Db) {}
  async canActivate(ctx: ExecutionContext) {
    const req = ctx.switchToHttp().getRequest();
    const d = await this.db.one<Device>('SELECT id, college_id AS "collegeId", section_id AS "sectionId" FROM device WHERE token_hash = $1', [sha256(bearer(req))]);
    if (!d) throw new UnauthorizedException({ code: 'unknown_device' });
    req.device = d;
    await this.db.q('UPDATE device SET last_seen_at = now() WHERE id = $1', [d.id]);
    return true;
  }
}

const Login = z.object({ email: z.string().email(), password: z.string().min(1) }).strict();

@Controller('v1/auth')
export class AuthController {
  constructor(@Inject(DB) private db: Db) {}

  @Post('login')
  async login(@Body(new Zod(Login)) b: z.infer<typeof Login>) {
    const u = await this.db.one('SELECT id, email, role, college_id AS "collegeId", password_hash FROM staff WHERE email = $1', [b.email.toLowerCase()]);
    if (!u || !(await bcrypt.compare(b.password, u.password_hash))) throw new UnauthorizedException({ code: 'bad_credentials' });
    const staff: Staff = { id: u.id, email: u.email, role: u.role, collegeId: u.collegeId };
    const jwt = await new SignJWT({ staff }).setProtectedHeader({ alg: 'HS256' }).setExpirationTime('12h').sign(secret());
    return { token: jwt, staff };
  }
}

/** The college an admin may act on; super/editor may name any. */
export function collegeOf(s: Staff, requested?: string): string {
  if (s.role === 'admin') return s.collegeId!;
  if (!requested) throw new ForbiddenException({ code: 'college_required' });
  return requested;
}
