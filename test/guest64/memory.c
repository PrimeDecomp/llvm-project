typedef unsigned long DWORD;
typedef unsigned long long SIZE_T;
typedef unsigned short WCHAR;
typedef struct {
	void *base;
	void *allocationBase;
	DWORD allocationProtect;
	SIZE_T regionSize;
	DWORD state;
	DWORD protect;
	DWORD type;
} MemoryInfo;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) void *VirtualAlloc(void *address, SIZE_T size, DWORD type, DWORD protect);
__declspec(dllimport) int VirtualFree(void *address, SIZE_T size, DWORD type);
__declspec(dllimport) int VirtualProtect(void *address, SIZE_T size, DWORD protect, DWORD *oldProtect);
__declspec(dllimport) SIZE_T VirtualQuery(const void *address, MemoryInfo *info, SIZE_T length);
__declspec(dllimport) int IsBadStringPtrA(const char *str, SIZE_T max);
__declspec(dllimport) int IsBadStringPtrW(const WCHAR *str, SIZE_T max);
#define CHECK(expr, code)                                                                                              \
	do {                                                                                                               \
		if (!(expr))                                                                                                   \
			ExitProcess(code);                                                                                         \
	} while (0)
void mainCRTStartup(void) {
	WCHAR text[] = {'o', 'k', 0};
#ifdef WIBO_WINE_BASELINE
	// Wine 9 returns TRUE for NULL even with zero length; Microsoft's contract returns FALSE.
	CHECK(IsBadStringPtrW(0, 0), 1);
#else
	CHECK(!IsBadStringPtrW(0, 0), 1);
#endif
	CHECK(IsBadStringPtrW(0, 1) && IsBadStringPtrW((WCHAR *)1, 1), 2);
	CHECK(!IsBadStringPtrW(text, ~(SIZE_T)0), 3);
	unsigned char *memory = VirtualAlloc((void *)0x200000000ULL, 8192, 0x3000, 4);
	CHECK(memory == (void *)0x200000000ULL, 4);
	MemoryInfo info;
	CHECK(VirtualQuery(memory, &info, sizeof(info)) == sizeof(info), 5);
	CHECK(info.base == memory && info.allocationBase == memory && info.regionSize == 8192, 6);
	CHECK(info.state == 0x1000 && info.protect == 4 && info.type == 0x20000, 7);
	DWORD oldProtect;
	CHECK(VirtualProtect(memory + 4096, 4096, 1, &oldProtect) && oldProtect == 4, 8);
	WCHAR *last = (WCHAR *)(memory + 4094);
	CHECK(!IsBadStringPtrW(last, ~(SIZE_T)0), 9);
	*last = 'x';
	CHECK(!IsBadStringPtrW(last, 1) && IsBadStringPtrW(last, 2), 10);
	CHECK(IsBadStringPtrW((WCHAR *)(memory + 4095), 1), 11);
	CHECK(VirtualQuery(memory + 4096, &info, sizeof(info)) == sizeof(info), 12);
	CHECK(info.base == memory + 4096 && info.protect == 1 && info.regionSize == 4096, 13);
	CHECK(VirtualProtect(memory + 4096, 4096, 4, &oldProtect), 14);
	CHECK(!IsBadStringPtrW((WCHAR *)(memory + 4095), 1), 15);
	CHECK(VirtualFree(memory, 0, 0x8000), 16);
	CHECK(IsBadStringPtrW(last, 1), 17);
	CHECK(VirtualQuery(memory, &info, sizeof(info)) == sizeof(info) && info.state == 0x10000, 18);
	CHECK(!IsBadStringPtrA("ok", ~(SIZE_T)0), 19);
	CHECK(!IsBadStringPtrA("", 0), 21);
#ifndef WIBO_WINE_BASELINE
	CHECK(!IsBadStringPtrA(0, 0), 22);
#endif
	CHECK(IsBadStringPtrA(0, 1) && IsBadStringPtrA((char *)memory, 1), 20);
	ExitProcess(0);
}
