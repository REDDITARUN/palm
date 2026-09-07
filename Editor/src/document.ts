// BlockNote's Markdown format is intentionally lossy. Preserve Palm's extensions
// explicitly; block JSON is always the canonical editing representation.
import type { BlockNoteEditor } from '@blocknote/core';
type Editor = BlockNoteEditor<any, any, any>;
type Item = {type:string; text?:string; styles?:Record<string,unknown>; content?:Item[]|string; props?:Record<string,unknown>; children?:Item[]; [key:string]:unknown};
export function importMarkdown(editor:Editor, markdown:string, links:Record<string,string> = {}) {
  const math = new Map<string,string>();
  // Protect fenced examples: dollar signs within program text are literal.
  const prepared = markdown.split(/(```[\s\S]*?```|~~~[\s\S]*?~~~)/g).map((part,index) => index%2 ? part : part.replace(/^\$\$\s*\n([\s\S]*?)\n\$\$\s*$/gm,(_,source:string) => { const token='PALMMATH'+crypto.randomUUID().replaceAll('-','');math.set(token,source);return '\n'+token+'\n'; })).join('');
  const blocks = editor.tryParseMarkdownToBlocks(prepared) as Item[];
  const walk = (block:Item):Item => {
    if(block.type === 'codeBlock' || block.type === 'diagram') return block;
    if(Array.isArray(block.content)) {
      const plain = block.content.map(i=>i.text||'').join('');
      if(math.has(plain.trim())) return {...block,type:'mathBlock',props:{},content:math.get(plain.trim())!};
      let highlighting = false;
      const markerCount = block.content.filter(i=>i.type==='text' && !i.styles?.code).reduce((count,i)=>count+((i.text||'').match(/==/g)||[]).length,0);
      if(markerCount >= 2 && markerCount % 2 === 0) block.content = block.content.flatMap(item => {
        if(item.type!=='text' || item.styles?.code) return [item];
        const pieces=(item.text||'').split('=='); const result:Item[]=[];
        pieces.forEach((text,index)=>{if(index) highlighting=!highlighting;if(text) result.push({...item,text,styles:highlighting?{...item.styles,backgroundColor:'yellow'}:item.styles});});
        return result;
      });
      block.content = block.content.flatMap(item => {
        if(item.type !== 'text' || item.styles?.code || !item.text) return [item];
        const parts:Item[]=[]; let offset=0;
        const pattern = /==([^=\n]+)==|(?<!\\)\$([^$\n]+)\$|\[\[([^\]\n]+)\]\]/g;
        for(const match of item.text.matchAll(pattern)) {
          if(match.index!>offset) parts.push({...item,text:item.text.slice(offset,match.index)});
          if(match[1]) parts.push({...item,text:match[1],styles:{...item.styles,backgroundColor:'yellow'}});
          else if(match[2]) parts.push({type:'math',props:{},content:match[2]});
          else parts.push({type:'noteLink',props:{label:match[3],target:links[match[3]]||match[3]}});
          offset=match.index!+match[0].length;
        }
        if(offset<item.text.length) parts.push({...item,text:item.text.slice(offset)});
        return parts.length ? parts : [item];
      });
    }
    if(block.children) block.children=block.children.map(walk);
    return block;
  };
  return blocks.map(walk);
}
export function exportMarkdown(editor:Editor) {
  const blocks=structuredClone(editor.document) as Item[];
  const walk=(item:Item):Item=>{
    if(item.type==='noteLink') return {type:'text',text:'[['+String(item.props?.label||item.props?.target)+']]',styles:{}};
    if(item.type==='text' && item.styles?.backgroundColor && item.styles.backgroundColor!=='default') {
      item.text='=='+item.text+'=='; delete item.styles.backgroundColor;
    }
    if(Array.isArray(item.content)) item.content=item.content.map(walk);
    if(item.children) item.children=item.children.map(walk);
    return item;
  };
  return editor.blocksToMarkdownLossy(blocks.map(walk) as never);
}
