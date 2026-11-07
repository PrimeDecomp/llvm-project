typedef unsigned long DWORD;
typedef unsigned long long UINT_PTR;
static const UINT_PTR value = 0xfedcba9876543210ULL;
static const UINT_PTR *volatile relocated = &value;
static DWORD attached;
int _fltused;
UINT_PTR CheckArguments(UINT_PTR a, UINT_PTR b, UINT_PTR c, UINT_PTR d, UINT_PTR e, UINT_PTR f) {
	return attached == 1 && *relocated == value ? a + 3 * b + 5 * c + 7 * d + 11 * e + 13 * f : 0;
}
double CheckFloats(double a, double b, double c, double d, double e) { return a + 2 * b + 3 * c + 4 * d + 5 * e; }
UINT_PTR CheckCallback(UINT_PTR (*callback)(UINT_PTR, UINT_PTR), UINT_PTR x) { return callback(x, *relocated); }
int DllMain(void *module, DWORD reason, void *reserved) {
	(void)module;
	(void)reserved;
	if (reason == 1)
		attached++;
	return 1;
}
