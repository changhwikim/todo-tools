# Find all the currently modified lines with TODOs.
#
# TODO(riley|sergei): Flesh out docstring.

DATE_CMD='gdate'
POTENTIAL_TODOS=()

main() {
    process_changed_files < <(difiles)
    process_potential_todos
}

process_changed_files() {
    while read filename; do
        # NOTE: Added this because it would fail otherwise on a removed file.
        # TODO(sergei): Remove this comment :P
        if [ -f $filename ]; then
            lines=$(get_changed_lines "$filename")
            process_lines "$lines"
        fi
    done
}

get_changed_lines() {
    git diff HEAD "$1" \
        | grep '^+' \
        | grep -v '^+++ ' \
        | sed -e 's/^+//'
}

process_lines() {
    lines="$1"
    while read line; do
        # If this matches, we're pretty confident that it's a comment so we
        # print and process it for saving.
        grep -q '[#(//)] TODO[\(:]' <<< "$line"
        found_match=$?

        if [ $found_match -eq 0 ]; then
            maybe_print_header
            output "$filename" "$line"
            save_todo "$filename" "$line"

        # If the above doesn't match, there's still a chance that it's a TODO.
        # We run it through a more permissive filter; if *that* matches we
        # prompt the user for input.
        elif [[ $line =~ "TODO" ]]; then
            # NOTE: Appending to global arrays must happen in the main process.
            # If this is ever refactored, make sure that this function is not
            # in a subshell.
            POTENTIAL_TODOS+=("$(output "$filename" "$line")")
        fi
    done < <(echo "$lines")
}

is_first_todo=true
maybe_print_header() {
    if [ "$is_first_todo" = true ]; then
        echo -e "Here's a list of TODOs you added in this commit:"
        echo -e "------------------------------------------------"
        is_first_todo=false
    fi
}

output() {
    filename=$1
    line=$2
    echo -e "+ $filename | $line"
}

save_todo() {
    filename=$1
    todo=$2
    date_pattern="TODO\([^\)\[]*\[(.*)\]\):?\ *(.*)"

    shopt -s nocasematch
    if [[ $todo =~ $date_pattern ]]; then
        date="${BASH_REMATCH[1]}"
        line="${BASH_REMATCH[2]}"
        formatted_date=$("$DATE_CMD" --iso-8601 --date "$date")
        echo "$formatted_date  |  $filename  |  $line" >> ~/.todos
    fi
}

is_first_potential_todo=true
process_potential_todos() {
    for file_and_line in "${POTENTIAL_TODOS[@]}"; do
        if [ "$is_first_potential_todo" = true ]; then
            echo -e "\nThese might be TODOs.  Did you mean to do them?"
            echo -e "-----------------------------------------------"
            is_first_potential_todo=false
        fi
        echo "$file_and_line"
    done
}

difiles () {
    git status --porcelain | awk '{print $2}'
}

main $*
