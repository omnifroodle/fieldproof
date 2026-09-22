// Hash comparison with fixture bytes; no network.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { compareHash } from '../lib/verify.js';

const bytes = Buffer.from('abc');
const ABC = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'; // FIPS 180-2 test vector

test('matching bytes verify', () => {
  const v = compareHash(bytes, ABC);
  assert.equal(v.verified, true);
  assert.equal(v.actual, ABC);
  assert.equal(v.byteLength, 3);
});

test('uppercase expected hash still verifies', () => {
  assert.equal(compareHash(bytes, ABC.toUpperCase()).verified, true);
});

test('one changed byte is a mismatch', () => {
  const v = compareHash(Buffer.from('abd'), ABC);
  assert.equal(v.verified, false);
  assert.equal(v.expected, ABC);
  assert.notEqual(v.actual, ABC);
});

test('missing expected hash is a mismatch, not a crash', () => {
  assert.equal(compareHash(bytes, undefined).verified, false);
});
