// A 20 MiB binary result expands to roughly 26.7 MiB in base64. Leave room for
// its JSON envelope while keeping all production input frames bounded.
const mcpMaxFrameBytes = 32 * 1024 * 1024;
