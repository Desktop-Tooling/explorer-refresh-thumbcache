// Refresh Windows thumbnail cache. Invoked from Explorer context menu with optional folder path.
// Built with LDC, -nogc; uses Windows API for env, file enum, and process control.

version (Windows) {
    import core.sys.windows.windows;
} else {
    static assert(0, "Windows only");
}

extern (Windows) nothrow @nogc {
    HANDLE FindFirstFileW(const wchar* lpFileName, WIN32_FIND_DATAW* lpFindFileData);
    BOOL   FindNextFileW(HANDLE hFindFile, WIN32_FIND_DATAW* lpFindFileData);
    BOOL   FindClose(HANDLE hFindFile);
    DWORD  GetEnvironmentVariableW(const wchar* name, wchar* buffer, DWORD size);
    DWORD  GetFileAttributesW(const wchar* lpFileName);
    BOOL   SetFileAttributesW(const wchar* lpFileName, DWORD dwFileAttributes);
    BOOL   DeleteFileW(const wchar* lpFileName);
    BOOL   CloseHandle(HANDLE hObject);
    void   Sleep(DWORD dwMilliseconds);
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
    BOOL   TerminateProcess(HANDLE hProcess, UINT uExitCode);
    DWORD  WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
    BOOL   CreateProcessW(const wchar* lpApplicationName, wchar* lpCommandLine,
        SECURITY_ATTRIBUTES* lpProcessAttributes, SECURITY_ATTRIBUTES* lpThreadAttributes,
        BOOL bInheritHandles, DWORD dwCreationFlags, void* lpEnvironment,
        const wchar* lpCurrentDirectory, STARTUPINFOW* lpStartupInfo, PROCESS_INFORMATION* lpProcessInformation);
}

enum DWORD FILE_ATTRIBUTE_READONLY  = 0x01;
enum DWORD FILE_ATTRIBUTE_NORMAL    = 0x80;
enum DWORD FILE_ATTRIBUTE_DIRECTORY  = 0x10;
enum DWORD PROCESS_TERMINATE        = 0x0001;
enum DWORD INFINITE                 = 0xFFFFFFFF;

// Max path and buffer for Explorer cache path
enum size_t MAX_ENV = 32768;
enum size_t MAX_PATH_W = 32768;

__gshared wchar[MAX_ENV] g_envBuf;
__gshared wchar[MAX_PATH_W] g_pathBuf;
__gshared wchar[MAX_PATH_W] g_searchSpec;

bool tryDeleteCacheFile(const wchar* path) @nogc {
    DWORD attrs = GetFileAttributesW(path);
    if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_READONLY))
        SetFileAttributesW(path, FILE_ATTRIBUTE_NORMAL);
    return DeleteFileW(path) != 0;
}

bool matchesCachePattern(const wchar* name) @nogc {
    // thumbcache_*.db or iconcache_*.db
    size_t len = 0;
    while (name[len]) len++;
    if (len < 4) return false;
    const wchar* ext = name + len - 4;
    if (ext[0] != '.' || ext[1] != 'd' || ext[2] != 'b') return false;
    // thumbcache_ or iconcache_
    if (len >= 12) {
        if (name[0]=='t' && name[1]=='h' && name[2]=='u' && name[3]=='m' && name[4]=='b' &&
            name[5]=='c' && name[6]=='a' && name[7]=='c' && name[8]=='h' && name[9]=='e' && name[10]=='_')
            return true;
    }
    if (len >= 11) {
        if (name[0]=='i' && name[1]=='c' && name[2]=='o' && name[3]=='n' && name[4]=='c' &&
            name[5]=='a' && name[6]=='c' && name[7]=='h' && name[8]=='e' && name[9]=='_')
            return true;
    }
    return false;
}

int clearExplorerCache(bool* anyDeleted) @nogc {
    g_envBuf[0] = 0;
    if (GetEnvironmentVariableW("LOCALAPPDATA"w.ptr, g_envBuf.ptr, cast(DWORD)(g_envBuf.length)) == 0)
        return 0;
    // Build path: LOCALAPPDATA\Microsoft\Windows\Explorer
    size_t i = 0;
    while (g_envBuf[i] && i < g_pathBuf.length - 1) { g_pathBuf[i] = g_envBuf[i]; i++; }
    const wchar[] rest = "\\Microsoft\\Windows\\Explorer"w;
    for (size_t j = 0; j < rest.length && (i + j) < g_pathBuf.length - 1; j++)
        g_pathBuf[i + j] = rest[j];
    i += rest.length;
    g_pathBuf[i] = 0;
    // Search spec: path\*
    size_t k = 0;
    while (g_pathBuf[k] && k < g_searchSpec.length - 3) { g_searchSpec[k] = g_pathBuf[k]; k++; }
    g_searchSpec[k] = '\\'; g_searchSpec[k+1] = '*'; g_searchSpec[k+2] = 0;

    WIN32_FIND_DATAW fd = void;
    HANDLE h = FindFirstFileW(g_searchSpec.ptr, &fd);
    if (h == INVALID_HANDLE_VALUE) return 0;

    int count = 0;
    do {
        if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) continue;
        if (!matchesCachePattern(fd.cFileName.ptr)) continue;
        // Build full path: g_pathBuf + \ + fd.cFileName
        size_t p = 0;
        while (g_pathBuf[p]) p++;
        if (p < g_pathBuf.length - 1) g_pathBuf[p++] = '\\';
        size_t n = 0;
        while (fd.cFileName[n] && (p + n) < g_pathBuf.length - 1) {
            g_pathBuf[p + n] = fd.cFileName[n]; n++;
        }
        g_pathBuf[p + n] = 0;
        if (tryDeleteCacheFile(g_pathBuf.ptr)) {
            count++;
            *anyDeleted = true;
        }
    } while (FindNextFileW(h, &fd) != 0);
    FindClose(h);
    return count;
}

void tryDeleteThumbsDbInFolder(const wchar* folder) @nogc {
    size_t i = 0;
    while (folder[i] && i < g_pathBuf.length - 12) { g_pathBuf[i] = folder[i]; i++; }
    g_pathBuf[i] = '\\';
    g_pathBuf[i+1] = 't'; g_pathBuf[i+2] = 'h'; g_pathBuf[i+3] = 'u'; g_pathBuf[i+4] = 'm';
    g_pathBuf[i+5] = 'b'; g_pathBuf[i+6] = 's'; g_pathBuf[i+7] = '.'; g_pathBuf[i+8] = 'd';
    g_pathBuf[i+9] = 'b'; g_pathBuf[i+10] = 0;
    tryDeleteCacheFile(g_pathBuf.ptr);
}

void restartExplorer() @nogc {
    // Find explorer.exe PIDs and terminate (simplified: use taskkill so we don't need to enumerate)
    STARTUPINFOW si = void;
    PROCESS_INFORMATION pi = void;
    si.cb = STARTUPINFOW.sizeof;
    pi.hProcess = INVALID_HANDLE_VALUE;
    pi.hThread = INVALID_HANDLE_VALUE;
    wchar[64] cmd;
    cmd[0] = 't'; cmd[1] = 'a'; cmd[2] = 's'; cmd[3] = 'k'; cmd[4] = 'k'; cmd[5] = 'i';
    cmd[6] = 'l'; cmd[7] = 'l'; cmd[8] = ' '; cmd[9] = '/'; cmd[10] = 'I'; cmd[11] = 'M';
    cmd[12] = ' '; cmd[13] = 'e'; cmd[14] = 'x'; cmd[15] = 'p'; cmd[16] = 'l'; cmd[17] = 'o';
    cmd[18] = 'r'; cmd[19] = 'e'; cmd[20] = 'r'; cmd[21] = '.'; cmd[22] = 'e'; cmd[23] = 'x';
    cmd[24] = 'e'; cmd[25] = ' '; cmd[26] = '/'; cmd[27] = 'F'; cmd[28] = 0;
    if (CreateProcessW(null, cmd.ptr, null, null, 0, 0, null, null, &si, &pi)) {
        WaitForSingleObject(pi.hProcess, 3000);
        if (pi.hProcess != INVALID_HANDLE_VALUE) CloseHandle(pi.hProcess);
        if (pi.hThread != INVALID_HANDLE_VALUE) CloseHandle(pi.hThread);
    }
    Sleep(500);
    wchar[16] exe;
    exe[0] = 'e'; exe[1] = 'x'; exe[2] = 'p'; exe[3] = 'l'; exe[4] = 'o'; exe[5] = 'r';
    exe[6] = 'e'; exe[7] = 'r'; exe[8] = '.'; exe[9] = 'e'; exe[10] = 'x'; exe[11] = 'e';
    exe[12] = 0;
    CreateProcessW(null, exe.ptr, null, null, 0, 0, null, null, &si, &pi);
    if (pi.hProcess != INVALID_HANDLE_VALUE) CloseHandle(pi.hProcess);
    if (pi.hThread != INVALID_HANDLE_VALUE) CloseHandle(pi.hThread);
}

int main(string[] args) {
    bool folderGiven = args.length > 1 && args[1].length > 0;
    wchar[MAX_PATH_W] folderBuf = void;
    folderBuf[0] = 0;
    if (folderGiven) {
        // Convert args[1] to wchar (simplified: assume ASCII path)
        const s = args[1];
        size_t i = 0;
        while (i < s.length && i < folderBuf.length - 1) {
            folderBuf[i] = cast(wchar) s[i];
            i++;
        }
        folderBuf[i] = 0;
        // Validate directory exists (GetFileAttributesW with FILE_ATTRIBUTE_DIRECTORY)
        DWORD attrs = GetFileAttributesW(folderBuf.ptr);
        if (attrs == INVALID_FILE_ATTRIBUTES || (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0)
            folderGiven = false;
    }

    bool anyDeleted = false;
    int n = clearExplorerCache(&anyDeleted);

    if (folderGiven)
        tryDeleteThumbsDbInFolder(folderBuf.ptr);

    if (n == 0 && !anyDeleted) {
        // Cache may be locked; restart Explorer and retry once
        restartExplorer();
        anyDeleted = false;
        clearExplorerCache(&anyDeleted);
    }
    if (anyDeleted || n > 0)
        restartExplorer();

    return 0;
}
