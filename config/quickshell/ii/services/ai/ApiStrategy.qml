import QtQuick

QtObject {
    property bool dataViaStdin: false // Pipe the request body to curl instead of passing it as an argument
    function buildEndpoint(model: AiModel): string { throw new Error("Not implemented") }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { throw new Error("Not implemented") }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { throw new Error("Not implemented") }
    function parseResponseLine(line: string, message: AiMessageData) { throw new Error("Not implemented") }
    function onRequestFinished(message: AiMessageData): var { return {} } // Default: no special handling
    function reset() { } // Reset any internal state if needed
    function buildScriptFileSetup(filePath) { return "" } // Default: no setup
    function finalizeScriptContent(scriptContent: string): string { return scriptContent } // Optionally modify/finalize script
}
