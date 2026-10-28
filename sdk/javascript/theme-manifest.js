const ALLOWED_KEYS = new Set([
  'id', 'name', 'version', 'apiVersion', 'entry', 'author', 'description', 'capabilities', 'permissions',
]);
const ALLOWED_CAPABILITIES = new Set(['cpu', 'gpu', 'memory', 'disk', 'network', 'clock']);
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$/;
const RESERVED_WINDOWS_NAMES = /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$/i;

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function validRelativeAssetPath(value) {
  if (typeof value !== 'string' || value.length === 0 || value.length > 240 || value.startsWith('/')) return false;
  if (value.includes('\\') || value.includes(':') || /[\u0000-\u001f\u007f?#%]/.test(value)) return false;
  const segments = value.split('/');
  return segments.every((part) => part.length > 0 && part !== '.' && part !== '..' &&
    !part.endsWith('.') && !part.endsWith(' ') && !RESERVED_WINDOWS_NAMES.test(part));
}

/** Validate an untrusted theme.json value against the supported v1 contract. */
export function validateThemeManifest(manifest) {
  const errors = [];
  if (!isRecord(manifest)) return { valid: false, errors: ['manifest must be a JSON object.'] };

  for (const key of Object.keys(manifest)) {
    if (!ALLOWED_KEYS.has(key)) errors.push(`unknown property: ${key}.`);
  }
  for (const key of ALLOWED_KEYS) {
    if (!Object.hasOwn(manifest, key)) errors.push(`missing required property: ${key}.`);
  }

  if (typeof manifest.id !== 'string' || manifest.id.length > 63 ||
      !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(manifest.id) || RESERVED_WINDOWS_NAMES.test(manifest.id)) {
    errors.push('id must be a lowercase portable folder id (1–63 letters, digits, or internal hyphens).');
  }
  if (typeof manifest.name !== 'string' || manifest.name.trim().length === 0 || manifest.name.length > 100) {
    errors.push('name must contain 1–100 characters.');
  }
  if (typeof manifest.version !== 'string' || !SEMVER.test(manifest.version)) {
    errors.push('version must follow Semantic Versioning 2.0.0.');
  }
  if (manifest.apiVersion !== '1') errors.push('apiVersion must be the string "1".');
  if (!validRelativeAssetPath(manifest.entry) || !manifest.entry.toLowerCase().endsWith('.html')) {
    errors.push('entry must be a safe relative path ending in .html.');
  }
  if (typeof manifest.author !== 'string' || manifest.author.trim().length === 0 || manifest.author.length > 200) {
    errors.push('author must contain 1–200 characters.');
  }
  if (typeof manifest.description !== 'string' || manifest.description.length > 1000) {
    errors.push('description must be a string of at most 1000 characters.');
  }
  if (!Array.isArray(manifest.capabilities) || manifest.capabilities.length > ALLOWED_CAPABILITIES.size ||
      manifest.capabilities.some((item) => typeof item !== 'string' || !ALLOWED_CAPABILITIES.has(item)) ||
      new Set(manifest.capabilities).size !== manifest.capabilities.length) {
    errors.push('capabilities must contain unique supported metric names.');
  }
  if (!Array.isArray(manifest.permissions) || manifest.permissions.length !== 0) {
    errors.push('permissions must be an empty array in Theme API v1.');
  }

  return { valid: errors.length === 0, errors };
}

export { ALLOWED_CAPABILITIES };
