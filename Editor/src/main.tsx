import { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { filterSuggestionItems } from '@blocknote/core';
import { useCreateBlockNote, SuggestionMenuController, FormattingToolbarController, getDefaultReactSlashMenuItems } from '@blocknote/react';
import { BlockNoteView } from '@blocknote/shadcn';
import { getMathSlashMenuItems } from '@blocknote/math-block';
import { getDiagramSlashMenuItems } from '@blocknote/diagram-block';
import '@blocknote/core/fonts/inter.css';
import '@blocknote/shadcn/style.css';
import './style.css';
import { EditorThemeContext } from './DiagramBlock';
import { NoteToolbar } from './NoteToolbar';
import { createSchema } from './schema';
import { importMarkdown, exportMarkdown } from './document';

type Payload = {id:string; markdown:string; blocks?:string; dark:boolean; revision:string; links?:Record<string,string>};
declare global { interface Window { webkit?:{messageHandlers:{plam:{postMessage:(v:unknown)=>void}}}; plam?:{load:(p:Payload)=>void; flush:()=>void; undo:()=>void}; } }
const send = (value:unknown) => window.webkit?.messageHandlers.plam.postMessage(value);
const schema = createSchema(target=>send({type:'openNote',target}));

function Editor() {
  const editor = useCreateBlockNote({schema, placeholders:{default:'Write, or type / for blocks…'}});
  const [dark,setDark] = useState(false);
  const [error,setError] = useState('');
  const [links,setLinks] = useState<Record<string,string>>({});
  useEffect(()=>{document.documentElement.classList.toggle('dark',dark);},[dark]);
  useEffect(() => {
    let current:Payload|undefined;
    let loading = false;
    let timer:ReturnType<typeof setTimeout>|undefined;
    const flush = () => {
      clearTimeout(timer);
      if (!current || loading) return;
      send({type:'change',id:current.id,blocks:JSON.stringify(editor.document),markdown:exportMarkdown(editor),revision:current.revision});
    };
    window.plam = {load:(p) => {
      setLinks(p.links || {});
      if(current?.id===p.id && current.revision===p.revision) {setDark(p.dark); return;}
      loading=true;
      try {
        const blocks = p.blocks ? JSON.parse(p.blocks) : importMarkdown(editor, p.markdown || '', p.links);
        editor.replaceBlocks(editor.document, blocks.length ? blocks : [{type:'paragraph',content:''}]);
        current=p; setDark(p.dark); setError('');
      } catch {setError('This note could not be opened safely. Its saved text is unchanged.'); send({type:'error',message:'The note editor could not read this document.'});}
      finally {loading=false;}
    },flush,undo:()=>{editor.undo();flush();}};
    const off = editor.onChange(() => { if(!loading) {clearTimeout(timer);flush();} });
    const selected = () => send({type:'selection',text:window.getSelection()?.toString() || ''});
    document.addEventListener('selectionchange',selected);
    window.addEventListener('blur',flush); window.addEventListener('pagehide',flush);
    send({type:'ready'});
    return () => {flush();off();document.removeEventListener('selectionchange',selected);window.removeEventListener('blur',flush);window.removeEventListener('pagehide',flush);delete window.plam;};
  },[editor]);
  return <EditorThemeContext.Provider value={dark}><main data-theme={dark?'dark':'light'}>{error ? <p role="alert">{error}</p> : <BlockNoteView editor={editor} theme={dark?'dark':'light'} slashMenu={false} formattingToolbar={false}>
    <FormattingToolbarController formattingToolbar={NoteToolbar}/>
    <SuggestionMenuController triggerCharacter="[[" getItems={async query=>Object.entries(links).filter(([title])=>title.toLowerCase().includes(query.toLowerCase())).slice(0,20).map(([title,target])=>({title,group:'Notes',onItemClick:()=>editor.insertInlineContent([{type:'noteLink',props:{label:title,target}},' '])}))}/>
    <SuggestionMenuController triggerCharacter="/" getItems={async query => filterSuggestionItems([...getDefaultReactSlashMenuItems(editor).filter(i=>!['Image','Video','Audio','File'].includes(i.title)),...getMathSlashMenuItems(editor),...getDiagramSlashMenuItems(editor)],query)}/>
  </BlockNoteView>}</main></EditorThemeContext.Provider>;
}
createRoot(document.getElementById('root')!).render(<Editor/>);
