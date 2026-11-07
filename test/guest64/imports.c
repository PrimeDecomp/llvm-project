typedef unsigned long long UINT_PTR;
__declspec(dllimport) void ExitProcess(unsigned int code);
__declspec(dllimport) UINT_PTR CheckArguments(UINT_PTR, UINT_PTR, UINT_PTR, UINT_PTR, UINT_PTR, UINT_PTR);
__declspec(dllimport) double CheckFloats(double, double, double, double, double);
__declspec(dllimport) UINT_PTR CheckCallback(UINT_PTR (*callback)(UINT_PTR, UINT_PTR), UINT_PTR);
int _fltused;
static UINT_PTR callback(UINT_PTR a, UINT_PTR b) { return a ^ b; }
void mainCRTStartup(void) {
	if (CheckArguments(1, 2, 3, 4, 5, 0x100000000ULL) != 105 + 13 * 0x100000000ULL)
		ExitProcess(1);
	if (CheckFloats(1, 2, 3, 4, 5) != 55)
		ExitProcess(2);
	if (CheckCallback(callback, 0x1122334455667788ULL) != (0x1122334455667788ULL ^ 0xfedcba9876543210ULL))
		ExitProcess(3);
	ExitProcess(0);
}
