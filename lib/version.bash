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

# Version information

# !!! IMPORTANT !!!
# Increment this version number if you change the layout of the databases.
DB_VERSION=2

versionfile="${datadir}/version"

# Get the version of the databases.
# If the version file does not exist,
# create it and set it to the current version.
db_version() {
   if [ -e "${versionfile}" ]; then
      cat "${versionfile}"
   else
      echo "${DB_VERSION}" | tee "${versionfile}"
   fi
}

# Update the version file.
set_db_version() {
   echo "Upgraded databases to v$1!" >&2
   echo "$1" > "${versionfile}"
   git_append_msg "Upgraded databases to $1"
}

# For testing purposes/template
upgrade_v0() {
   set_db_version "1"
}

# Upgrade from v1 to v2.
# This upgrade replaced the total field with a price.
upgrade_v1() {
   local transactions new_trans new_csv csv_entry num price total IFS
   local TID CID date desc

   csv_read "${tdb_file}" transactions
   transactions="$(echo "${transactions}" | tr '\n' '=')"

   new_trans=""
   
   IFS='='
   for csv_entry in ${transactions}; do
      TID="$(echo "${csv_entry}" | cut -d',' -f1)"
      CID="$(echo "${csv_entry}" | cut -d',' -f2)"
      date="$(echo "${csv_entry}" | cut -d',' -f3)"
      num="$(echo "${csv_entry}" | cut -d',' -f4)"
      total="$(echo "${csv_entry}" | cut -d',' -f5)"
      desc="$(echo "${csv_entry}" | cut -d',' -f6)"
      price="$(echo "scale=2; ${total} / ${num}" | bc)"

      new_csv="${TID},${CID},${date},${num},${price},${desc}"
      new_trans+="${new_csv}="
   done

   csv_write "${tdb_file}" "$(echo "${new_trans}" | tr '=' '\n')"

   set_db_version "2"
}

declare -a upgrade_funcs
upgrade_funcs[0]=upgrade_v0
upgrade_funcs[1]=upgrade_v1

# Checks the version of this program with the version the databases were created with.
check_version() {
   local i resp ver="$(db_version)"

   if [ "${ver}" -lt "${DB_VERSION}" ]; then
      echo "The databases were created with an older version of this program." >&2
      printf "%s" "Would you like to try to upgrade them automatically? " >&2
      read -r resp
      [ "${resp}" = "y" ] || exit 0

      # TODO: add git notice (git decribe --always)

      for (( i = ${ver}; i != ${DB_VERSION}; i++ )); do
         if [ "${upgrade_funcs[$ver]}" ]; then
            eval "${upgrade_funcs[$ver]}"
         else
            echo "Automatic upgrading from v${ver} to $((ver + 1)) is not supported!" >&2
            error "Please look into the documentation how to manually do the upgrade."
         fi
      done

      # Check again
      check_version
   elif [ "${ver}" -gt "${DB_VERSION}" ]; then
      error "The databases were created with a newer version of this program, please update to the latest version."
   fi
}
