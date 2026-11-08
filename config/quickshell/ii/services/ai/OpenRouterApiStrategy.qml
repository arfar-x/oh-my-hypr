import QtQuick
import qs.modules.common.functions as CF

/**
 * OpenRouter: OpenAI-compatible chat completions plus usage/cost reporting, reasoning effort,
 * the web search plugin and image/PDF attachments (sent inline as base64 data URIs).
 *
 * "Tools" for this format are OpenRouter plugins, e.g. [{ id: "web" }]; they go into `plugins`.
 */
OpenAiApiStrategy {
    property string reasoningEffort: "" // "", "low", "medium" or "high"
    readonly property string fileDataVarName: "OR_FILE_DATA"
    readonly property string fileSubstitutionString: "__OR_FILE_DATA__"

    // Attachments can be megabytes, far beyond the per-argument exec limit, so the body is piped.
    dataViaStdin: true

    function fileContentPart(filePath: string) {
        const name = filePath.split("/").pop();
        const ext = name.split(".").pop().toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif"].includes(ext)) {
            return { "type": "image_url", "image_url": { "url": fileSubstitutionString } };
        }
        return { "type": "file", "file": { "filename": name, "file_data": fileSubstitutionString } };
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        const hasFile = filePath && filePath.length > 0;
        const lastIndex = messages.length - 1;
        const plugins = (tools ?? []).filter(tool => tool.id !== undefined);
        let data = {
            "model": model.model,
            "messages": [
                { role: "system", content: systemPrompt },
                ...messages.map((message, index) => {
                    return {
                        "role": message.role,
                        "content": (hasFile && index === lastIndex)
                            ? [{ "type": "text", "text": message.rawContent }, fileContentPart(filePath)]
                            : message.rawContent,
                    };
                }),
            ],
            "stream": true,
            "temperature": temperature,
            "usage": { "include": true }, // Ask for the cost of the request in the final chunk
        };
        if (plugins.length > 0) data.plugins = plugins;
        if (reasoningEffort.length > 0 && model.supportsReasoning) data.reasoning = { "effort": reasoningEffort };
        return model.extraParams ? Object.assign({}, data, model.extraParams) : data;
    }

    function buildScriptFileSetup(filePath) {
        const path = CF.StringUtils.shellSingleQuoteEscape(CF.FileUtils.trimFileProtocol(filePath));
        return `OR_FILE_PATH='${path}'\n`
            + `${fileDataVarName}="data:$(file -b --mime-type "$OR_FILE_PATH");base64,$(base64 -w0 "$OR_FILE_PATH")"\n`;
    }

    function finalizeScriptContent(scriptContent: string): string {
        return scriptContent.replace(fileSubstitutionString, () => `'"\$${fileDataVarName}"'`);
    }
}
