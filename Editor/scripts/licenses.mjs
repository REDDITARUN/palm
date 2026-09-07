import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const destination=path.resolve('../Sources/PalmCore/Resources/Editor/Licenses');
fs.mkdirSync(destination,{recursive:true});
const folders=execFileSync('npm',['ls','--omit=dev','--all','--parseable'],{encoding:'utf8'}).trim().split('\n').slice(1);
let notice='Palm editor — production dependency notices\n\nOriginal Palm integration: MIT. Each dependency retains its own license.\nThe dependency graph below may include packages eliminated by tree-shaking.\n\n';
for(const folder of [...new Set(folders)].sort()){
  const pkg=JSON.parse(fs.readFileSync(path.join(folder,'package.json'),'utf8'));
  const license=typeof pkg.license==='string'?pkg.license:JSON.stringify(pkg.license??pkg.licenses??'See package source');
  notice+=`${pkg.name} ${pkg.version} — ${license}\n`;
  notice+=`Source: https://www.npmjs.com/package/${pkg.name}/v/${pkg.version}\n`;
  for(const file of fs.readdirSync(folder).filter(name=>/^(licen[sc]e|copying|notice|ofl)(\.|$)/i.test(name))){
    if(fs.statSync(path.join(folder,file)).isFile()) fs.copyFileSync(path.join(folder,file),path.join(destination,pkg.name.replaceAll('/','-').replace('@','')+'-'+file+'.txt'));
  }
}
notice+='\nBlockNote is MPL-2.0. Unmodified corresponding source is available from each exact npm package version above and https://github.com/TypeCellOS/BlockNote.\nPalm does not include BlockNote XL AI. Integration source: Editor/src in https://github.com/REDDITARUN/palm.\n';
fs.writeFileSync(path.join(destination,'NOTICE.txt'),notice);
