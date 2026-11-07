typedef unsigned long DWORD;
typedef unsigned long long UINT_PTR;
typedef void *HANDLE;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) HANDLE CreateThread(void *, UINT_PTR, DWORD (*)(void *), void *, DWORD, DWORD *);
__declspec(dllimport) DWORD WaitForSingleObject(HANDLE, DWORD);
__declspec(dllimport) int GetExitCodeThread(HANDLE, DWORD *);
__declspec(dllimport) int CloseHandle(HANDLE);
static DWORD worker(void *argument) {
	UINT_PTR teb;
	__asm__("movq %%gs:0x30, %0" : "=r"(teb));
	UINT_PTR stack = (UINT_PTR)&teb;
	if (stack >= *(UINT_PTR *)(teb + 8) || stack < *(UINT_PTR *)(teb + 16))
		return 1;
	return argument == (void *)0x1122334455667788ULL ? 123 : 2;
}
void mainCRTStartup(void) {
	HANDLE thread = CreateThread(0, 0, worker, (void *)0x1122334455667788ULL, 0, 0);
	if (!thread || WaitForSingleObject(thread, 10000) != 0)
		ExitProcess(3);
	DWORD status;
	if (!GetExitCodeThread(thread, &status) || status != 123)
		ExitProcess(4);
	if (!CloseHandle(thread))
		ExitProcess(5);
	ExitProcess(0);
}
