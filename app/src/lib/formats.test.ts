import { describe, expect, it } from 'vitest';
import {
  AUDIO_EXTS,
  CORE_EXTS,
  IMAGE_EXTS,
  SUPPORTED_EXTS,
  isAudioExt,
  isHeavyExt,
  isImageExt,
} from './formats';

describe('format lists', () => {
  it('includes core document formats', () => {
    for (const ext of ['pdf', 'docx', 'pptx', 'xlsx', 'epub', 'html', 'csv', 'json']) {
      expect(CORE_EXTS).toContain(ext);
      expect(SUPPORTED_EXTS).toContain(ext);
    }
  });

  it('unions core + image + audio without duplicates', () => {
    expect(SUPPORTED_EXTS.length).toBe(new Set([...CORE_EXTS, ...IMAGE_EXTS, ...AUDIO_EXTS]).size);
  });
});

describe('ext classifiers', () => {
  it('detects images case-insensitively', () => {
    expect(isImageExt('PNG')).toBe(true);
    expect(isImageExt('jpg')).toBe(true);
    expect(isImageExt('pdf')).toBe(false);
  });

  it('detects audio case-insensitively', () => {
    expect(isAudioExt('MP3')).toBe(true);
    expect(isAudioExt('wav')).toBe(true);
    expect(isAudioExt('docx')).toBe(false);
  });

  it('marks OCR/audio as heavy', () => {
    expect(isHeavyExt('png')).toBe(true);
    expect(isHeavyExt('mp3')).toBe(true);
    expect(isHeavyExt('pdf')).toBe(false);
    expect(isHeavyExt('docx')).toBe(false);
  });
});
