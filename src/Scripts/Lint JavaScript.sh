#!/bin/sh

# Test npm, eslint are available
# If not output infos

# Test bbresults is available
# If not output instruction

# map file,line,col,type,msg from eslint compact format
FORMAT_COMPACT="(?P<file>.+?): line (?P<line>\d+), (col (?P<col>\d+),)? (?P<type>[a-zA-z]+) - (?P<msg>.*)$"

# determine parent directory of file
DIR="$(dirname "${BB_DOC_PATH}")"

# move to current directory to provide context for npm
cd "$DIR" || { echo "Unable to 'cd \"$DIR\"'" ; exit 1 ; }

# check for eslint
hash eslint > /dev/null 2>&1 || { echo "eslint not installed" ; exit 1 ; }

# default to null config, so ESLint does its own work to find a config
ESLINTCONFIG=''
# check workspace root for GitHub Actions directory with ESLint config
if [ -n "$BB_DOC_WORKSPACE_ROOT" ] && [ -s "${BB_DOC_WORKSPACE_ROOT}/.github/linters/eslint.config.js" ]
then
	# only apply that if there's no workspace root config
	if [ ! -f "${BB_DOC_WORKSPACE_ROOT}/.eslintrc.js" ] && [ ! -f "${BB_DOC_WORKSPACE_ROOT}/eslintconfig.js" ]
	then
		# use Github Actions ESLint config
		# shellcheck disable=SC2089
		ESLINTCONFIG="-c ${BB_DOC_WORKSPACE_ROOT}/.github/linters/eslint.config.js"
		pushd "$BB_DOC_WORKSPACE_ROOT" > /dev/null 2>&1
		npm install --no-save eslint eslint-plugin-n > /dev/null 2>&1
		popd > /dev/null 2>&1
	fi
fi

# Run eslint in npm project (requires 'eslint-formatter-compact'
# Install that manually with `npm install -D eslint-formatter-compact`
# shellcheck disable=SC2086,SC2090
RESPONSE="$("$(which eslint)" $ESLINTCONFIG --format compact "$BB_DOC_PATH")"

CHARCOUNT="${#RESPONSE}"

SHORTNAME="$(basename "$BB_DOC_PATH")"

# eslint output of one character indicates no problems
if [ "$CHARCOUNT" -gt 1 ]
then
	# head (get first line only)
	# grep -c (get the count of lines starting with: BB_DOC_PATH)
	RESULT=$(echo "${RESPONSE}" | head -n 1 | grep -c "^$BB_DOC_PATH")


	if [ "$RESULT" -eq 1 ]
	then
		# notify if possible
		hash terminal-notifier >/dev/null 2>&1 && \
				(nohup terminal-notifier -title "ERROR: ESLint $SHORTNAME" -message "$(echo "${RESPONSE}" | head -n 1 | sed -E "s|${BB_DOC_PATH}:||g")" -sound sosumi >/dev/null 2>&1 &)
		# expected eslint output - pass it to bbresults
		echo "${RESPONSE}" | bbresults --pattern "$FORMAT_COMPACT"

	else
		# unexpected output - pass it to STDOUT
		echo "Oops! Perhaps eslint output has changed. Please report https://github.com/ollicle/BBEdit-ESLint/issues/"
		echo "RESPONSE ${RESPONSE}"
		echo "CHARCOUNT $CHARCOUNT"
		echo "RESULT $RESULT"
		hash terminal-notifier >/dev/null 2>&1 && \
			(nohup terminal-notifier -title 'ERROR: BBEdit ESLint' -message "See \"Unix Shell Script.log\" for \"$BB_DOC_PATH\"" -sound sosumi >/dev/null 2>&1 &)
		open -a BBEdit "$HOME/Library/Containers/com.barebones.bbedit/Data/Library/Logs/BBEdit/Unix Script Output.log" >/dev/null 2>&1
	fi

	exit 1
fi

hash terminal-notifier >/dev/null 2>&1 && \
		(nohup terminal-notifier -title "OK: ESLint $SHORTNAME" -message 'No errors.' -sound default >/dev/null 2>&1 &)
