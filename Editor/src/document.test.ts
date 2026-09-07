// @vitest-environment jsdom
import { describe, expect, it } from 'vitest';
import { BlockNoteEditor } from '@blocknote/core';
import { createSchema } from './schema';
import { importMarkdown, exportMarkdown } from './document';

const makeEditor=()=>BlockNoteEditor.create({schema:createSchema(()=>{})});
describe('Palm note format',()=>{
  it('preserves equations, code, diagrams, highlights and stable note links',()=>{
    const editor=makeEditor();
    const markdown='# Functions\n\n==A variable `n` is captured.==\n\nInline $x^2$ and [[Scope]].\n\n$$\nf(x) = x^2 + 1\n$$\n\n```javascript\nconst price = "$x$";\n```\n\n```mermaid\nflowchart LR\n A --> B\n```';
    const blocks=importMarkdown(editor,markdown,{Scope:'note-id'});
    editor.replaceBlocks(editor.document,blocks as never);
    const json=JSON.stringify(editor.document);
    expect(json).toContain('mathBlock'); expect(json).toContain('diagram'); expect(json).toContain('backgroundColor":"yellow');expect(json).toContain('note-id');
    const exported=exportMarkdown(editor);
    expect(exported).toContain('f(x) = x^2 + 1');expect(exported).toContain('$x^2$');expect(exported).toContain('[[Scope]]');expect(exported).toContain('flowchart LR');expect(exported).toContain('const price = "$x$";');expect(exported).toContain('==');
    const copy=makeEditor();copy.replaceBlocks(copy.document,JSON.parse(json));expect(JSON.stringify(copy.document)).toEqual(json);
  });
  it('keeps incomplete highlight syntax and code dollar signs literal',()=>{
    const editor=makeEditor();const blocks=importMarkdown(editor,'Unfinished ==important\n\n`$price$`\n\n```text\n$$\nnot a formula\n$$\n```');
    editor.replaceBlocks(editor.document,blocks as never);
    const text=exportMarkdown(editor);expect(text).toContain('==important');expect(text).toContain('`$price$`');expect(text).toContain('not a formula');expect(JSON.stringify(editor.document)).not.toContain('mathBlock');
  });
});
