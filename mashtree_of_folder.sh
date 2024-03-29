#!/bin/sh -l

#$ -o mashfolder.out
#$ -e mashdfolder.err
#$ -N mashfolder
#$ -cwd
#$ -q short.q

#Import the config file with shortcuts and settings
if [[ ! -f "./config.sh" ]]; then
	cp config_template.sh config.sh
fi
. ./config.sh

# Load necessary modules to run mashtree
#module unload perl/5.22.1
#module load perl/5.16.1-MT
#Switiching to ml syntax
ml -perl/5.22.1 perl/5.16.1-MT mashtree/0.29

#
# Script to create mashtree of specified isolates that were processed by Quaisar pipeline
#
# Usage ./mashtree_of_folder.sh -f path_to_assemblies -o output_filename -e extension_of_files_to_process
#

#  Function to print out help blurb
show_help () {
	echo "Usage is ./mashtree_of_folder.sh -f path_to_folder -o output_filename -e extension_of_fasta_files"
	echo "Output is saved to path_to_folder"
}

options_found=0
while getopts ":h?n:p:" option; do
	options_found=$(( options_found + 1 ))
	case "${option}" in
		\?)
			echo "Invalid option found: ${OPTARG}"
      show_help
      exit 0
      ;;
		f)
			echo "Option -f triggered, argument = ${OPTARG}"
			DATADIR=${OPTARG};;
		p)
			echo "Option -o triggered, argument = ${OPTARG}"
			outfile=${OPTARG};;
		e)
			echo "Option -e triggered, argument = ${OPTARG}"
			extension=${OPTARG};;
		:)
			echo "Option -${OPTARG} requires as argument";;
		h)
			show_help
			exit 0
			;;
	esac
done

if [[ "${options_found}" -eq 0 ]]; then
	echo "No options found"
	show_help
	exit
fi

# Call mashtree on all copied fasta
cd ${DATADIR}
mashtree.pl --numcpus ${procs} *.${extension} --tempdir ${DATADIR}/temp > "${DATADIR}/${outfile}.dnd";

module unload perl/5.16.1-MT
module load perl/5.22.1

exit
