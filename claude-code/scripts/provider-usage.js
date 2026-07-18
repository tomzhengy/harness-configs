#!/usr/bin/env bun

import { mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

const cacheMaxAgeMs = 60_000;
const requestTimeoutMs = 4_000;
const cacheDir = join(homedir(), '.cache', 'harness-statusline');

function toEpochSeconds(value) {
    if (typeof value === 'number' && Number.isFinite(value)) {
        return Math.floor(value);
    }

    if (typeof value !== 'string' || value.length === 0) {
        return null;
    }

    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
        return Math.floor(numeric);
    }

    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : Math.floor(parsed / 1000);
}

function normalizeWindow(window) {
    if (!window || typeof window !== 'object') {
        return null;
    }

    const usedPercent = Number(window.usedPercent ?? window.used_percentage ?? window.utilization);
    if (!Number.isFinite(usedPercent)) {
        return null;
    }

    const windowMinutes = Number(
        window.windowDurationMins ?? window.window_minutes ?? window.windowMinutes
    );
    return {
        usedPercent: Math.max(0, Math.min(100, usedPercent)),
        resetsAt: toEpochSeconds(window.resetsAt ?? window.resets_at),
        windowMinutes: Number.isFinite(windowMinutes) ? windowMinutes : null
    };
}

function normalizeCodexUsage(usage) {
    const windows = [
        normalizeWindow(usage?.primary),
        normalizeWindow(usage?.secondary)
    ].filter(Boolean);
    if (windows.length === 0) {
        return null;
    }

    const primary = windows.find((window) => (
        window.windowMinutes !== null && window.windowMinutes < 1440
    )) ?? null;
    const secondary = windows.find((window) => (
        window.windowMinutes !== null && window.windowMinutes >= 1440
    )) ?? null;

    if (primary || secondary) {
        return { provider: 'codex', primary, secondary };
    }

    return {
        provider: 'codex',
        primary: windows[0] ?? null,
        secondary: windows[1] ?? null
    };
}

function usageFromClaudeSnapshot(snapshot) {
    const limits = snapshot?.rate_limits;
    if (!limits || typeof limits !== 'object') {
        return null;
    }

    const primary = normalizeWindow(limits.five_hour);
    const secondary = normalizeWindow(limits.seven_day);
    return primary || secondary ? { provider: 'anthropic', primary, secondary } : null;
}

async function readClaudeOauthToken() {
    try {
        const credentials = await Bun.file(join(homedir(), '.claude', '.credentials.json')).json();
        const token = credentials?.claudeAiOauth?.accessToken;
        if (typeof token === 'string' && token.length > 0) {
            return token;
        }
    } catch {}

    if (process.platform !== 'darwin') {
        return null;
    }

    const result = Bun.spawnSync(
        ['security', 'find-generic-password', '-s', 'Claude Code-credentials', '-w'],
        { stdout: 'pipe', stderr: 'ignore' }
    );
    if (result.exitCode !== 0) {
        return null;
    }

    try {
        const credentials = JSON.parse(new TextDecoder().decode(result.stdout));
        const token = credentials?.claudeAiOauth?.accessToken;
        return typeof token === 'string' && token.length > 0 ? token : null;
    } catch {
        return null;
    }
}

async function fetchAnthropicUsage() {
    const token = await readClaudeOauthToken();
    if (!token) {
        throw new Error('claude oauth credentials are unavailable');
    }

    const response = await fetch('https://api.anthropic.com/api/oauth/usage', {
        headers: {
            Authorization: `Bearer ${token}`,
            'anthropic-beta': 'oauth-2025-04-20'
        },
        signal: AbortSignal.timeout(requestTimeoutMs)
    });
    if (!response.ok) {
        throw new Error(`anthropic usage request failed with ${response.status}`);
    }

    const body = await response.json();
    const primary = normalizeWindow(body?.five_hour);
    const secondary = normalizeWindow(body?.seven_day);
    if (!primary && !secondary) {
        throw new Error('anthropic usage response has no rate-limit windows');
    }

    return { provider: 'anthropic', primary, secondary };
}

async function writeAppServerMessage(process, message) {
    process.stdin.write(`${JSON.stringify(message)}\n`);
    await process.stdin.flush();
}

async function fetchCodexUsage() {
    const appServer = Bun.spawn(['codex', 'app-server', '--stdio'], {
        stdin: 'pipe',
        stdout: 'pipe',
        stderr: 'ignore'
    });
    const reader = appServer.stdout.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let initialized = false;
    let result = null;
    const timeout = setTimeout(() => appServer.kill(), requestTimeoutMs);

    try {
        await writeAppServerMessage(appServer, {
            method: 'initialize',
            id: 1,
            params: {
                clientInfo: {
                    name: 'harness_statusline',
                    title: 'Harness status line',
                    version: '1.0.0'
                }
            }
        });

        while (true) {
            const chunk = await reader.read();
            if (chunk.done) {
                break;
            }

            buffer += decoder.decode(chunk.value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop() ?? '';

            for (const line of lines) {
                if (line.trim().length === 0) {
                    continue;
                }

                const message = JSON.parse(line);
                if (message.id === 1 && !initialized) {
                    initialized = true;
                    await writeAppServerMessage(appServer, { method: 'initialized', params: {} });
                    await writeAppServerMessage(appServer, { method: 'account/rateLimits/read', id: 2 });
                    continue;
                }

                if (message.id === 2) {
                    const byLimit = message.result?.rateLimitsByLimitId;
                    result = byLimit?.codex ?? message.result?.rateLimits ?? null;
                    break;
                }
            }

            if (result) {
                break;
            }
        }
    } finally {
        clearTimeout(timeout);
        appServer.stdin.end();
        appServer.kill();
        await appServer.exited;
    }

    const usage = normalizeCodexUsage(result);
    if (!usage) {
        throw new Error('codex usage response has no rate-limit windows');
    }

    return usage;
}

async function readCache(provider) {
    const path = join(cacheDir, `${provider}-usage.json`);
    try {
        const cached = await Bun.file(path).json();
        if (!cached?.data || typeof cached.fetchedAt !== 'number') {
            return null;
        }
        return { ...cached, fresh: Date.now() - cached.fetchedAt < cacheMaxAgeMs };
    } catch {
        return null;
    }
}

async function writeCache(provider, data) {
    await mkdir(cacheDir, { recursive: true });
    await Bun.write(
        join(cacheDir, `${provider}-usage.json`),
        JSON.stringify({ fetchedAt: Date.now(), data })
    );
}

function detectProvider(snapshot) {
    const model = `${snapshot?.model?.id ?? ''} ${snapshot?.model?.display_name ?? ''}`.toLowerCase();
    return /(^|[-_ ])(gpt|codex|sol)([-_ ]|$)/.test(model) ? 'codex' : 'anthropic';
}

async function resolveUsage(provider, snapshot) {
    if (provider === 'anthropic') {
        const live = usageFromClaudeSnapshot(snapshot);
        if (live) {
            return live;
        }
    }

    const cached = await readCache(provider);
    if (cached?.fresh) {
        return provider === 'codex' ? normalizeCodexUsage(cached.data) : cached.data;
    }

    try {
        const data = provider === 'codex'
            ? await fetchCodexUsage()
            : await fetchAnthropicUsage();
        await writeCache(provider, data);
        return data;
    } catch {
        if (!cached?.data) {
            return null;
        }
        return provider === 'codex' ? normalizeCodexUsage(cached.data) : cached.data;
    }
}

let snapshot = {};
try {
    snapshot = JSON.parse(await Bun.stdin.text());
} catch {}

const provider = detectProvider(snapshot);
const usage = await resolveUsage(provider, snapshot);
if (usage) {
    process.stdout.write(JSON.stringify(usage));
}
