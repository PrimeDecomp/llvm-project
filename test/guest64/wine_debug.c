__declspec(dllimport) void ExitProcess(unsigned int code);
typedef struct {
	unsigned char flags;
	char name[15];
} WineDebugChannel;
__declspec(dllimport) unsigned char __wine_dbg_get_channel_flags(WineDebugChannel *channel);
__declspec(dllimport) const char *__wine_dbg_strdup(const char *str);
__declspec(dllimport) int __wine_dbg_output(const char *str);
__declspec(dllimport) int __wine_dbg_header(int cls, WineDebugChannel *channel, const char *function);
#define CHECK(expr, code)                                                                                              \
	do {                                                                                                               \
		if (!(expr))                                                                                                   \
			ExitProcess(code);                                                                                         \
	} while (0)

void mainCRTStartup(void) {
	WineDebugChannel channel = {0xff, "wibotest"};
	unsigned char flags = __wine_dbg_get_channel_flags(&channel);
	CHECK(!(flags & 0xf0) && channel.flags == flags, 1);
	int header = __wine_dbg_header(3, &channel, "fixture");
	CHECK((flags & 8) ? header >= 0 : header == -1, 2);
	char text[] = "first";
	const char *first = __wine_dbg_strdup(text);
	text[0] = 'X';
	const char *second = __wine_dbg_strdup("second");
	CHECK(first != text && first[0] == 'f' && first[5] == 0, 3);
	CHECK(second[0] == 's' && second[6] == 0 && first[0] == 'f', 4);
	CHECK(__wine_dbg_output("Win64 Wine debug ") == 17, 5);
	if (flags & 8) {
		CHECK(__wine_dbg_header(3, &channel, "continuation") == 0, 6);
	}
	CHECK(__wine_dbg_output("passed\n") == 7, 7);
	ExitProcess(0);
}
