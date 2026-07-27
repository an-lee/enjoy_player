#!/usr/bin/env node
/**
 * Export Play Store feature graphic (1024×500 PNG).
 * Run: npm install --prefix tool && node tool/export_feature_graphic.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hostname } from 'node:os';
import { Resvg } from '@resvg/resvg-js';
import { PostHog } from 'posthog-node';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const inputSvg = join(root, 'assets', 'store', 'feature-graphic.svg');
const outputPng = join(root, 'assets', 'store', 'feature-graphic.png');

const phKey = process.env.POSTHOG_API_KEY;
const phHost = process.env.POSTHOG_HOST;
let posthog = null;
if (phKey && phHost) {
  posthog = new PostHog(phKey, { host: phHost, flushAt: 1, flushInterval: 0, isServer: false, enableExceptionAutocapture: true });
} else {
  console.warn('POSTHOG_API_KEY variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once POSTHOG_API_KEY is configured');
}
const distinctId = hostname();

try {
  const svg = readFileSync(inputSvg, 'utf8');
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: 1024 },
    background: '#08080E',
  });
  const rendered = resvg.render();
  writeFileSync(outputPng, rendered.asPng());
  console.log(`Wrote ${outputPng} (${rendered.width}x${rendered.height})`);
  posthog?.capture({
    distinctId,
    event: 'feature_graphic_exported',
    properties: { width: rendered.width, height: rendered.height, output_path: outputPng },
  });
} catch (err) {
  posthog?.capture({
    distinctId,
    event: 'feature_graphic_export_failed',
    properties: { error: err.message },
  });
  posthog?.captureException(err, distinctId);
  console.error(err);
  process.exitCode = 1;
} finally {
  await posthog?.shutdown();
}
