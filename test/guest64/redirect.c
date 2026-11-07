typedef unsigned long DWORD;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) void *GetStdHandle(DWORD which);
__declspec(dllimport) int WriteFile(void *file, const void *data, DWORD length, DWORD *written, void *overlapped);
__declspec(dllimport) DWORD SetFilePointer(void *file, long distance, long *high, DWORD method);
void mainCRTStartup(void) {
	void *file = GetStdHandle((DWORD)-11);
	DWORD written = 0;
	if (!WriteFile(file, "ABC", 3, &written, 0) || written != 3)
		ExitProcess(1);
	if (SetFilePointer(file, 0, 0, 0) != 0)
		ExitProcess(2);
	if (!WriteFile(file, "Z", 1, &written, 0) || written != 1)
		ExitProcess(3);
	ExitProcess(0);
}
