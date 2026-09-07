import { createContext, useContext, useEffect, useId, useState } from 'react';
import { plainContentToString } from '@blocknote/core';
import { createReactBlockSpec, SourceBlockWithPreview, type ReactCustomBlockRenderProps } from '@blocknote/react';
import mermaid, { type MermaidConfig } from 'mermaid';
import '../../Sources/PalmCore/Resources/Diagrams/palm-theme.js';
declare global { var palmDiagramTheme: (dark: boolean) => MermaidConfig; }
import { parseDiagramCodeContent, parseDiagramCodeElement } from '@blocknote/diagram-block';

export const EditorThemeContext=createContext(false);
const config={type:'diagram' as const,propSchema:{},content:'plain' as const};
function DiagramBlock(props:ReactCustomBlockRenderProps<typeof config>) {
  const dark=useContext(EditorThemeContext);
  const source=plainContentToString(props.block.content);
  const id='palmdiagram'+useId().replaceAll(/[^a-zA-Z0-9]/g,'');
  const [svg,setSVG]=useState('');
  const [error,setError]=useState<string>();
  useEffect(()=>{
    let cancelled=false;
    void(async()=>{
      try {
        if(source.length>20000 || /%%\{|^\s*---/m.test(source)) throw Error('Use diagram syntax without configuration directives.');
        mermaid.initialize(globalThis.palmDiagramTheme(dark));
        if(!source.trim()) {setSVG('');setError(undefined);return;}
        const result=await mermaid.render(id,source);
        if(!cancelled){setSVG(result.svg);setError(undefined);}
      } catch {if(!cancelled){setSVG('');setError('This diagram could not be drawn. Click to edit its source.');}}
    })();
    return ()=>{cancelled=true;};
  },[source,dark,id]);
  return <SourceBlockWithPreview block={props.block} editor={props.editor} contentRef={props.contentRef} source={source} sourcePlaceholder="flowchart LR\n A --> B" error={error}
    preview={svg?<div className="palm-diagram" role="img" aria-label="Flow diagram" dangerouslySetInnerHTML={{__html:svg}}/>:undefined}
    errorPreview={<span>{error}</span>} emptySourcePlaceholder={<span>Add a flow diagram</span>}/>;
}
export const createPalmDiagramSpec=createReactBlockSpec(config,{
  meta:{code:true,defining:true,hasPreview:true,hardBreakShortcut:'shift+enter'},
  render:DiagramBlock,
  parse:parseDiagramCodeElement,
  parseContent:parseDiagramCodeContent,
  runsBefore:['codeBlock'],
  toExternalHTML:({contentRef})=><pre><code className="language-mermaid" data-language="mermaid" ref={contentRef}/></pre>
});
