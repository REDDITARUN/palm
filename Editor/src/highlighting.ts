import { createHighlighterCore, type ThemeRegistration } from 'shiki/core';
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript';
import python from 'shiki/langs/python.mjs';
import javascript from 'shiki/langs/javascript.mjs';
import typescript from 'shiki/langs/typescript.mjs';
import tsx from 'shiki/langs/tsx.mjs';
import jsx from 'shiki/langs/jsx.mjs';
import swift from 'shiki/langs/swift.mjs';
import java from 'shiki/langs/java.mjs';
import rust from 'shiki/langs/rust.mjs';
import go from 'shiki/langs/go.mjs';
import cpp from 'shiki/langs/cpp.mjs';
import c from 'shiki/langs/c.mjs';
import shell from 'shiki/langs/shellscript.mjs';
import sql from 'shiki/langs/sql.mjs';
import json from 'shiki/langs/json.mjs';
import yaml from 'shiki/langs/yaml.mjs';
import html from 'shiki/langs/html.mjs';
import css from 'shiki/langs/css.mjs';

function theme(dark: boolean): ThemeRegistration {
  const ink = dark ? '#dbe8d4' : '#405738';
  const blue = dark ? '#9cb8f2' : '#4a64ab';
  const orange = dark ? '#f0ad6e' : '#b35726';
  const muted = dark ? '#9cb594' : '#6e8061';
  return { name: dark ? 'palm-dark' : 'palm-light', type: dark ? 'dark' : 'light',
    colors: { 'editor.foreground': ink, 'editor.background': dark ? '#29332b' : '#f0f3e8' },
    tokenColors: [
      { scope: ['comment', 'punctuation.definition.comment'], settings: { foreground: muted } },
      { scope: ['keyword', 'storage', 'support.function', 'entity.name.function'], settings: { foreground: blue } },
      { scope: ['constant.numeric', 'constant.language'], settings: { foreground: orange } },
      { scope: ['string', 'variable', 'entity.name.type'], settings: { foreground: ink } }
    ]
  };
}

// Static grammars and a JS regex engine keep notes fully offline and avoid CSP/wasm exceptions.
export const createPalmHighlighter = () => createHighlighterCore({
  themes: [theme(false), theme(true)],
  langs: [python, javascript, typescript, tsx, jsx, swift, java, rust, go, cpp, c, shell, sql, json, yaml, html, css],
  engine: createJavaScriptRegexEngine()
});
