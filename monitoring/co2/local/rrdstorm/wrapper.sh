#!/bin/bash
####################################################################
# rrdstorm decomposed - main wrapper
#
# Structure:
#   config.sh  - all static definitions (RRDcFILE, RRDcDEF, RRDuSRC,
#                RRDgUM, RRDgLIST, RRDgGRAPH)
#   data/<N>-<name>.sh  - data extraction, outputs colon-separated
#                         values to stdout. Testable independently:
#                           ./data/0-load.sh  -> 0.15:0.10:0.05
#   defs/<N>-<name>.sh  - rrdtool DEF definitions, one per data
#                         source. Uses $RRD placeholder substituted
#                         at runtime.
#
# Usage:
#   wrapper.sh create   0 1 2 3 4 5 6 7 8 9  - create databases + HTML
#   wrapper.sh update   0 1 2 3 4 5 6 7 8 9  - update RRD databases
#   wrapper.sh graph    0 1 2 3 4 5 6 7 8 9  - generate all graphs
#   wrapper.sh graph_cron s 0 1 ...           - one time-range graph
#   wrapper.sh graph_cron h 0 1 ...          - 4h graph
#   wrapper.sh graph_cron d 0 1 ...          - 24h graph
#   wrapper.sh graph_cron w 0 1 ...          - weekly graph
#   wrapper.sh graph_cron m 0 1 ...          - monthly graph
#   wrapper.sh graph_cron y 0 1 ...          - yearly graph
#   wrapper.sh help
#
####################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

DATADIR="${SCRIPT_DIR}/data"
DEFSDIR="${SCRIPT_DIR}/defs"

####################################################################
# functions
####################################################################

CreateRRD()
{
    echo "$RRDTOOL" create "$1" --step "$2" $3
    "$RRDTOOL" create "$1" --step "$2" $3
}

# $1 = N (source index)
# $2 = P (graph index)
# $3 = RRDFILE
# $4 = M (minute)
# $5 = H (hour)
# $6 = MODE ("visual" or "cron")
CreateGraph()
{
    local N="$1"
    local P="$2"
    local RRDFILE="$3"
    local M="$4"
    local H="$5"
    local MODE="${6:-visual}"

    [ -z "${RRDgGRAPH[$P]}" ] && return

    local BACK IMGBASE TITLE EXTRA COND

    BACK=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f1)
    IMGBASE=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f2)
    TITLE=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f3)
    if [ "$MODE" = "visual" ]; then
        TITLE="${TITLE} @ \"${H}\":\"${M}\""
    fi
    EXTRA=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f5)
    COND=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f4)

    if [ ! -z "$FORCEGRAPH" ]; then
        RET=1
    elif [ -z "$COND" ]; then
        RET=1
    else
        COND="if ${COND}; then RET=1; else RET=0; fi"
        eval "$COND"
    fi

    [ "$RET" != 1 ] && return

    echo "Making graph (${N}:${P}) ${RRDOUTPUT}/${IMGBASE}.svg .."

    local DEF_FILE
    DEF_FILE="${DEFSDIR}/${N}-${FILEBASE}.sh"

    [ -f "$DEF_FILE" ] || { echo "DEF file not found: ${DEF_FILE}" >&2; return 1; }

    GRAPH_ARGS=()
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        line="${line//\$RRD/$RRDFILE}"
        GRAPH_ARGS+=("$line")
    done < "$DEF_FILE"

    # Build extra args matching original order:
    #   graph imgfile [extra --graph-render-mode normal] --color ... -M -a SVG ...
    local ALL_EXTRA=()
    if [ -n "$EXTRA" ]; then
        eval "EXTRA_ARGS=($EXTRA)"
        ALL_EXTRA+=("${EXTRA_ARGS[@]}")
    fi
    if [ "$MODE" = "visual" ]; then
        ALL_EXTRA+=("--graph-render-mode" "normal")
    fi
    ALL_EXTRA+=("--color" "CANVAS#000000" "--color" "FONT#FFFFFF" "--color" "BACK#000000")

    "$RRDTOOL" graph "${RRDOUTPUT}/${IMGBASE}.svg" \
        "${ALL_EXTRA[@]}" \
        -M -a SVG -s "-${BACK}" -e -20 -w 550 -h 240 \
        -v "${RRDgUM[$N]}" -t "$TITLE" \
        "${GRAPH_ARGS[@]}"
}

####################################################################
# main code
####################################################################

COMMAND="${1:-help}"
case "$COMMAND" in
    help)
        echo "Usage: wrapper.sh {create|update|graph|graph_cron[s h d w m y]} 0 1 2 .."
        echo "graph_cron is for cron to quickly update just one graph per time range [1h=s 4h=h 24h=d 1week=w 1 month=m 1year=y]}"
        exit 0
        ;;
    "")
        echo "Usage: wrapper.sh {create|update|graph|graph_cron[s h d w m y]} 0 1 2 .."
        exit 1
        ;;
esac

if [ "$COMMAND" = "graph_cron" ]; then
    CRON_GRAPH_TIME="$2"
    shift 2
else
    shift 1
fi

MAKEINDEX=""

case "$COMMAND" in
    create)
        [ -d "$RRDOUTPUT" ] || mkdir -p "$RRDOUTPUT"
        HTMLINDEX="${RRDOUTPUT}/storj.html"
        if [ ! -f "$HTMLINDEX" ]; then
            cat > "$HTMLINDEX" <<'HTMLHEAD'
<head><title>RRDStorm</title>
    <style>body{background:white;color:black}</style></head>
    <body><h1>RRDStorm</h1><ul>
HTMLHEAD
            MAKEINDEX="yes"
        fi
        ;;
esac

DATE=$(date '+%x %R')

for N in "$@"; do
    META_FILE=$(ls "${DEFSDIR}/${N}-"*.meta 2>/dev/null | head -n 1)
    if [ ! -f "$META_FILE" ]; then
        echo "Warning: No metadata file found for index ${N}" >&2
        continue
    fi
    source "$META_FILE"

    FILEBASE=$(echo "${RRDcFILE[$N]}" | awk -F: '{print $1}')
    RRDFILE="${RRDDATA}/${FILEBASE}.rrd"

    case "$COMMAND" in
        create)
            HTMLFILE="${RRDOUTPUT}/${FILEBASE}.html"
            STEP=$(echo "${RRDcFILE[$N]}" | awk -F: '{print $2}')
            HTITLE=$(echo "${RRDcFILE[$N]}" | awk -F: '{print $3}')
            echo "Vars: HTMLFILE ${HTMLFILE}, STEP ${STEP}, HTITLE ${HTITLE}"

            [ -d "$RRDDATA" ] || mkdir -p "$RRDDATA"
            [ -f "$RRDFILE" ] || CreateRRD "$RRDFILE" "$STEP" "${RRDcDEF[$N]}"

            [ -f "$HTMLFILE" ] || {
                cat > "$HTMLFILE" <<EOF
<head><title>${HTITLE}</title>
    <style>body{background:white;color:black}</style></head>
    <body style="background-color:black;color:lightgray"><h1>${HTITLE}</h1><center>
EOF
                for P in ${RRDgLIST[$N]}; do
                    [ -z "${RRDgGRAPH[$P]}" ] && continue
                    IMGBASE=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f2)
                    echo "${P} in (${N}): <img src=\"${IMGBASE}.svg\"><br>"
                    echo "<img src=\"${IMGBASE}.svg\"><br>" >> "$HTMLFILE"
                done
                echo "</center><p>RRDStorm for ${VERSION} / ${DATE}</p></body>" >> "$HTMLFILE"

                for F in "${TIMED_DASHBOARDS[@]}"; do
                    TIMEDFILENAME=$(echo "$F" | cut -d':' -f1)
                    TIMEDFILETITLE=$(echo "$F" | cut -d':' -f2)
                    TIMEDFILESOURCES=$(echo "$F" | cut -d':' -f3)
                    DASHFILE="${RRDOUTPUT}/${TIMEDFILENAME}.html"
                    cat > "$DASHFILE" <<EOF
<head><title>${TIMEDFILETITLE}</title>
    <style>body{background:white;color:black}</style></head>
    <body style="background-color:black;color:lightgray"><h1>${TIMEDFILETITLE}</h1><center>
EOF
                    for P in ${TIMEDFILESOURCES}; do
                        HTMLFILEBASEINDEX=$(expr $P / 6)
                        DASH_META_FILE=$(ls "${DEFSDIR}/${HTMLFILEBASEINDEX}-"*.meta 2>/dev/null | head -n 1)
                        [ -f "$DASH_META_FILE" ] && source "$DASH_META_FILE"

                        [ -z "${RRDgGRAPH[$P]}" ] && continue

                        IMGBASE=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f2)
                        HTMLFILEBASE=$(echo "${RRDcFILE[$HTMLFILEBASEINDEX]}" | cut -d':' -f1)
                        echo "<a href=\"${HTMLFILEBASE}.html\"><img src=\"${IMGBASE}.svg\"></a><br>" >> "$DASHFILE"
                    done
                    echo "</center><p>RRDStorm for ${VERSION} / ${DATE}</p></body>" >> "$DASHFILE"
                done
            }

            [ ! -z "$MAKEINDEX" ] && {
                echo "<li><a href=\"${FILEBASE}.html\">${HTITLE}</a>" >> "$HTMLINDEX"
            }
            ;;

        update)
            EXTRACTOR="${DATADIR}/${N}-$(echo "${RRDcFILE[$N]}" | awk -F: '{print $1}').sh"
            if [ -f "$EXTRACTOR" ]; then
                VAL=$("${EXTRACTOR}")
                EXTRACTOR_STATUS=$?
                if [ "$EXTRACTOR_STATUS" -ne 0 ]; then
                    echo "ERROR: Extractor ${EXTRACTOR} failed with exit code ${EXTRACTOR_STATUS}" >&2
                    continue
                fi
                if [ -z "$VAL" ]; then
                    echo "Warning: Extractor ${EXTRACTOR} returned empty data. Skipping update." >&2
                    continue
                fi
                echo "Updating ($N) ${RRDFILE} with ${VAL} .."
                "${SCRIPT_DIR}/update_rrd_db.sh" "$RRDFILE" "${RRDuSRC[$N]}" "$VAL"
            else
                echo "ERROR: Data extractor not found: ${EXTRACTOR}" >&2
            fi
            ;;

        graph)
            M=$(date "+%M")
            H=$(date "+%H")
            for P in ${RRDgLIST[$N]}; do
                CreateGraph "$N" "$P" "$RRDFILE" "$M" "$H" "visual"
            done
            ;;

        graph_cron)
            M=$(date "+%M")
            H=$(date "+%H")
            case "$CRON_GRAPH_TIME" in
                s) CRON_SUB_GRAPH=0 ;;
                h) CRON_SUB_GRAPH=1 ;;
                d) CRON_SUB_GRAPH=2 ;;
                w) CRON_SUB_GRAPH=3 ;;
                m) CRON_SUB_GRAPH=4 ;;
                y) CRON_SUB_GRAPH=5 ;;
                *) exit 1 ;;
            esac
            P=$((((($N+1)*6)-6)+$CRON_SUB_GRAPH))
            CreateGraph "$N" "$P" "$RRDFILE" "$M" "$H" "cron"
            ;;

        *)
            echo "ERROR: Unknown command '${COMMAND}'. Run 'wrapper.sh help' for usage." >&2
            exit 1
            ;;
    esac
done

[ ! -z "$MAKEINDEX" ] && {
    echo "</ul><p>RRDStorm for ${VERSION} / ${DATE}</p></body>" >> "$HTMLINDEX"
}

exit 0
