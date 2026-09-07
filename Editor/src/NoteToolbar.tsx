import { FormattingToolbar, BlockTypeSelect, BasicTextStyleButton, ColorStyleButton, CreateLinkButton, useComponentsContext, useBlockNoteEditor } from '@blocknote/react';
import { Highlighter, Sparkles } from 'lucide-react';
export function NoteToolbar() {
  const editor=useBlockNoteEditor();
  const components=useComponentsContext()!;
  const Button=components.FormattingToolbar.Button;
  return <FormattingToolbar>
    <BlockTypeSelect/>
    <BasicTextStyleButton basicTextStyle="bold"/>
    <BasicTextStyleButton basicTextStyle="italic"/>
    <BasicTextStyleButton basicTextStyle="code"/>
    <Button label="Highlight" mainTooltip="Highlight" icon={<Highlighter size={16}/>} onClick={()=>{editor.focus();editor.toggleStyles({backgroundColor:'yellow'});}}/>
    <ColorStyleButton/>
    <CreateLinkButton/>
    <Button label="Ask Plam" mainTooltip="Ask about selection" icon={<Sparkles size={16}/>} onClick={()=>window.webkit?.messageHandlers.plam.postMessage({type:'askSelection',text:editor.getSelectedText()})}/>
  </FormattingToolbar>;
}
