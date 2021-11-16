#  Copyright (C) 2021 Benjamin Stürz
#
#  This file is part of the accounthing project.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.

### Read/Write encrypted CSV databases

# Check if $datadir is set.
[[ -z ${datadir} ]] && error "\${datadir} is not defined"

# Checks if $1 is a valid CSV ID.
# Exit Code:
#   0 - Valid
#   1 - Invalid
csv_is_ID() {
   grep -q '^[0-9]\{3\}$' <<< "$1"
}

if [[ ${enable_caching} == 'true' ]]; then

   declare -A csv_cache

   # Read an encrypted CSV database.
   # Arguments:
   #   $1 - name of the database
   #   $2 - variable to store the data in
   csv_read() {
      local csv_data
      if [[ ${csv_cache[$1]} ]]; then
         debug "Cache Hit ($1)"
         csv_data="${csv_cache[$1]}"
      else
         debug "Cache Miss ($1)"
         decrypt "${datadir}/${1}.csv" csv_data
         csv_cache["$1"]="${csv_data}"
      fi

      [[ ${#2} -ne 0 ]] && eval "${2}='${csv_data}'" || echo "${csv_data}"
   }
   
   # Write an encrypted CSV database.
   # Arguments:
   #   $1 - name of the database
   #   $2 - new data
   csv_write() {
      local tmp_data
      tmp_data="$(sed '/^\s*$/d' <<< "$2")"
      mkdir -p "${datadir}" || error "failed to create ${datadir}"
      encrypt "${datadir}/${1}.csv" <<< "${tmp_data}" || error "failed to update '$1'"
      csv_cache["$1"]="${tmp_data}"
   }

else

   # Read an encrypted CSV database.
   # Arguments:
   #   $1 - name of the database
   #   $2 - variable to store the data in
   csv_read() {
      local csv_data
      decrypt "${datadir}/${1}.csv" csv_data
      [[ ${#2} -ne 0 ]] && eval "${2}='${csv_data}'" || echo "${csv_data}"
   }
   
   # Write an encrypted CSV database.
   # Arguments:
   #   $1 - name of the database
   #   $2 - new data
   csv_write() {
      mkdir -p "${datadir}" || error "failed to create ${datadir}"
      encrypt "${datadir}/${1}.csv" <<< "$2" || error "failed to update '$1'"
   }

fi

# Append to an encrypted CSV database.
# Arguments:
#   $1 - See: csv_read()
#   $2 - text to be appended
csv_append() {
   local append_data
   csv_read "$1" append_data
   append_data="$(printf "%s\n%s" "${append_data}" "$2")"
   csv_write "$1" "${append_data}"
}

# Search for an entry in a CSV database.
# Arguments:
#   $1 - See: csv_read()
#   $2 - search regex
#   $3 - '-v' (optional)
#   $4 - out
# Returns:
#   The corresponding entry in the database in CSV format.
# Exit Code:
#   0 - Entry found
#   1 - No such entry
csv_search() {
   local arg db csv_search_results

   arg="--"
   [[ $3 ]] && arg="$3"

   csv_read "$1" db
   csv_search_results="$(grep "${arg}" "$2" <<< "${db}")"
   [[ ${#4} -ne 0 ]] && eval "${4}='${csv_search_results}'" || echo "${csv_search_results}"
}

# Search for the next available ID.
# IDs are always 3 digits long.
# Arguments:
#   $1 - file
#   $2 - out
csv_next_ID() {
   local csv
   csv_read "$1" csv
   local ID="$(cut -d',' -f1 <<< "${csv}" | sort | tail -n1)"
   [[ -z ${ID} ]] && ID="001" || ID="$(increment_ID "${ID}" 3)"
   [[ ${#2} -ne 0 ]] && eval "${2}='${ID}'" || echo "${ID}"
}

# Get an entry from a CSV-line
# Arguments:
#   $1 - CSV entry
#   $2 - num
#   $3 - out
csv_get() {
   local tmp
   tmp="$(cut -d',' -f"$2" <<< "$1")"
   [[ ${#3} -ne 0 ]] && eval "${3}='${tmp}'" || echo "${tmp}"
}
