package exigent

Key :: enum u16 {
	None         = 0,

	// --- Block 0: Basic Control (1-32) ---
	Backspace    = 8,
	Tab          = 9,
	Enter        = 13,
	Escape       = 27,
	Space        = 32,

	// --- Block 1: Alphanumeric (Matches ASCII 48-90) ---
	Zero         = 48,
	One          = 49,
	Two          = 50,
	Three        = 51,
	Four         = 52,
	Five         = 53,
	Six          = 54,
	Seven        = 55,
	Eight        = 56,
	Nine         = 57,
	A            = 65,
	B            = 66,
	C            = 67,
	D            = 68,
	E            = 69,
	F            = 70,
	G            = 71,
	H            = 72,
	I            = 73,
	J            = 74,
	K            = 75,
	L            = 76,
	M            = 77,
	N            = 78,
	O            = 79,
	P            = 80,
	Q            = 81,
	R            = 82,
	S            = 83,
	T            = 84,
	U            = 85,
	V            = 86,
	W            = 87,
	X            = 88,
	Y            = 89,
	Z            = 90,

	// --- Block 2: Modifiers & System (100-120) ---
	LShift       = 100,
	RShift       = 101,
	LCtrl        = 102,
	RCtrl        = 103,
	LAlt         = 104,
	RAlt         = 105,
	LSuper       = 106, // Win / Cmd
	RSuper       = 107, // Win / Cmd
	Menu         = 108, // Application key / Context menu key /  Keyboard "right-click"
	CapsLock     = 109,

	// --- Block 3: Navigation & Editing (200-220) ---
	Left         = 200,
	Right        = 201,
	Up           = 202,
	Down         = 203,
	PageUp       = 204,
	PageDown     = 205,
	Home         = 206,
	End          = 207,
	Insert       = 208,
	Delete       = 209,
	PrintScreen  = 210,
	ScrollLock   = 211,
	Pause        = 212,

	// --- Block 4: Function Keys (300-324) ---
	F1           = 300,
	F2           = 301,
	F3           = 302,
	F4           = 303,
	F5           = 304,
	F6           = 305,
	F7           = 306,
	F8           = 307,
	F9           = 308,
	F10          = 309,
	F11          = 310,
	F12          = 311,
	F13          = 312,
	F14          = 313,
	F15          = 314,
	F16          = 315,
	F17          = 316,
	F18          = 317,
	F19          = 318,
	F20          = 319,
	F21          = 320,
	F22          = 321,
	F23          = 322,
	F24          = 323,

	// --- Block 5: Numpad (400-420) ---
	NumLock      = 400,
	KP_0         = 401,
	KP_1         = 402,
	KP_2         = 403,
	KP_3         = 404,
	KP_4         = 405,
	KP_5         = 406,
	KP_6         = 407,
	KP_7         = 408,
	KP_8         = 409,
	KP_9         = 410,
	KP_Divide    = 411,
	KP_Multiply  = 412,
	KP_Subtract  = 413,
	KP_Add       = 414,
	KP_Enter     = 415,
	KP_Decimal   = 416,

	// --- Block 6: Punctuation (500-520) ---
	Semicolon    = 500, // ;
	Equal        = 501, // =
	Comma        = 502, // ,
	Minus        = 503, // -
	Period       = 504, // .
	Slash        = 505, // /
	Backtick     = 506, // `
	LeftBracket  = 507, // [
	Backslash    = 508, // \
	RightBracket = 509, // ]
	Apostrophe   = 510, // '

	// --- Block 7: Media & Special (600+) ---
	MediaPlay    = 600,
	MediaStop    = 601,
	MediaNext    = 602,
	MediaPrev    = 603,
	VolumeUp     = 604,
	VolumeDown   = 605,
	VolumeMute   = 606,
}
