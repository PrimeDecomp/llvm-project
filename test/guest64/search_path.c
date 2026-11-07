typedef unsigned short WCHAR;
typedef unsigned long DWORD;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) DWORD GetModuleFileNameW(void *module, WCHAR *buffer, DWORD length);
__declspec(dllimport) DWORD GetLastError(void);
__declspec(dllimport) void *CreateFileW(const WCHAR *path, DWORD access, DWORD share, void *security, DWORD creation,
										DWORD attributes, void *templateFile);
__declspec(dllimport) DWORD GetFinalPathNameByHandleW(void *file, WCHAR *buffer, DWORD length, DWORD flags);
__declspec(dllimport) int SetFileInformationByHandle(void *file, DWORD infoClass, void *info, DWORD size);
__declspec(dllimport) DWORD GetFileAttributesW(const WCHAR *path);
__declspec(dllimport) int DeleteFileW(const WCHAR *path);
__declspec(dllimport) int GetVolumePathNameW(const WCHAR *path, WCHAR *buffer, DWORD length);
__declspec(dllimport) int CloseHandle(void *file);
__declspec(dllimport) DWORD GetFileType(void *file);
__declspec(dllimport) int GetFileInformationByHandle(void *file, DWORD *info);
__declspec(dllimport) DWORD SearchPathW(const WCHAR *path, const WCHAR *filename, const WCHAR *extension, DWORD length,
										WCHAR *buffer, WCHAR **filePart);
#define CHECK(expr, code)                                                                                              \
	do {                                                                                                               \
		if (!(expr))                                                                                                   \
			ExitProcess(code);                                                                                         \
	} while (0)
static WCHAR lower(WCHAR ch) { return ch >= 'A' && ch <= 'Z' ? ch + ('a' - 'A') : ch; }
static int equal(const WCHAR *a, const WCHAR *b) {
	while (*a && lower(*a) == lower(*b)) {
		++a;
		++b;
	}
	return lower(*a) == lower(*b);
}
void mainCRTStartup(void) {
	static WCHAR directory[2048], result[2048], explicitResult[2048];
	DWORD length = GetModuleFileNameW(0, directory, 2048);
	CHECK(length && length < 2048, 1);
	while (length && directory[length - 1] != '\\')
		--length;
	directory[length] = 0;
	WCHAR *part = 0;
	DWORD required = SearchPathW(directory, L"guest64", L".dll", 0, 0, 0);
	CHECK(required > 1 && required < 2048, 2);
	result[0] = '!';
	CHECK(SearchPathW(directory, L"guest64", L".dll", required - 1, result, &part) == required, 3);
	CHECK(result[0] == '!', 4);
	CHECK(SearchPathW(directory, L"GUEST64", L".dll", required, result, &part) == required - 1, 5);
	CHECK(result[required - 1] == 0 && part >= result && part < result + required, 6);
	CHECK(equal(part, L"guest64.dll"), 7);
	CHECK(SearchPathW(0, L"guest64.dll", L".ignored", 2048, explicitResult, &part) == required - 1, 8);
	CHECK(equal(result, explicitResult), 9);
	CHECK(SearchPathW(L"Z:\\does-not-exist", result, 0, 2048, explicitResult, &part) == required - 1, 10);
	CHECK(equal(result, explicitResult), 11);
	void *file = CreateFileW(result, 0x80000000UL, 7, 0, 3, 0, 0);
	CHECK(file != (void *)-1, 14);
	DWORD finalSize = GetFinalPathNameByHandleW(file, 0, 0, 0);
	CHECK(finalSize == required + 4, 15);
	explicitResult[0] = '!';
	CHECK(GetFinalPathNameByHandleW(file, explicitResult, finalSize - 1, 0) == finalSize, 16);
	CHECK(explicitResult[0] == '!', 17);
	CHECK(GetFinalPathNameByHandleW(file, explicitResult, finalSize, 0) == finalSize - 1, 18);
	CHECK(explicitResult[0] == '\\' && explicitResult[1] == '\\' && explicitResult[2] == '?' &&
			  explicitResult[3] == '\\' && equal(explicitResult + 4, result),
		  19);
	CHECK(GetFinalPathNameByHandleW(file, explicitResult, 2048, 4) == required - 3, 20);
	CHECK(equal(explicitResult, result + 2), 21);
	CHECK(!GetFinalPathNameByHandleW(file, explicitResult, 2048, 0x10) && GetLastError() == 87, 22);
	CHECK(CloseHandle(file), 23);
	CHECK(!GetFinalPathNameByHandleW(file, explicitResult, 2048, 0) && GetLastError() == 6, 24);
	CHECK(SearchPathW(directory, L"wibo_nonexistent_fixture.123", 0, 2048, result, 0) == 0, 12);
	CHECK(GetLastError() == 2, 13);
	file = CreateFileW(directory, 0, 7, 0, 3, 0x02000000UL, 0);
	CHECK(file != (void *)-1 && GetFileType(file) == 1, 25);
	DWORD info[13];
	CHECK(GetFileInformationByHandle(file, info) && (info[0] & 0x10), 26);
	CHECK(CloseHandle(file), 27);
	CHECK(GetVolumePathNameW(result, explicitResult, 2048) && equal(explicitResult, L"Z:\\"), 40);
	CHECK(GetVolumePathNameW(L"\\\\?\\Z:\\missing", explicitResult, 2048) && equal(explicitResult, L"\\\\?\\Z:\\"), 41);
	CHECK(GetVolumePathNameW(L"Z:\\missing", explicitResult, 3) && equal(explicitResult, L"Z:"), 42);
	CHECK(!GetVolumePathNameW(L"Z:\\missing", explicitResult, 2), 43);
	CHECK(!GetVolumePathNameW(L"", explicitResult, 2048), 44);
#ifndef WIBO_WINE_BASELINE
	CHECK(GetLastError() == 0, 59);
#endif
	const WCHAR *temporary = L"wibo_guest64_disposition.tmp";
	file = CreateFileW(temporary, 0xc0010000UL, 7, 0, 1, 0, 0);
	CHECK(file != (void *)-1, 28);
	unsigned char disposition = 1;
	CHECK(!SetFileInformationByHandle(file, 4, &disposition, 0) && GetLastError() == 87, 29);
	CHECK(SetFileInformationByHandle(file, 4, &disposition, 1), 30);
	disposition = 0;
	CHECK(SetFileInformationByHandle(file, 4, &disposition, 1), 31);
	CHECK(CloseHandle(file) && GetFileAttributesW(temporary) != 0xffffffffUL, 32);
	file = CreateFileW(temporary, 0x80000000UL, 7, 0, 3, 0, 0);
	CHECK(file != (void *)-1, 33);
	disposition = 1;
	CHECK(!SetFileInformationByHandle(file, 4, &disposition, 1) && GetLastError() == 5, 34);
	CHECK(CloseHandle(file), 35);
	file = CreateFileW(temporary, 0x10000UL, 7, 0, 3, 0, 0);
	CHECK(file != (void *)-1 && SetFileInformationByHandle(file, 4, &disposition, 1), 36);
	CHECK(CloseHandle(file) && GetFileAttributesW(temporary) == 0xffffffffUL, 37);
	file = CreateFileW(temporary, 0xc0010000UL, 7, 0, 1, 0x04000000UL, 0);
	disposition = 0;
	CHECK(file != (void *)-1 && SetFileInformationByHandle(file, 4, &disposition, 1), 38);
	CHECK(CloseHandle(file) && GetFileAttributesW(temporary) == 0xffffffffUL, 39);
	file = CreateFileW(temporary, 0xc0010000UL, 7, 0, 1, 0, 0);
	CHECK(file != (void *)-1, 45);
	DWORD beforeRename[13];
	CHECK(GetFileInformationByHandle(file, beforeRename), 55);
	CHECK(beforeRename[7] != info[7] || beforeRename[11] != info[11] || beforeRename[12] != info[12], 56);
	struct {
		unsigned char replace;
		void *root;
		DWORD nameBytes;
		WCHAR name[64];
	} renameInfo;
	const WCHAR *renamed = L"wibo_guest64_renamed.tmp";
	DWORD count = 0;
	while (renamed[count]) {
		renameInfo.name[count] = renamed[count];
		++count;
	}
#ifdef WIBO_WINE_BASELINE
	// Wine 9 converts a NUL-terminated name and ignores the supplied lengths.
	renameInfo.name[count] = 0;
#else
	renameInfo.name[count] = '!'; // The API takes a byte count, not a terminated string.
#endif
	renameInfo.replace = 0;
	renameInfo.root = 0;
	renameInfo.nameBytes = count * 2;
#ifndef WIBO_WINE_BASELINE
	CHECK(!SetFileInformationByHandle(file, 3, &renameInfo, 20) && GetLastError() == 87, 46);
#endif
	void *other = CreateFileW(renamed, 0xc0010000UL, 7, 0, 1, 0, 0);
	CHECK(other != (void *)-1 && CloseHandle(other), 47);
	CHECK(!SetFileInformationByHandle(file, 3, &renameInfo, sizeof(renameInfo)), 48);
	renameInfo.replace = 1;
	CHECK(SetFileInformationByHandle(file, 3, &renameInfo, sizeof(renameInfo)), 49);
	CHECK(GetFileAttributesW(temporary) == 0xffffffffUL && GetFileAttributesW(renamed) != 0xffffffffUL, 50);
	CHECK(GetFinalPathNameByHandleW(file, result, 2048, 0) > 0, 51);
	CHECK(GetFileInformationByHandle(file, info), 57);
	CHECK(beforeRename[7] == info[7] && beforeRename[11] == info[11] && beforeRename[12] == info[12], 58);
	DWORD end = 0;
	while (result[end])
		++end;
	CHECK(end >= count && equal(result + end - count, renamed), 52);
	disposition = 1;
	CHECK(SetFileInformationByHandle(file, 4, &disposition, 1) && CloseHandle(file), 53);
	CHECK(GetFileAttributesW(renamed) == 0xffffffffUL, 54);
	ExitProcess(0);
}
