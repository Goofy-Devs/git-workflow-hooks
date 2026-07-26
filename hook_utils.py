# Set up colors for colored text and highlights
HIGHLIGHTS = { 
    "reverse": "\033[7m",        
}
COLORS = {
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
}
TEXT_RESET = "\033[0m"
def color_text(text, color_code):
    return f"{color_code}{text}{TEXT_RESET}"

# Set up vars for message statuses
INFO = color_text("[INFO]", COLORS.get("green", ''))
WARNING = color_text("[WARNING]", COLORS.get("yellow", ''))
ERROR = color_text("[ERROR]", COLORS.get("red", ''))

# Set up indent/padding
PAD_INFO = " " * len(INFO)
PAD_WARNING = " " * len(WARNING)
PAD_ERROR = " " * len(ERROR)
INDENT = "    "