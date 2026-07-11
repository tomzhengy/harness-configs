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
const footerLabels = [...js.matchAll(patchedPattern)].sort((a, b) => b.index - a.index);
let compactFooterCount = 0;
let expandedFooterCount = 0;

for (const footerLabel of footerLabels) {
    const modeVariable = footerLabel[1];
    const escapedModeVariable = modeVariable.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const suffixStart = footerLabel.index + footerLabel[0].length;
    const suffix = js.slice(suffixStart, suffixStart + 200);
    const compactPatched = new RegExp(
        `^,${escapedModeVariable}==="bypassPermissions"\\?null:${identifier}(?=\\]\\},"mode")`
    );
    const compactOriginal = new RegExp(`^,(${identifier})(?=\\]\\},"mode")`);
    const expandedPatched = new RegExp(
        `^,${escapedModeVariable}!=="bypassPermissions"&&${identifier}&&${identifier}&&`
    );
    const expandedOriginal = new RegExp(`^,(${identifier}&&${identifier}&&)`);
    let match = suffix.match(compactPatched);

    if (match) {
        compactFooterCount += 1;
        continue;
    }

    match = suffix.match(compactOriginal);
    if (match) {
        const replacement = `,${modeVariable}==="bypassPermissions"?null:${match[1]}`;
        js = js.slice(0, suffixStart) + replacement + js.slice(suffixStart + match[0].length);
        compactFooterCount += 1;
        continue;
    }

    match = suffix.match(expandedPatched);
    if (match) {
        expandedFooterCount += 1;
        continue;
    }

    match = suffix.match(expandedOriginal);
    if (match) {
        const replacement = `,${modeVariable}!=="bypassPermissions"&&${match[1]}`;
        js = js.slice(0, suffixStart) + replacement + js.slice(suffixStart + match[0].length);
        expandedFooterCount += 1;
        continue;
    }

    throw new Error('could not locate the bypass permission cycle hint');
}

if (compactFooterCount !== 1 || expandedFooterCount !== 1) {
    throw new Error(
        `expected one compact and one expanded footer, found ${compactFooterCount} compact and ${expandedFooterCount} expanded`
    );
}

const usageCachePath = '/.cache/harness-statusline/footer-usage.txt';
const usagePatchCount = js.split(usageCachePath).length - 1;
if (usagePatchCount === 0) {
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
        `${escapedReactVariable}\\.jsxs\\((${identifier}),\\{height:1,overflow:"hidden",children:\\[(${identifier},${identifier},${identifier},${identifier},${identifier}),null\\]\\}\\)`
    );
    const expandedRootPattern = new RegExp(
        `${escapedReactVariable}\\.jsxs\\((${identifier}),\\{height:1,overflow:"hidden",children:\\[(${identifier}(?:,${identifier}){6})\\]\\}\\)`
    );
    const compactRoot = js.match(compactRootPattern);
    const expandedRoot = js.match(expandedRootPattern);
    if (!compactRoot || !expandedRoot) {
        throw new Error('could not locate both footer root layouts');
    }

    const makeUsageChildren = (boxVariable) => {
        const usageValue = `(()=>{try{return require("fs").readFileSync(process.env.HOME+"${usageCachePath}","utf8")}catch{return""}})()`;
        return `${reactVariable}.jsx(${boxVariable},{flexGrow:1}),${reactVariable}.jsx(${boxVariable},{flexShrink:100,marginLeft:1,children:${reactVariable}.jsx(${textVariable},{dimColor:!0,wrap:"truncate",children:${usageValue}})})`;
    };
    js = js.replace(
        compactRootPattern,
        `${reactVariable}.jsxs($1,{height:1,overflow:"hidden",children:[$2,${makeUsageChildren(compactRoot[1])}]})`
    );
    js = js.replace(
        expandedRootPattern,
        `${reactVariable}.jsxs($1,{height:1,overflow:"hidden",children:[$2,${makeUsageChildren(expandedRoot[1])}]})`
    );
} else if (usagePatchCount !== 2) {
    throw new Error(`expected zero or two footer usage patches, found ${usagePatchCount}`);
}

return js;
