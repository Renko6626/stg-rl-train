/* Native x86 launcher. All writes stay beside this executable. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

/* Production string helpers are also exercised by the small host check. */
static int json_string(char *out, size_t capacity, const char *text)
{
    static const char hex[] = "0123456789abcdef";
    size_t n = 0;
#define PUT(c) do { if (n + 1 >= capacity) return 0; out[n++] = (c); } while (0)
    PUT('"');
    for (const unsigned char *p = (const unsigned char *)text; *p; ++p) {
        if (*p == '"' || *p == '\\') { PUT('\\'); PUT((char)*p); }
        else if (*p < 32) {
            PUT('\\'); PUT('u'); PUT('0'); PUT('0');
            PUT(hex[*p >> 4]); PUT(hex[*p & 15]);
        } else PUT((char)*p);
    }
    PUT('"'); out[n] = 0;
#undef PUT
    return 1;
}

static int quote_argument(wchar_t *out, size_t capacity, const wchar_t *text)
{
    size_t n = 0;
#define PUT(c) do { if (n + 1 >= capacity) return 0; out[n++] = (c); } while (0)
    PUT(L'"');
    while (*text) {
        size_t slashes = 0;
        while (*text == L'\\') { ++slashes; ++text; }
        size_t count = (*text == L'"' || !*text) ? slashes * 2 : slashes;
        while (count--) PUT(L'\\');
        if (!*text) break;
        if (*text == L'"') PUT(L'\\');
        PUT(*text++);
    }
    PUT(L'"'); out[n] = 0;
#undef PUT
    return 1;
}

static int make_command_line(wchar_t *out, size_t capacity, const wchar_t *loader,
                             const wchar_t *config, const wchar_t *game)
{
    const wchar_t *arguments[] = {loader, config, game};
    size_t n = 0;
    for (size_t i = 0; i < sizeof arguments / sizeof *arguments; ++i) {
        if (!quote_argument(out + n, capacity - n, arguments[i])) return 0;
        n += wcslen(out + n);
        if (i + 1 < sizeof arguments / sizeof *arguments) {
            if (n + 1 >= capacity) return 0;
            out[n++] = L' '; out[n] = 0;
        }
    }
    return 1;
}

#ifdef TH18_LAUNCHER_TEST
#include <assert.h>
int main(void)
{
    char json[256]; wchar_t quoted[256];
    assert(json_string(json, sizeof json, "C:\\游戏 目录\\a\"b\n\t\001.onnx"));
    assert(!strcmp(json, "\"C:\\\\游戏 目录\\\\a\\\"b\\u000a\\u0009\\u0001.onnx\""));
    assert(!json_string(json, 4, "long"));
    assert(quote_argument(quoted, 256, L"C:\\游戏 目录\\th18.exe"));
    assert(!wcscmp(quoted, L"\"C:\\游戏 目录\\th18.exe\""));
    assert(quote_argument(quoted, 256, L"a\\\"b\\"));
    assert(!wcscmp(quoted, L"\"a\\\\\\\"b\\\\\""));
    assert(quote_argument(quoted, 256, L""));
    assert(!wcscmp(quoted, L"\"\""));
    assert(!quote_argument(quoted, 3, L"abc"));
    wchar_t line[512];
    assert(make_command_line(line, 512, L"C:\\启动 包\\thcrap\\bin\\thcrap_loader.exe",
                             L"C:\\启动 包\\thcrap\\config\\ai.js", L"D:\\游戏 目录\\th18.exe"));
    assert(!wcscmp(line, L"\"C:\\启动 包\\thcrap\\bin\\thcrap_loader.exe\" "
                         L"\"C:\\启动 包\\thcrap\\config\\ai.js\" \"D:\\游戏 目录\\th18.exe\""));
    puts("launcher JSON escaping, Windows argument quoting and absolute command line: PASS");
    return 0;
}
#else
#define WIN32_LEAN_AND_MEAN
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <wincrypt.h>

#define PATH_CAP 1024
#define UTF8_CAP (PATH_CAP * 4)
static const wchar_t title[] = L"TH18 AI 启动器";
static wchar_t root[PATH_CAP];

static int error_message(const wchar_t *message)
{
    MessageBoxW(NULL, message, title, MB_OK | MB_ICONERROR);
    return 0;
}

static int windows_error(const wchar_t *message)
{
    DWORD code = GetLastError();
    wchar_t detail[512] = L"", buffer[1800];
    FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   NULL, code, 0, detail, 512, NULL);
    swprintf(buffer, 1800, L"%ls\n\nWindows 错误 %lu：%ls", message, code, detail);
    return error_message(buffer);
}

static int utf8(const wchar_t *path, char *out)
{
    return WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path, -1,
                               out, UTF8_CAP, NULL, NULL);
}

static int short_path(const wchar_t *path, int limit)
{
    char text[UTF8_CAP];
    int count = utf8(path, text);
    if (!count || count > limit)
        return error_message(L"路径过长。请将启动包和游戏移到较短的目录，再重新启动。\n"
                             L"例如 C:\\TH18-AI 与 C:\\Games\\TH18；中文和空格可以保留。");
    return 1;
}

static int package_path(wchar_t *path, const wchar_t *relative)
{
    int n = swprintf(path, PATH_CAP, L"%ls\\%ls", root, relative);
    if (n < 0 || n >= PATH_CAP) return error_message(L"启动包目录过长，请移到较短目录。");
    return short_path(path, MAX_PATH);
}

static int regular_file(const wchar_t *path)
{
    DWORD attributes = GetFileAttributesW(path);
    return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY);
}

static int check_package(void)
{
    static const wchar_t *files[] = {
        L"model\\b-request-light-shift-k8-best.onnx",
        L"runtime\\onnxruntime.dll", L"runtime\\onnxruntime_providers_shared.dll",
        L"runtime\\msvcp140.dll", L"runtime\\msvcp140_1.dll", L"runtime\\vcruntime140.dll",
        L"runtime\\d3dx9_43.dll", L"runtime\\xinput1_3.dll",
        L"thcrap\\bin\\thcrap_loader.exe", L"thcrap\\bin\\thcrap.dll",
        L"thcrap\\bin\\jansson.dll", L"thcrap\\bin\\win32_utf8.dll",
        L"thcrap\\bin\\zlib-ng.dll", L"thcrap\\bin\\stg_ai.dll",
        L"thcrap\\bin\\update.json", L"thcrap\\config\\games.js",
        L"thcrap\\patches\\stg-ai-th18\\patch.js",
        L"thcrap\\patches\\stg-ai-th18\\versions.js",
        L"thcrap\\patches\\stg-ai-th18\\th18.v1.00a.js"
    };
    wchar_t path[PATH_CAP], message[1500];
    for (size_t i = 0; i < sizeof files / sizeof *files; ++i) {
        if (!package_path(path, files[i])) return 0;
        if (!regular_file(path)) {
            swprintf(message, 1500, L"启动包缺少文件：\n%ls\n\n请完整解压启动包后再运行。", path);
            return error_message(message);
        }
    }
    return 1;
}

static int supported_game(const wchar_t *path)
{
    static const BYTE expected[32] = {
        0x5a,0xeb,0x74,0xb1,0x99,0x39,0xa2,0x9a,0x8c,0xf0,0x6e,0x4f,0xe7,0x77,0x7a,0xaf,
        0x91,0x39,0xe9,0x34,0x78,0x50,0x7e,0x03,0x9f,0x43,0x31,0x81,0x71,0x02,0x0e,0x9f
    };
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    HCRYPTPROV provider = 0; HCRYPTHASH hash = 0;
    BYTE buffer[65536], digest[32]; DWORD read_count, size = sizeof digest;
    int ok = file != INVALID_HANDLE_VALUE;
    if (ok) ok = CryptAcquireContextW(&provider, NULL, NULL, PROV_RSA_AES, CRYPT_VERIFYCONTEXT);
    if (ok) ok = CryptCreateHash(provider, CALG_SHA_256, 0, 0, &hash);
    while (ok) {
        ok = ReadFile(file, buffer, sizeof buffer, &read_count, NULL);
        if (!ok || !read_count) break;
        ok = CryptHashData(hash, buffer, read_count, 0);
    }
    if (ok) ok = CryptGetHashParam(hash, HP_HASHVAL, digest, &size, 0);
    if (ok) ok = size == sizeof expected && !memcmp(digest, expected, sizeof expected);
    if (hash) CryptDestroyHash(hash);
    if (provider) CryptReleaseContext(provider, 0);
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    return ok;
}

static int write_file(const wchar_t *path, const char *text)
{
    HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE)
        return windows_error(L"无法保存启动配置。请将启动包解压到当前用户可写的文件夹。");
    DWORD count = (DWORD)strlen(text), written = 0;
    BOOL ok = WriteFile(file, text, count, &written, NULL);
    DWORD failure = GetLastError();
    if (ok && written != count) failure = ERROR_WRITE_FAULT;
    if (!CloseHandle(file) && ok && written == count) { ok = FALSE; failure = GetLastError(); }
    if (!ok || written != count) {
        SetLastError(failure);
        return windows_error(L"保存启动配置失败。请检查文件夹权限和可用空间。");
    }
    return 1;
}

static int read_game_path(const wchar_t *record, wchar_t *game)
{
    char text[UTF8_CAP]; DWORD count = 0;
    HANDLE file = CreateFileW(record, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    BOOL ok = ReadFile(file, text, sizeof text - 1, &count, NULL);
    CloseHandle(file);
    if (!ok || !count || count == sizeof text - 1) return 0;
    text[count] = 0;
    return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, game, PATH_CAP) != 0;
}

static int select_game(wchar_t *game)
{
    OPENFILENAMEW dialog = {0};
    game[0] = 0; dialog.lStructSize = sizeof dialog;
    dialog.lpstrFilter = L"TH18 游戏程序 (*.exe)\0*.exe\0所有文件\0*.*\0";
    dialog.lpstrFile = game; dialog.nMaxFile = PATH_CAP;
    dialog.lpstrTitle = L"选择 TH18 v1.00a 游戏程序（通常为 th18.exe）";
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
    if (GetOpenFileNameW(&dialog)) return 1;
    if (CommDlgExtendedError()) error_message(L"无法打开文件选择窗口，请重新运行启动器。");
    return 0;
}

static int set_child_path(void)
{
    DWORD old_size = GetEnvironmentVariableW(L"PATH", NULL, 0);
    size_t capacity = old_size + PATH_CAP * 2 + 40;
    wchar_t *value = calloc(capacity, sizeof *value);
    if (!value) return error_message(L"内存不足，无法准备运行环境。");
    int prefix = swprintf(value, capacity, L"%ls\\runtime;%ls\\thcrap\\bin;", root, root);
    if (old_size) GetEnvironmentVariableW(L"PATH", value + prefix, old_size);
    BOOL ok = SetEnvironmentVariableW(L"PATH", value);
    free(value);
    return ok ? 1 : windows_error(L"无法准备运行库搜索路径。");
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command, int show)
{
    (void)instance; (void)previous; (void)command; (void)show;
    wchar_t game[PATH_CAP] = L"", record[PATH_CAP], model[PATH_CAP], ort[PATH_CAP];
    wchar_t config[PATH_CAP], loader[PATH_CAP], cwd[PATH_CAP];
    DWORD count = GetModuleFileNameW(NULL, root, PATH_CAP);
    if (!count || count >= PATH_CAP) return error_message(L"无法读取启动器路径，请移到较短目录。"), 1;
    wchar_t *slash = wcsrchr(root, L'\\');
    if (!slash) return error_message(L"无法确定启动包目录。"), 1;
    *slash = 0;
    if (!check_package() || !package_path(record, L"game-path.txt")) return 1;
    int argc = 0; wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    int choose = argc > 1 && !wcscmp(argv[1], L"--choose");
    if (argc > 1 && !choose) {
        DWORD length = GetFullPathNameW(argv[1], PATH_CAP, game, NULL);
        if (!length || length >= PATH_CAP) game[0] = 0;
    } else if (!choose) read_game_path(record, game);
    if (argv) LocalFree(argv);
    if (game[0] && !supported_game(game)) {
        MessageBoxW(NULL, L"已保存或指定的游戏不存在、无法读取，或不是支持的 TH18 v1.00a 版本。\n请重新选择原版游戏程序。",
                    title, MB_OK | MB_ICONINFORMATION);
        game[0] = 0;
    }
    while (!game[0]) {
        if (!select_game(game)) return 0;
        if (!supported_game(game)) {
            MessageBoxW(NULL, L"该文件无法读取或不匹配支持的 TH18 v1.00a 版本。\n请选择原版游戏程序；启动包不包含游戏文件。",
                        title, MB_OK | MB_ICONWARNING);
            game[0] = 0;
        }
    }
    if (!short_path(game, MAX_PATH) || !package_path(model, L"model\\b-request-light-shift-k8-best.onnx") ||
        !package_path(ort, L"runtime\\onnxruntime.dll") || !short_path(model, 256) || !short_path(ort, 256) ||
        !package_path(config, L"thcrap\\config\\ai.js") || !package_path(loader, L"thcrap\\bin\\thcrap_loader.exe") ||
        !package_path(cwd, L"thcrap")) return 1;
    char game_text[UTF8_CAP], model_text[UTF8_CAP], ort_text[UTF8_CAP];
    char model_json[UTF8_CAP * 6], ort_json[UTF8_CAP * 6], settings[UTF8_CAP * 12 + 512];
    if (!utf8(game, game_text) || !utf8(model, model_text) || !utf8(ort, ort_text) ||
        !json_string(model_json, sizeof model_json, model_text) || !json_string(ort_json, sizeof ort_json, ort_text))
        return error_message(L"路径编码失败，请重新选择游戏或移动启动包。"), 1;
    /* Per-patch config merges after version JSON; top-level breakpoints would suppress hook stages. */
    snprintf(settings, sizeof settings, "{\n  \"console\": false,\n  \"msgbox_invalid_func\": true,\n"
             "  \"patches\": [{\"archive\": \"patches/stg-ai-th18/\", \"config\": {\"breakpoints\": {\"stg_ai_tick\": {"
             "\"model\": %s, \"ort\": %s}}}}]\n}\n", model_json, ort_json);
    if (!write_file(record, game_text) || !write_file(config, settings) || !set_child_path()) return 1;
    HMODULE runtime = LoadLibraryExW(ort, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!runtime) return windows_error(L"无法加载包内 AI 运行库。请完整解压启动包，并查看文件是否被安全软件隔离。"), 1;
    FreeLibrary(runtime);
    wchar_t line[PATH_CAP * 6 + 128];
    if (!make_command_line(line, sizeof line / sizeof *line, loader, config, game))
        return error_message(L"启动参数过长，请将文件移到较短目录。"), 1;
    STARTUPINFOW startup = {0}; PROCESS_INFORMATION process = {0};
    startup.cb = sizeof startup;
    if (!CreateProcessW(loader, line, NULL, NULL, FALSE, 0, NULL, cwd, &startup, &process))
        return windows_error(L"无法启动包内 thcrap 加载器。请检查解压是否完整。"), 1;
    CloseHandle(process.hThread);
    DWORD exit_code = 1;
    if (WaitForSingleObject(process.hProcess, INFINITE) == WAIT_OBJECT_0)
        GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hProcess);
    if (exit_code) {
        wchar_t message[1600];
        swprintf(message, 1600, L"thcrap 加载器退出，错误码 %lu。\n请查看日志并反馈错误内容：\n%ls\\thcrap\\logs\\thcrap_log.txt",
                 exit_code, root);
        error_message(message);
    }
    return exit_code ? 1 : 0;
}
#endif
