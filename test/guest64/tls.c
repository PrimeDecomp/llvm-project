typedef unsigned long DWORD;
typedef unsigned long long UINT_PTR;
__declspec(dllimport) void ExitProcess(unsigned int code);
#pragma section(".tls", read, write)
#pragma section(".tls$ZZZ", read, write)
#pragma section(".rdata$T", read)
__declspec(allocate(".tls")) char tlsStart;
__declspec(thread) int tlsValue = 0x12345678;
__declspec(allocate(".tls$ZZZ")) char tlsEnd;
DWORD _tls_index;
static int called;
static void tlsCallback(void *module, DWORD reason, void *reserved) {
	(void)module;
	(void)reserved;
	if (reason == 1) {
		++tlsValue;
		++called;
	}
}
static void (*callbacks[])(void *, DWORD, void *) = {tlsCallback, 0};
struct TLS_DIRECTORY {
	const void *start;
	const void *end;
	DWORD *index;
	const void *callbacks;
	DWORD zeroFill;
	DWORD characteristics;
};
__declspec(allocate(".rdata$T"))
const struct TLS_DIRECTORY _tls_used = {&tlsStart, &tlsEnd, &_tls_index, callbacks, 0, 0};
void mainCRTStartup(void) { ExitProcess(tlsValue == 0x12345679 && called == 1 ? 0 : 1); }
