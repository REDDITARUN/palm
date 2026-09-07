// Shared by the native Markdown viewer and editable notebook. No model-supplied styling.
globalThis.palmDiagramTheme = function (dark) {
  const ink = dark ? '#dde8d7' : '#293d30';
  const fill = dark ? '#29382c' : '#eef3e6';
  const emphasis = dark ? '#36492e' : '#e4eed6';
  const line = dark ? '#879d75' : '#9aae85';
  return {
    startOnLoad: false, securityLevel: 'strict', theme: 'base',
    suppressErrorRendering: true, maxTextSize: 20000, maxEdges: 100,
    flowchart: { htmlLabels: false, curve: 'basis', padding: 22, nodeSpacing: 35, rankSpacing: 48 },
    themeVariables: {
      darkMode: dark, background: 'transparent', primaryColor: fill,
      primaryTextColor: ink, primaryBorderColor: fill, lineColor: line,
      secondaryColor: emphasis, secondaryTextColor: ink, secondaryBorderColor: emphasis,
      tertiaryColor: fill, tertiaryTextColor: ink, tertiaryBorderColor: fill,
      clusterBkg: dark ? '#202a21' : '#f7f9f1', clusterBorder: fill,
      edgeLabelBackground: dark ? '#202a21' : '#fcfcf8',
      actorBkg: fill, actorBorder: fill, actorTextColor: ink, actorLineColor: line,
      signalColor: line, signalTextColor: ink, noteBkgColor: emphasis,
      noteBorderColor: emphasis, noteTextColor: ink,
      fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif', fontSize: '14px'
    },
    themeCSS: `.node rect { rx: 12px; ry: 12px; stroke-width: 0 !important; }
      .node polygon, .node circle, .node path { stroke-width: 0 !important; }
      .flowchart-link { stroke: ${line} !important; stroke-width: 1.3px !important; }
      .marker { fill: ${line} !important; stroke: ${line} !important; }
      .label text, .nodeLabel { fill: ${ink} !important; }
      .cluster rect { rx: 14px; ry: 14px; stroke-width: 0 !important; }`
  };
};
