const indicatorFunctionMatch = js.match(
    /function ([A-Za-z_$][\w$]*)\(e\)\{return [A-Za-z_$][\w$]*\(e\)\.indicator\}/
);

if (!indicatorFunctionMatch) {
    throw new Error('could not locate the permission-mode indicator function');
}

const indicatorFunctionName = indicatorFunctionMatch[1];
const escapedFunctionName = indicatorFunctionName.replace(
    /[.*+?^${}()|[\]\\]/g,
    '\\$&'
);
const originalPattern = new RegExp(
    `,${escapedFunctionName}\\(([A-Za-z_$][\\w$]*)\\)," on"`,
    'g'
);
const patchedPattern = new RegExp(
    `,([A-Za-z_$][\\w$]*)==="bypassPermissions"\\?null:\\[${escapedFunctionName}\\(\\1\\)," on"\\]`,
    'g'
);
const originalMatches = [...js.matchAll(originalPattern)];
const patchedMatches = [...js.matchAll(patchedPattern)];

if (originalMatches.length === 2 && patchedMatches.length === 0) {
    js = js.replace(originalPattern, (_, modeVariable) => (
        `,${modeVariable}==="bypassPermissions"?null:[${indicatorFunctionName}(${modeVariable})," on"]`
    ));
} else if (originalMatches.length !== 0 || patchedMatches.length !== 2) {
    throw new Error(
        `expected two unpatched footer renderers, found ${originalMatches.length} unpatched and ${patchedMatches.length} patched`
    );
}

const identifier = '[A-Za-z_$][\\w$]*';
const solAutoCompactMarker = 'harness-sol-auto-compact';
const solAutoCompactWindow = 310000;
const solAutoCompactPatchCount = js.split(solAutoCompactMarker).length - 1;

if (solAutoCompactPatchCount === 0) {
    const compactFunctionPattern = new RegExp(
        `function (${identifier})\\((${identifier}),(${identifier})\\)\\{let (${identifier})=(${identifier})\\(\\2\\),(${identifier})=(${identifier})\\(\\),(${identifier})=(${identifier})\\(\\2,\\6\\);`,
        'g'
    );
    const compactFunctions = [...js.matchAll(compactFunctionPattern)].filter((match) => {
        const suffix = js.slice(match.index, match.index + 5000);
        return suffix.includes('CLAUDE_CODE_AUTO_COMPACT_WINDOW')
            && suffix.includes('source:"settings"');
    });

    if (compactFunctions.length !== 1) {
        throw new Error(
            `expected one auto-compact window function, found ${compactFunctions.length}`
        );
    }

    const compactFunction = compactFunctions[0];
    const modelVariable = compactFunction[4];
    const settingVariable = compactFunction[3];
    const maximumVariable = compactFunction[8];
    const functionStart = compactFunction.index;
    const functionSuffix = js.slice(functionStart, functionStart + 5000);
    const settingsPattern = new RegExp(
        `if\\(${settingVariable}!==void 0\\)return\\{window:Math\\.min\\(${maximumVariable},${settingVariable}\\),configured:${settingVariable},source:"settings"\\};`
    );
    const settingsMatch = functionSuffix.match(settingsPattern);

    if (!settingsMatch) {
        throw new Error('could not locate the auto-compact settings override');
    }

    const insertionPoint = functionStart + settingsMatch.index + settingsMatch[0].length;
    const solOverride = `if(${modelVariable}==="gpt-5.6-sol"){let harnessSolWindow=${solAutoCompactWindow};return{window:Math.min(${maximumVariable},harnessSolWindow),configured:harnessSolWindow,source:"model-default"}/* ${solAutoCompactMarker} */}`;
    js = js.slice(0, insertionPoint) + solOverride + js.slice(insertionPoint);
} else if (solAutoCompactPatchCount === 1) {
    const patchedWindowPattern = /let harnessSolWindow=\d+;(?=return\{window:Math\.min\([^,]+,harnessSolWindow\),configured:harnessSolWindow,source:"model-default"\}\/\* harness-sol-auto-compact \*\/)/g;
    const patchedWindowMatches = [...js.matchAll(patchedWindowPattern)];

    if (patchedWindowMatches.length !== 1) {
        throw new Error(
            `expected one patched Sol auto-compact window, found ${patchedWindowMatches.length}`
        );
    }

    js = js.replace(
        patchedWindowPattern,
        `let harnessSolWindow=${solAutoCompactWindow};`
    );
} else {
    throw new Error(
        `expected zero or one Sol auto-compact patches, found ${solAutoCompactPatchCount}`
    );
}

const footerLabels = [...js.matchAll(patchedPattern)].sort((a, b) => b.index - a.index);
let hiddenCycleHintCount = 0;

for (const footerLabel of footerLabels) {
    const modeVariable = footerLabel[1];
    const escapedModeVariable = modeVariable.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const suffixStart = footerLabel.index + footerLabel[0].length;
    const suffix = js.slice(suffixStart, suffixStart + 500);
    const hiddenPattern = /^,null(?=\]\},"mode")/;
    const compactBypassOnlyPattern = new RegExp(
        `^,${escapedModeVariable}==="bypassPermissions"\\?null:${identifier}(?=\\]\\},"mode")`
    );
    const compactOriginalPattern = new RegExp(`^,${identifier}(?=\\]\\},"mode")`);
    const expandedHint = `${identifier}&&${identifier}&&${identifier}\\.jsxs\\(${identifier},\\{dimColor:!0,children:\\[" ",${identifier}\\.jsx\\(${identifier},\\{chord:${identifier},action:"cycle",parens:!0,format:\\{keyCase:"lower"\\}\\}\\)\\]\\}\\)`;
    const expandedBypassOnlyPattern = new RegExp(
        `^,${escapedModeVariable}!=="bypassPermissions"&&${expandedHint}`
    );
    const expandedOriginalPattern = new RegExp(`^,${expandedHint}`);
    let match = suffix.match(hiddenPattern);

    if (match) {
        hiddenCycleHintCount += 1;
        continue;
    }

    match = suffix.match(compactBypassOnlyPattern)
        ?? suffix.match(compactOriginalPattern)
        ?? suffix.match(expandedBypassOnlyPattern)
        ?? suffix.match(expandedOriginalPattern);
    if (match) {
        js = js.slice(0, suffixStart) + ',null' + js.slice(suffixStart + match[0].length);
        hiddenCycleHintCount += 1;
        continue;
    }

    throw new Error('could not locate the bypass permission cycle hint');
}

if (hiddenCycleHintCount !== 2) {
    throw new Error(
        `expected two hidden permission cycle hints, found ${hiddenCycleHintCount}`
    );
}

const usageCachePrefix = '/.cache/harness-statusline/footer-usage.';
const usageCacheMarker = `${usageCachePrefix}"+process.pid+".txt`;
const usageComponentName = 'HarnessFooterUsage';
const usagePatchCount = js.split(usageCacheMarker).length - 1;
const usageComponentCount = js.split(`function ${usageComponentName}`).length - 1;
if (usagePatchCount === 0 && usageComponentCount === 0) {
    const firstFooterLabel = [...js.matchAll(patchedPattern)][0];
    const footerPrefix = js.slice(Math.max(0, firstFooterLabel.index - 500), firstFooterLabel.index);
    const modeRendererPattern = new RegExp(
        `(${identifier})\\.jsxs\\((${identifier}),\\{color:${identifier}\\(${identifier}\\),children:\\[`,
        'g'
    );
    const modeRenderers = [...footerPrefix.matchAll(modeRendererPattern)];
    const modeRenderer = modeRenderers[modeRenderers.length - 1];
    if (!modeRenderer) {
        throw new Error('could not locate the footer react and text components');
    }

    const reactVariable = modeRenderer[1];
    const textVariable = modeRenderer[2];
    const escapedReactVariable = reactVariable.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const compactRootPattern = new RegExp(
        `${escapedReactVariable}\\.jsxs\\((${identifier}),\\{height:1,overflow:"hidden",children:\\[(${identifier},${identifier},${identifier},${identifier},${identifier},null,${identifier})\\]\\}\\)`
    );
    const expandedRootPattern = new RegExp(
        `${escapedReactVariable}\\.jsxs\\((${identifier}),\\{height:1,overflow:"hidden",children:\\[(${identifier}(?:,${identifier}){6})\\]\\}\\)`
    );
    const compactRoot = js.match(compactRootPattern);
    const expandedRoot = js.match(expandedRootPattern);
    if (!compactRoot || !expandedRoot) {
        throw new Error('could not locate both footer root layouts');
    }

    const footerFunctionStart = js.lastIndexOf('function ', compactRoot.index);
    if (footerFunctionStart < 0) {
        throw new Error('could not locate the footer function');
    }

    const footerFunctionPrefix = js.slice(footerFunctionStart, compactRoot.index);
    const hooksMatches = [...footerFunctionPrefix.matchAll(new RegExp(`(${identifier})\\.useState\\(`, 'g'))];
    const hooksVariable = hooksMatches[0]?.[1];
    if (!hooksVariable || !footerFunctionPrefix.includes(`${hooksVariable}.useEffect(`)) {
        throw new Error('could not locate the footer react hooks');
    }

    const readUsage = `()=>{try{return require("fs").readFileSync(process.env.HOME+"${usageCachePrefix}"+process.pid+".txt","utf8")}catch{return""}}`;
    const usageComponent = `function ${usageComponentName}(){let[e,t]=${hooksVariable}.useState(${readUsage});${hooksVariable}.useEffect(()=>{let n=setInterval(()=>{let r=(${readUsage})();t((o)=>o===r?o:r)},1000);return()=>clearInterval(n)},[]);return ${reactVariable}.jsx(${textVariable},{dimColor:!0,wrap:"truncate",children:e})}`;
    js = js.slice(0, footerFunctionStart) + usageComponent + js.slice(footerFunctionStart);

    const makeUsageChildren = (boxVariable) => {
        return `${reactVariable}.jsx(${boxVariable},{flexGrow:1}),${reactVariable}.jsx(${boxVariable},{flexShrink:100,marginLeft:1,children:${reactVariable}.jsx(${usageComponentName},{})})`;
    };
    js = js.replace(
        compactRootPattern,
        `${reactVariable}.jsxs($1,{height:1,overflow:"hidden",children:[$2,${makeUsageChildren(compactRoot[1])}]})`
    );
    js = js.replace(
        expandedRootPattern,
        `${reactVariable}.jsxs($1,{height:1,overflow:"hidden",children:[$2,${makeUsageChildren(expandedRoot[1])}]})`
    );
} else if (usagePatchCount !== 2 || usageComponentCount !== 1) {
    throw new Error(
        `expected an unpatched footer or one usage component, found ${usagePatchCount} usage reads and ${usageComponentCount} components`
    );
}

const foregroundAgentMarker = 'harness-hide-fg-agents';
const foregroundAgentPatchCount = js.split(foregroundAgentMarker).length - 1;
if (foregroundAgentPatchCount === 0) {
    const foregroundAgentPattern = new RegExp(
        `(${identifier})=${identifier}&&!${identifier}\\?${identifier}\\.jsx\\(${identifier},\\{\\},"fg-agents"\\):null`,
        'g'
    );
    const foregroundAgentMatches = [...js.matchAll(foregroundAgentPattern)];
    if (foregroundAgentMatches.length !== 1) {
        throw new Error(
            `expected one foreground agent hint, found ${foregroundAgentMatches.length}`
        );
    }

    js = js.replace(
        foregroundAgentPattern,
        '$1=null/* harness-hide-fg-agents */'
    );
} else if (foregroundAgentPatchCount !== 1) {
    throw new Error(
        `expected zero or one foreground agent hint patches, found ${foregroundAgentPatchCount}`
    );
}

const backgroundAgentMarker = 'harness-hide-bg-agents';
const backgroundAgentPatchCount = js.split(backgroundAgentMarker).length - 1;
if (backgroundAgentPatchCount === 0) {
    const backgroundAgentPattern = new RegExp(
        `(${identifier})=\\(${identifier}\\(\\)\\|\\|${identifier}\\(\\)\\)&&${identifier}&&${identifier}&&!${identifier}&&!${identifier}\\?${identifier}\\.jsx\\(${identifier},\\{\\},"bg-detach"\\):null`,
        'g'
    );
    const backgroundAgentMatches = [...js.matchAll(backgroundAgentPattern)];
    if (backgroundAgentMatches.length !== 1) {
        throw new Error(
            `expected one background agent hint, found ${backgroundAgentMatches.length}`
        );
    }

    js = js.replace(
        backgroundAgentPattern,
        '$1=null/* harness-hide-bg-agents */'
    );
} else if (backgroundAgentPatchCount !== 1) {
    throw new Error(
        `expected zero or one background agent hint patches, found ${backgroundAgentPatchCount}`
    );
}

const idleAgentMarker = 'harness-hide-for-agents';
const idleAgentPatchCount = js.split(idleAgentMarker).length - 1;
if (idleAgentPatchCount === 0) {
    const idleAgentPattern = new RegExp(
        `(${identifier})=${identifier}\\.jsxs\\(${identifier},\\{dimColor:!0,children:\\[${identifier}," for agents"\\]\\}\\)`,
        'g'
    );
    const idleAgentMatches = [...js.matchAll(idleAgentPattern)];
    if (idleAgentMatches.length !== 1) {
        throw new Error(`expected one idle agent hint, found ${idleAgentMatches.length}`);
    }

    js = js.replace(
        idleAgentPattern,
        '$1=null/* harness-hide-for-agents */'
    );
} else if (idleAgentPatchCount !== 1) {
    throw new Error(
        `expected zero or one idle agent hint patches, found ${idleAgentPatchCount}`
    );
}

return js;
