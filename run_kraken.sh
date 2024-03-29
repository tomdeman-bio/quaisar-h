#!/bin/sh -l

#$ -o run_kraken.out
#$ -e run_kraken.err
#$ -N run_kraken
#$ -cwd
#$ -q short.q

#Import the config file with shortcuts and settings
if [[ ! -f "./config.sh" ]]; then
	cp ./config_template.sh ./config.sh
fi
. ./config.sh

# Runs the kraken classification tool which identifies the most likely taxonomic classification for the sample
#
# Usage ./run_kraken.sh sample_name pre/post(assembly) source_type(paired/R1/R2/single/assembled) run_id
#
# requires kraken/0.10.5 perl/5.12.3 (NOT!!! 5.16.1-MT or 5.22.1)
#

ml kraken/0.10.5 perl/5.12.3 krona/2.7

# Checks for proper argumentation
if [[ $# -eq 0 ]]; then
	echo "No argument supplied to $0, exiting"
	exit 1
elif [[ -z "${1}" ]]; then
	echo "Empty sample name supplied to run_kraken.sh, exiting"
	exit 1
# Gives the user a brief usage and help section if requested with the -h option argument
elif [[ "${1}" = "-h" ]]; then
	echo "Usage is ./run_kraken.sh   sample_name   assembly_relativity(pre or post)   read_type(paired,assembled, or single)   run_id"
	echo "Output is saved to in ${processed}/miseq_run_id/sample_name/kraken/assembly_relativity"
	exit 0
elif [ -z "$2" ]; then
	echo "Empty assembly relativity supplied to run_kraken.sh. Second argument should be 'pre' or 'post' (no quotes). Exiting"
	exit 1
elif [ -z "$3" ]; then
	echo "Empty read types supplied to run_kraken.sh. Third argument should be 'paired','single', or 'assembled' (no quotes). Exiting"
	exit 1
elif [ -z "$4" ]; then
	echo "Empty project_id supplied to run_kraken.sh. Fourth argument should be the id of the miseq run. Exiting"
	exit 1
fi

# Sets the parent output folder as the sample name folder in the processed samples folder in MMB_Data
OUTDATADIR="${processed}/${4}/${1}"

# Creates folder for output from kraken
if [ ! -d "$OUTDATADIR/kraken" ]; then
	echo "Creating $OUTDATADIR/kraken"
	mkdir -p "$OUTDATADIR/kraken/${2}Assembly"
elif [ ! -d "$OUTDATADIR/kraken/{2}Assembly" ]; then
	echo "Creating $OUTDATADIR/kraken/${2}Assembly"
	mkdir -p "$OUTDATADIR/kraken/${2}Assembly"
fi

#. "${shareScript}/module_changers/perl_5221_to_5123.sh"
# Prints out version of kraken
kraken --version
# Status view of run
echo "[:] Running kraken.  Output: ${1}.kraken / ${1}.classified"
# Runs kraken in paired reads mode
if [ "${3}" = "paired" ]; then
	kraken --paired --db "${kraken_mini_db}" --preload --fastq-input --threads "${procs}" --output "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.kraken" --classified-out "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.classified" "${OUTDATADIR}/trimmed/${1}_R1_001.paired.fq" "${OUTDATADIR}/trimmed/${1}_R2_001.paired.fq"
# Runs kraken in single end mode on the concatenated single read file
elif [ "${3}" = "single" ]; then
	kraken --db "${kraken_mini_db}" --preload --fastq-input --threads "${procs}" --output "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.kraken" --classified-out "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.classified ${OUTDATADIR}/FASTQs/${1}.single.fastq"
# Runs kraken on the assembly
elif [ "${3}" = "assembled" ]; then
	kraken --db "${kraken_mini_db}" --preload --threads "${procs}" --output "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.kraken" --classified-out "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.classified" "${OUTDATADIR}/Assembly/${1}_scaffolds_trimmed.fasta"
	# Attempting to weigh contigs and produce standard krona and list output using a modified version of Rich's weighting scripts (will also be done on pure contigs later)
	echo "1"
	python ${shareScript}/Kraken_Assembly_Converter_2_Exe.py -i "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.kraken"
	echo "2"
	kraken-translate --db "${kraken_mini_db}" "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.kraken" > "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.labels"
	# Create an mpa report
	echo "3"
	kraken-mpa-report --db "${kraken_mini_db}" "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.kraken" > "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_weighted.mpa"
	# Convert mpa to krona file
	echo "4"
	perl "${shareScript}/Methaplan_to_krona.pl" -p "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_weighted.mpa" -k "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_weighted.krona"
	# Create taxonomy list file from kraken file
	echo "5"
	kraken-report --db "${kraken_mini_db}" "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.kraken" > "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.list"
	# Weigh taxonomy list file
	echo "6"
	python ${shareScript}/Kraken_Assembly_Summary_Exe.py -k "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.kraken" -l "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.labels" -t "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP.list" -o "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_BP_data.list"
	# Change perl version to allow ktimporttext to work ( cant use anything but 5.12.3
	####. "${shareScript}/module_changers/perl_5221_to_5123.sh"
	# Run the krona graph generator from krona output
	echo "7"
	ktImportText "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_weighted.krona" -o "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}_weighted_BP_krona.html"
	# Return perl version back to 5.22.1
#	. "${shareScript}/module_changers/perl_5123_to_5221.sh"
	# Runs the extractor for pulling best taxonomic hit from a kraken run
	echo "8"
	"${shareScript}/best_hit_from_kraken.sh" "${1}" "${2}" "${3}_BP_data" "${4}"
else
	echo "Argument combination is incorrect"
	exit 1
fi

# Run the metaphlan generator on the kraken output
echo "[:] Generating metaphlan compatible report."
kraken-mpa-report --db "${kraken_mini_db}" "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.kraken" > "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.mpa"
# Run the krona generator on the metaphlan output
echo "[:] Generating krona output for ${1}."
# Convert mpa to krona file
perl "${shareScript}/Methaplan_to_krona.pl" -p "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.mpa" -k "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.krona"
# Change perl version to allow ktimporttext to work ( cant use anything but 5.12.3
#. "${shareScript}/module_changers/perl_5221_to_5123.sh"
# Run the krona graph generator from krona output
ktImportText "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.krona" -o "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.html"
# Return perl version back to 5.22.1
#. "${shareScript}/module_changers/perl_5123_to_5221.sh"

# Creates the taxonomy list file from the kraken output
echo "[:] Creating alternate report for taxonomic extraction"
kraken-report --db "${kraken_mini_db}" "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.kraken" > "${OUTDATADIR}/kraken/${2}Assembly/${1}_${3}.list"
# Parses the output for the best taxonomic hit
echo "[:] Extracting best taxonomic matches"
# Runs the extractor for pulling best taxonomic hit from a kraken run
"${shareScript}/best_hit_from_kraken.sh" "${1}" "${2}" "${3}" "${4}"

ml -kraken/0.10.5 -perl/5.12.3 -krona/2.7

#Script exited gracefully (unless something else inside failed)
exit 0
