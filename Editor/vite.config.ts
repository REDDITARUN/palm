import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';
export default defineConfig({plugins:[tailwindcss(),viteSingleFile()],build:{outDir:'../Sources/PlamCore/Resources/Editor',emptyOutDir:true,target:'es2022',assetsInlineLimit:10000000}});
