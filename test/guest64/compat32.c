__declspec(dllimport) __declspec(noreturn) void __stdcall ExitProcess(unsigned int code) __asm__("_ExitProcess");
void mainCRTStartup(void) {
	volatile unsigned int a = 0x12345678;
	volatile unsigned int b = 0x11111111;
	ExitProcess(a + b == 0x23456789 ? 0 : 1);
}
