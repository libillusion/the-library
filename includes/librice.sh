# Illusion Bash Extensions
# <-- COLORS -->
CReset='\033[0m' # Text Reset

# Regular Colors
CBlack='\033[0;30m'  # Black
CRed='\033[0;31m'    # Red
CGreen='\033[0;32m'  # Green
CYellow='\033[0;33m' # Yellow
CBlue='\033[0;34m'   # Blue
CPurple='\033[0;35m' # Purple
CCyan='\033[0;36m'   # Cyan
CWhite='\033[0;37m'  # White

# Bold
CBBlack='\033[1;30m'  # Black
CBRed='\033[1;31m'    # Red
CBGreen='\033[1;32m'  # Green
CBYellow='\033[1;33m' # Yellow
CBBlue='\033[1;34m'   # Blue
CBPurple='\033[1;35m' # Purple
CBCyan='\033[1;36m'   # Cyan
CBWhite='\033[1;37m'  # White

# Underline
CUBlack='\033[4;30m'  # Black
CURed='\033[4;31m'    # Red
CUGreen='\033[4;32m'  # Green
CUYellow='\033[4;33m' # Yellow
CUBlue='\033[4;34m'   # Blue
CUPurple='\033[4;35m' # Purple
CUCyan='\033[4;36m'   # Cyan
CUWhite='\033[4;37m'  # White

# Background
COn_Black='\033[40m'  # Black
COn_Red='\033[41m'    # Red
COn_Green='\033[42m'  # Green
COn_Yellow='\033[43m' # Yellow
COn_Blue='\033[44m'   # Blue
COn_Purple='\033[45m' # Purple
COn_Cyan='\033[46m'   # Cyan
COn_White='\033[47m'  # White

# High Intensity
CIBlack='\033[0;90m'  # Black
CIRed='\033[0;91m'    # Red
CIGreen='\033[0;92m'  # Green
CIYellow='\033[0;93m' # Yellow
CIBlue='\033[0;94m'   # Blue
CIPurple='\033[0;95m' # Purple
CICyan='\033[0;96m'   # Cyan
CIWhite='\033[0;97m'  # White

# Bold High Intensity
CBIBlack='\033[1;90m'  # Black
CBIRed='\033[1;91m'    # Red
CBIGreen='\033[1;92m'  # Green
CBIYellow='\033[1;93m' # Yellow
CBIBlue='\033[1;94m'   # Blue
CBIPurple='\033[1;95m' # Purple
CBICyan='\033[1;96m'   # Cyan
CBIWhite='\033[1;97m'  # White

# High Intensity backgrounds
COn_IBlack='\033[0;100m'  # Black
COn_IRed='\033[0;101m'    # Red
COn_IGreen='\033[0;102m'  # Green
COn_IYellow='\033[0;103m' # Yellow
COn_IBlue='\033[0;104m'   # Blue
COn_IPurple='\033[0;105m' # Purple
COn_ICyan='\033[0;106m'   # Cyan
COn_IWhite='\033[0;107m'  # White

# <-- EXTENSIONS -->
ERR_MISSINGARG="MissingArgument"
ERR_INVALIDARG="InvalidArgument"
ERR_INVALIDCONF="InvalidConfiguration"
ERR_MISSINGLIB="MissingLibrary"
_fmt_raise() {
  echo -e "${CBRed}${ERROR}${CReset}${CBWhite}: ${CReset}${@}"
}

_fmt_bash_stdin_exec() {
  if command -v "bat" >/dev/null; then
    bat --plain --language bash --color always
  else
    cat
  fi
}

_fmt_bash_stdin() {
  # _fmt_bash_stin - LINENUM LINENUM_MAX_VAL
  if [ -z "$1" ]; then
    _fmt_bash_stdin_exec
    return
  fi
  local lines=$(_fmt_bash_stdin_exec)
  local i
  if [[ "$1" == "-" ]]; then
    i="$((${2} - $(echo "$lines" | wc -l)))"
  elif [[ "$1" == "+" ]]; then
    i="$((${2} + 1))"
  elif [[ "$1" == "THIS_LINE" ]]; then
    for _ in $(seq 0 "$((${longest_mid:-0} - ${#i}))"); do printf ' '; done
    echo -ne "${CBRed}> ${2}  | ${line}"
    cat <<<"$lines"
    return
  fi
  [ -n "$3" ] && longest_mid="${#3}"

  while read -r line; do
    for _ in $(seq 0 "$((${longest_mid:-0} - ${#i}))"); do printf ' '; done
    echo -e "  ${CWhite}${i}${CReset}  | ${line}"
    i=$((${i} + 1))
  done <<<"$lines"
}

raise() {
  declare -n ERROR="$1"
  [ -z "$ERROR" ] && declare -n ERROR="ERR_$1"
  shift

  print_trace_src() {
    local LINENUM="$(("${#BASH_LINENO[@]}" - "${1}" - 1))"
    LINENUM="${BASH_LINENO["$LINENUM"]}"
    local SOURCEFILE="$(("${#BASH_SOURCE[@]}" - "${1}"))"
    SOURCEFILE="${BASH_SOURCE["$SOURCEFILE"]}"
    [[ "$SOURCEFILE" == "${BASH_SOURCE[0]}" ]] && return

    exec >&2
    echo -e "${CBWhite}Traceback${CReset} on line ${CBYellow}${LINENUM}${CReset} in ${CBPurple}${SOURCEFILE}${CReset}:"
    local lines
    local MAXVAL=$(($LINENUM + 3))
    if [[ "$LINENUM" != 1 ]]; then
      # Get last 2 lines
      sed -n "$(($((${LINENUM} - 3)) >= 1 ? $((${LINENUM} - 3)) : 1)),$(($((${LINENUM} - 1)) >= 1 ? $((${LINENUM} - 1)) : 1))p" "$SOURCEFILE" | _fmt_bash_stdin - ${LINENUM} $((${LINENUM} + 3))
    fi
    sed -n "${LINENUM}p" "$SOURCEFILE" | _fmt_bash_stdin THIS_LINE "$LINENUM"
    sed -n "$((${LINENUM} + 1)),$((${LINENUM} + 3))p" "$SOURCEFILE" | _fmt_bash_stdin + ${LINENUM} $((${LINENUM} + 3))
  }

  echo
  echo -e "${CBRed}======================== FATAL ERROR ========================"
  echo -e "${CBCyan}:( An exception has occured, and the program cannot continue."
  echo -e "${CBRed}============================================================="
  print_trace_src 1
  print_trace_src 2

  case "$ERROR" in
  "$ERR_MISSINGARG")
    _fmt_raise "Function ${CBGreen}${FUNCNAME[1]}${CReset} requires argument ${CBCyan}\"$1\"${CReset}."
    ;;
  "$ERR_INVALIDARG")
    _fmt_raise "Function ${CBGreen}${FUNCNAME[1]}${CReset} contains invalid argument ${CBCyan}\"${1}\"${CReset}."
    ;;
  "$ERR_MISSINGLIB")
    _fmt_raise "Missing library ${CBCyan}${1}${CReset}. Cannot proceed."
    ;;
  *)
    _fmt_raise "${1}"
    ;;
  esac

  exit 1
}

gethash() {
  # Gets a hash
  for v in "$@"; do
    echo $(cksum <<<"$v" | awk '{ print $1 }')
  done
}

# Logging functions
_log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}
_info() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${CBBlue}[ INFO ]${CReset} $@"
}
_warn() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${CBYellow}[ WARN ]${CReset} $@"
}
_debug() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${CBCyan}[ DBUG ]${CReset} $@"
}
_trace() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${CBPurple}[ TRAC ]${CReset} $@"
}
_welcometo() {
  _info "${CBWhite}Welcome to ${CReset}${CBGreen}${@}${CReset}${CBWhite}!${CReset}"
}

_add_s() {
  local -n "_input"="$1"
  if [[ "$_input" =~ ^[+-]?[0-9]+$ ]]; then
    [[ "$_input" -gt 1 ]] && echo s
    return
  else
    [[ "${#_input[@]}" -gt 1 ]] && echo s
    return
  fi
}
