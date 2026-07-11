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

if (patchedMatches.length === 2 && originalMatches.length === 0) {
    return js;
}

if (originalMatches.length !== 2 || patchedMatches.length !== 0) {
    throw new Error(
        `expected two unpatched footer renderers, found ${originalMatches.length} unpatched and ${patchedMatches.length} patched`
    );
}

js = js.replace(originalPattern, (_, modeVariable) => (
    `,${modeVariable}==="bypassPermissions"?null:[${indicatorFunctionName}(${modeVariable})," on"]`
));

return js;
