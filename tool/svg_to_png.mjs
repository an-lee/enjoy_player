#!/usr/bin/env node
/**
 * Convert logo SVG to PNG for flutter_launcher_icons.
 * Run from repo root: npm install --prefix tool && node tool/svg_to_png.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hostname } from 'node:os';
import { PostHog } from 'posthog-node';

const __dirname = dirname(fileURLToPath(import.meta.url));

const phKey = process.env.POSTHOG_API_KEY;
const phHost = process.env.POSTHOG_HOST;
let posthog = null;
if (phKey && phHost) {
  posthog = new PostHog(phKey, { host: phHost, flushAt: 1, flushInterval: 0, isServer: false, enableExceptionAutocapture: true });
} else {
  console.warn('POSTHOG_API_KEY variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once POSTHOG_API_KEY is configured');
}
const distinctId = hostname();

async function main() {
  const { Resvg } = await import('@resvg/resvg-js');

  const argv = process.argv.slice(2);
  const size = Number(argv.find((a) => a.startsWith('--size='))?.split('=')[1]) || 1024;
  const positional = argv.filter((a) => !a.startsWith('--'));
  const inputSvg =
    positional[0] ?? join(__dirname, '..', 'assets', 'logo-light.svg');
  const outputPng =
    positional[1] ?? join(__dirname, '..', 'assets', 'logo.png');

  const svg = readFileSync(inputSvg, 'utf8');
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
  });
  const pngData = resvg.render();
  const pngBuffer = pngData.asPng();
  writeFileSync(outputPng, pngBuffer);
  console.log(`Wrote ${outputPng} (${size}x${size})`);
  posthog?.capture({
    distinctId,
    event: 'svg_converted_to_png',
    properties: { size, input_path: inputSvg, output_path: outputPng },
  });
}

main()
  .catch((e) => {
    posthog?.capture({
      distinctId,
      event: 'svg_conversion_failed',
      properties: { error: e.message },
    });
    posthog?.captureException(e, distinctId);
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await posthog?.shutdown();
  });
