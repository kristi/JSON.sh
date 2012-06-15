
throw () {
  echo "$*" >&2
  exit 1
}

tokenize () {
  local ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
  local CHAR='[^[:cntrl:]"\\]'
  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'
  egrep -ao "$STRING|$NUMBER|$KEYWORD|$SPACE|." --color=never |
    egrep -v "^$SPACE$"  # eat whitespace
}

parse_array () {
  local index=0
  local ary=''
  read -r token
  case "$token" in
    ']') ;;
    *)
      while :
      do
        parse_value "$1" "$index"
        let index=$index+1
        ary="$ary""$value" 
        read -r token
        case "$token" in
          ']') break ;;
          ',') ary="$ary," ;;
          *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
      ;;
  esac
  value=`printf '[%s]' "$ary"`
}

parse_object () {
  local key
  local obj=''
  read -r token
  case "$token" in
    '}') ;;
    *)
      while :
      do
        case "$token" in
          '"'*'"') key=$token 
              [ "$strip_quotes" = "true" ] && key=${key:1:${#key}-2}
              ;;
          *) throw "EXPECTED string GOT ${token:-EOF}" ;;
        esac
        read -r token
        case "$token" in
          ':') ;;
          *) throw "EXPECTED : GOT ${token:-EOF}" ;;
        esac
        read -r token
        parse_value "$1" "$key"
        obj="$obj$key:$value"        
        read -r token
        case "$token" in
          '}') break ;;
          ',') obj="$obj," ;;
          *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
    ;;
  esac
  value=`printf '{%s}' "$obj"`
}

parse_value () {
  local jpath="${1:+$1$pathsep}$2"
  case "$token" in
    '{') parse_object "$jpath" ;;
    '[') parse_array  "$jpath" ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[^0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
    *) value=$token ;;
  esac
  printf "$left%s$right$delim%s\n" "$jpath" "$value"
}

parse () {
  read -r token
  parse_value
  read -r token
  case "$token" in
    '') ;;
    *) throw "EXPECTED EOF GOT $token" ;;
  esac
}

if [ $0 = $BASH_SOURCE ];
then
  # Usage example:
  # echo '{"name":"apple","properties":{"color":"red","round":"true"}}' |
  #   ./JSON.sh --delimiter "=" --bracket "()" --strip-quotes --pathsep "/"
  # Default options
  delim="\t"
  pathsep=","
  left="["
  right="]"
  strip_quotes="false"
  while [ "${1:0:1}" = "-" ]
  do
    case "$1" in
      -d|--delimiter) shift; delim="$1" ;;
      -b|--bracket) shift; left="${1:0:1}"; right="${1:${#1}-1:1}" ;;
      -p|--path-sep) shift; pathsep="$1" ;;
      --strip-quotes) strip_quotes="true" ;;
      *) echo "Skipping unrecognized option '$1'" >&2
    esac
    shift;
  done
  tokenize | parse
fi
