typedef unsigned long DWORD;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) void *GetStdHandle(DWORD which);
__declspec(dllimport) int WriteFile(void *file, const void *data, DWORD length, DWORD *written, void *overlapped);
__declspec(dllimport) DWORD SetFilePointer(void *file, long distance, long *high, DWORD method);
typedef struct {
	short x, y;
} Coord;
typedef struct {
	short left, top, right, bottom;
} Rect;
typedef struct {
	Coord size, cursor;
	unsigned short attributes;
	Rect window;
	Coord maximum;
} ConsoleInfo;
__declspec(dllimport) int GetConsoleMode(void *file, DWORD *mode);
__declspec(dllimport) int GetConsoleScreenBufferInfo(void *file, ConsoleInfo *info);
__declspec(dllimport) DWORD GetLastError(void);
void mainCRTStartup(void) {
	void *file = GetStdHandle((DWORD)-11);
	DWORD written = 0;
	DWORD mode;
	ConsoleInfo info;
	if (GetConsoleMode(file, &mode) || GetLastError() != 6)
		ExitProcess(4);
	if (GetConsoleScreenBufferInfo(file, &info) || GetLastError() != 6)
		ExitProcess(5);
	if (GetConsoleMode((void *)-1, &mode) || GetLastError() != 6)
		ExitProcess(6);
	if (GetConsoleScreenBufferInfo((void *)-1, &info) || GetLastError() != 6)
		ExitProcess(7);
	if (!WriteFile(file, "ABC", 3, &written, 0) || written != 3)
		ExitProcess(1);
	if (SetFilePointer(file, 0, 0, 0) != 0)
		ExitProcess(2);
	if (!WriteFile(file, "Z", 1, &written, 0) || written != 1)
		ExitProcess(3);
	ExitProcess(0);
}
