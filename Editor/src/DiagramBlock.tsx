import { createContext, useContext, useEffect, useId, useState } from 'react';
import { plainContentToString } from '@blocknote/core';
import { createReactBlockSpec, SourceBlockWithPreview, type ReactCustomBlockRenderProps } from '@blocknote/react';
import mermaid from 'mermaid';
import { parseDiagramCodeContent, parseDiagramCodeElement } from '@blocknote/diagram-block';

export const EditorThemeContext=createContext(false);
const config={type:'diagram' as const,propSchema:{},content:'plain' as const};
function DiagramBlock(props:ReactCustomBlockRenderProps<typeof config>) {
  const dark=useContext(EditorThemeContext);
  const source=plainContentToString(props.block.content);
  const id='plamdiagram'+useId().replaceAll(/[^a-zA-Z0-9]/g,'');
  const [svg,setSVG]=useState('');
  const [error,setError]=useState<string>();
  useEffect(()=>{
    let cancelled=false;
    void(async()=>{
      try {
        if(source.length>20000 || /%%\{|^\s*---/m.test(source)) throw Error('Use diagram syntax without configuration directives.');
        mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:'base',suppressErrorRendering:true,maxTextSize:20000,maxEdges:100,flowchart:{htmlLabels:false},themeVariables:{darkMode:dark,background:'transparent',primaryColor:dark?'#242b2c':'#f4f6f5',primaryTextColor:dark?'#e3e7e6':'#24282a',primaryBorderColor:dark?'#596565':'#a8b6b2',lineColor:dark?'#91aaa3':'#59756d',fontFamily:'-apple-system',fontSize:'14px'}});
        if(!source.trim()) {setSVG('');setError(undefined);return;}
        const result=await mermaid.render(id,source);
        if(!cancelled){setSVG(result.svg);setError(undefined);}
      } catch {if(!cancelled){setSVG('');setError('This diagram could not be drawn. Click to edit its source.');}}
    })();
    return ()=>{cancelled=true;};
  },[source,dark,id]);
  return <SourceBlockWithPreview block={props.block} editor={props.editor} contentRef={props.contentRef} source={source} sourcePlaceholder="flowchart LR\n A --> B" error={error}
    preview={svg?<div className="plam-diagram" role="img" aria-label="Flow diagram" dangerouslySetInnerHTML={{__html:svg}}/>:undefined}
    errorPreview={<span>{error}</span>} emptySourcePlaceholder={<span>Add a flow diagram</span>}/>;
}
export const createPlamDiagramSpec=createReactBlockSpec(config,{
  meta:{code:true,defining:true,hasPreview:true,hardBreakShortcut:'shift+enter'},
  render:DiagramBlock,
  parse:parseDiagramCodeElement,
  parseContent:parseDiagramCodeContent,
  runsBefore:['codeBlock'],
  toExternalHTML:({contentRef})=><pre><code className="language-mermaid" data-language="mermaid" ref={contentRef}/></pre>
});
