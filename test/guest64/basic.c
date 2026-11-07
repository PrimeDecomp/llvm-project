typedef unsigned long long UINT_PTR;
typedef unsigned long DWORD;
typedef void *HANDLE;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) HANDLE GetModuleHandleA(const char *name);
__declspec(dllimport) void *GetProcAddress(HANDLE module, const char *name);
__declspec(dllimport) HANDLE GetStdHandle(DWORD which);
__declspec(dllimport) int WriteFile(HANDLE file, const void *buffer, DWORD size, DWORD *written, void *overlapped);
__declspec(dllimport) void *VirtualAlloc(void *address, UINT_PTR size, DWORD type, DWORD protect);
__declspec(dllimport) int VirtualFree(void *address, UINT_PTR size, DWORD type);
__declspec(dllimport) DWORD TlsAlloc(void);
__declspec(dllimport) int TlsSetValue(DWORD index, void *value);
__declspec(dllimport) void *TlsGetValue(DWORD index);
__declspec(dllimport) int TlsFree(DWORD index);
#define CHECK(expr, code)                                                                                              \
	do {                                                                                                               \
		if (!(expr))                                                                                                   \
			ExitProcess(code);                                                                                         \
	} while (0)
void mainCRTStartup(void) {
	UINT_PTR teb;
	__asm__("movq %%gs:0x30, %0" : "=r"(teb));
	CHECK(teb != 0 && *(UINT_PTR *)(teb + 0x30) == teb, 1);
	CHECK(*(UINT_PTR *)(teb + 0x60) != 0, 2);
	UINT_PTR stack = (UINT_PTR)&teb;
	CHECK(stack < *(UINT_PTR *)(teb + 8) && stack >= *(UINT_PTR *)(teb + 16), 3);
	HANDLE module = GetModuleHandleA(0);
	CHECK((UINT_PTR)module > 0xffffffffULL, 4);
	HANDLE kernel = GetModuleHandleA("kernel32.dll");
	CHECK(kernel && GetProcAddress(kernel, "WriteFile"), 5);
	void *memory = VirtualAlloc((void *)0x200000000ULL, 0x10000, 0x3000, 4);
	CHECK(memory == (void *)0x200000000ULL, 6);
	*(UINT_PTR *)memory = 0x123456789abcdef0ULL;
	CHECK(*(UINT_PTR *)memory == 0x123456789abcdef0ULL, 7);
	DWORD slot = TlsAlloc();
	CHECK(slot != 0xffffffffUL && TlsSetValue(slot, memory), 8);
	CHECK(TlsGetValue(slot) == memory && TlsFree(slot), 9);
	CHECK(VirtualFree(memory, 0, 0x8000), 10);
	const char text[] = "Win64 guest passed\n";
	DWORD written = 0;
	CHECK(WriteFile(GetStdHandle((DWORD)-11), text, sizeof(text) - 1, &written, 0), 11);
	CHECK(written == sizeof(text) - 1, 12);
	ExitProcess(0);
}
