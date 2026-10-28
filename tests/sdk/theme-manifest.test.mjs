import assert from 'node:assert/strict';
import { test } from 'node:test';
import { validateThemeManifest } from '../../sdk/javascript/theme-manifest.js';

const validManifest = {
  id: 'minimal-monitor',
  name: 'Minimal Monitor',
  version: '1.0.0',
  apiVersion: '1',
  entry: 'index.html',
  author: 'Example Author',
  description: 'A small local metrics theme.',
  capabilities: ['cpu', 'memory', 'network', 'clock'],
  permissions: [],
};

test('accepts a valid v1 manifest and returns no errors', () => {
  assert.deepEqual(validateThemeManifest(validManifest), { valid: true, errors: [] });
});

test('rejects missing fields and unsupported API versions', () => {
  const result = validateThemeManifest({ ...validManifest, name: undefined, apiVersion: '2' });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((error) => error.includes('name')));
  assert.ok(result.errors.some((error) => error.includes('apiVersion')));
});

test('rejects traversal paths, malformed ids, and non-semver versions', () => {
  const result = validateThemeManifest({ ...validManifest, id: '../theme', version: 'latest', entry: '../index.html' });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((error) => error.includes('id')));
  assert.ok(result.errors.some((error) => error.includes('version')));
  assert.ok(result.errors.some((error) => error.includes('entry')));
});

test('rejects duplicate or unknown capabilities, permissions, and extra properties', () => {
  const result = validateThemeManifest({
    ...validManifest,
    capabilities: ['cpu', 'cpu', 'shell'],
    permissions: ['filesystem'],
    nativeCommand: 'LoadLibrary',
  });
  assert.equal(result.valid, false);
  assert.ok(result.errors.length >= 3);
});
