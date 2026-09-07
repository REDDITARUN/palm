import { expect, it } from 'vitest';
import { createPalmHighlighter } from './highlighting';
it('highlights Python offline with distinct light and dark tokens without changing code', async () => {
  const highlighter = await createPalmHighlighter();
  const code = '# A comment\nitems = [1, 2]\nprint(items)';
  for (const theme of ['palm-light', 'palm-dark']) {
    const result = highlighter.codeToTokens(code, {lang:'python', theme});
    expect(result.tokens.map(line=>line.map(token=>token.content).join('')).join('\n')).toBe(code);
    expect(new Set(result.tokens.flat().map(token=>token.color)).size).toBeGreaterThan(2);
  }
  highlighter.dispose();
});
