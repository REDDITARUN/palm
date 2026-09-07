import { BlockNoteSchema } from '@blocknote/core';
import { createReactInlineContentSpec } from '@blocknote/react';
import { createReactMathBlockSpec, createReactInlineMathSpec } from '@blocknote/math-block';
import { createPalmDiagramSpec } from './DiagramBlock';
export function createSchema(openNote:(target:string)=>void) {
  const noteLink = createReactInlineContentSpec({type:'noteLink',propSchema:{label:{default:''},target:{default:''}},content:'none'}, {
    render:({inlineContent})=><button className="note-link" onClick={()=>openNote(inlineContent.props.target)}>{inlineContent.props.label}</button>,
    toExternalHTML:({inlineContent})=><span>{'[['+inlineContent.props.label+']]'}</span>
  });
  return BlockNoteSchema.create().extend({blockSpecs:{mathBlock:createReactMathBlockSpec(),diagram:createPalmDiagramSpec()},inlineContentSpecs:{noteLink,math:createReactInlineMathSpec()}});
}
