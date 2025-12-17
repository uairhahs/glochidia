#!/bin/bash
# fix-gnuc.sh - Automated C source patching for musl compatibility

SOURCE_DIR="$1"

if [[ -z ${SOURCE_DIR} ]]; then
	echo "Usage: $0 <path/to/source/dir>"
	exit 1
fi

echo "--- Patching Source Files in ${SOURCE_DIR} for musl/C99 compatibility ---"

# --- Patch 1: Remove old 'extern char *getenv ()' declarations ---
# This line conflicts with the modern declaration in stdlib.h.
echo "  -> Applying patch for getenv()."
while IFS= read -r -d $'\0' file; do
	echo "     Processing ${file}"
	# Use multiple sed patterns to handle variations in whitespace
	sed -i '/extern[[:space:]]*char[[:space:]]*\*[[:space:]]*getenv[[:space:]]*([[:space:]]*)/d' "${file}"
	echo "     Patched ${file}"

	# For getopt.c, we need to explicitly add stdlib.h and unistd.h headers
	if [[ ${file} == *getopt.c ]]; then
		# Check if the header is already present to avoid duplicates
		if ! grep -q '#include <stdlib.h>' "${file}"; then
			# Find the line after #include <string.h> and insert our headers
			sed -i '/#include <string.h>/a #include <stdlib.h>\n#include <unistd.h>' "${file}"
			echo "     Added standard headers to ${file}"
		fi
	fi
done < <(find "${SOURCE_DIR}" -type f \( -name "getopt.c" -o -name "fnmatch.c" -o -name "getopt1.c" \) -print0 || true)

# --- Patch 2: Remove old 'extern int getopt ()' declarations from headers ---
# This conflicts with the new full prototype.
echo "  -> Applying patch for getopt() declarations in headers."
while IFS= read -r -d $'\0' file; do
	sed -i '/extern int getopt ();/d' "${file}"
	echo "     Patched ${file}"
done < <(find "${SOURCE_DIR}" -type f -name "getopt.h" -print0 || true)

# --- Patch 3: Convert old-style C function definitions to modern style (for getopt) ---
# This fixes the "expected identifier or (" errors.
echo "  -> Converting old-style function signatures (getopt)."
while IFS= read -r -d $'\0' file; do
	# 1. Find the old C style definition pattern (e.g., 'getopt (argc, argv, optstring)')
	# 2. Replace it with the modern ANSI C definition: 'int getopt(int argc, char *const *argv, const char *optstring)'
	# 3. Clean up the old redundant parameter declarations below it (int argc;, etc.)

	# NOTE: This substitution is complex and varies. For now, we only clean the signature.
	# The previous manual fix in make was to delete the redundant variable lines below the new definition.
	# We will rely on manual cleaning for the signature for maximum safety, but delete the redundant variables.

	# Simple substitution to find and remove vestigial old parameter lines (int argc;, etc.)
	sed -i '/int argc;/d' "${file}"
	sed -i '/char \*const \*argv;/d' "${file}"
	sed -i '/const char \*optstring;/d' "${file}"
	echo "     Cleaned redundant C-style parameter declarations in ${file}"
done < <(find "${SOURCE_DIR}" -type f -name "getopt.c" -print0 || true)

# --- Patch 4 (Address Fix): Fix incompatible function pointer casting in io.c (gawk/musl issue) ---
echo "  -> Applying address-based patch for io.c (most reliable)."

while IFS= read -r -d $'\0' file; do
	# 1. Fix the assignment (Line 3389): Replace the entire line content.
	sed -i '3389s/.*/        iop->public.read_func = read;/' "${file}"

	# 2. Fix the comparison (Line 4449): Replace the entire line content.
	sed -i '4449s/.*/        if ((iop->public.read_func == read) \&\& tmout > 0)/' "${file}"

	echo "     Patched ${file} (Lines 3389, 4449 fixed)"
done < <(find "${SOURCE_DIR}" -type f -name "io.c" -print0 || true)

echo "--- Patching complete ---"
