#!/bin/sh -l

#$ -o run_kraken2.out
#$ -e run_kraken2.err
#$ -N run_kraken2
#$ -cwd
#$ -q all.q

#Import the config file with shortcuts and settings
if [[ ! -f "./config.sh" ]]; then
	cp ./config_template.sh ./config.sh
fi
. ./config.sh

# Runs the kraken2 classification tool which identifies the most likely taxonomic classification for the sample
#
# Usage ./run_kraken2.sh sample_name pre/post(assembly) source_type(paired/R1/R2/single/assembled) run_id
#
# requires kraken/2.0.0 perl/5.12.3 (NOT!!! 5.16.1-MT or 5.22.1)
#

# Checks for proper argumentation
if [[ $# -eq 0 ]]; then
	echo "No argument supplied to run_kraken2.sh, exiting"
	exit 1
elif [[ -z "${1}" ]]; then
	echo "Empty sample name supplied to run_kraken2.sh, exiting"
	exit 1
# Gives the user a brief usage and help section if requested with the -h option argument
elif [[ "${1}" = "-h" ]]; then
	echo "Usage is ./run_kraken2.sh   sample_name   assembly_relativity(pre or post)   read_type(paired,assembled, or single)   run_id"
	echo "Output is saved to in ${processed}/miseq_run_id/sample_name/kraken2/assembly_relativity"
	exit 0
elif [ -z "$2" ]; then
	echo "Empty assembly relativity supplied to run_kraken2.sh. Second argument should be 'pre' or 'post' (no quotes). Exiting"
	exit 1
elif [ -z "$3" ]; then
	echo "Empty read types supplied to run_kraken2.sh. Third argument should be 'paired','single', or 'assembled' (no quotes). Exiting"
	exit 1
elif [ -z "$4" ]; then
	echo "Empty project_id supplied to run_kraken2.sh. Fourth argument should be the id of the miseq run. Exiting"
	exit 1
fi

# Sets the parent output folder as the sample name folder in the processed samples folder in MMB_Data
OUTDATADIR="${processed}/${4}/${1}"

# Creates folder for output from kraken2
if [ ! -d "$OUTDATADIR/kraken2" ]; then
	echo "Creating $OUTDATADIR/kraken2"
	mkdir -p "$OUTDATADIR/kraken2/${2}Assembly"
elif [ ! -d "$OUTDATADIR/kraken2/${2}Assembly" ]; then
	echo "Creating $OUTDATADIR/kraken2/${2}Assembly"
	mkdir -p "$OUTDATADIR/kraken2/${2}Assembly"
fi

#. "${shareScript}/module_changers/perl_5221_to_5123.sh"
# Prints out version of kraken
kraken2 --version
# Status view of run
echo "[:] Running kraken2.  Output: ${1}.kraken2 / ${1}.classified"
# Runs kraken2 in paired reads mode
if [ "${3}" = "paired" ]; then
	cp "${OUTDATADIR}/trimmed/${1}_R1_001.paired.fq" "${OUTDATADIR}/trimmed/${1}_1.fq"
	cp "${OUTDATADIR}/trimmed/${1}_R2_001.paired.fq" "${OUTDATADIR}/trimmed/${1}_2.fq"
	kraken2 --paired --db "${kraken2_mini_db}" --fastq-input --report --use-mpa-style "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2_report" --use-names --threads "${procs}" --output "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2" --classified-out "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}#.classified" "${OUTDATADIR}/trimmed/${1}_R1_001.paired.fq" "${OUTDATADIR}/trimmed/${1}_R2_001.paired.fq"
	rm "${OUTDATADIR}/trimmed/${1}_1.fq"
	rm "${OUTDATADIR}/trimmed/${1}_2.fq"
# Runs kraken2 in single end mode on the concatenated single read file
elif [ "${3}" = "single" ]; then
	kraken2 --db "${kraken2_mini_db}" --fastq-input --threads "${procs}" --output "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2" --classified-out "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.classified ${OUTDATADIR}/FASTQs/${1}.single.fastq"
# Runs kraken2 on the assembly
elif [ "${3}" = "assembled" ]; then
	kraken2 --db "${kraken2_mini_db}" --threads "${procs}" --report --use-mpa-style --use-names --output "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2" --classified-out "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.classified" "${OUTDATADIR}/Assembly/${1}_scaffolds_trimmed.fasta"
	# Attempting to weigh contigs and produce standard krona and list output using a modified version of Rich's weighting scripts (will also be done on pure contigs later)
	echo "1"
	python ${shareScript}/Kraken_Assembly_Converter_2_Exe.py "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2"
	echo "2"
	kraken2 --use-names --db "${kraken2_mini_db}" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.kraken2" > "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.labels"
	# Create an mpa report
	echo "3"
	kraken2 --report --use-mpa-style --db "${kraken2_mini_db}" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.kraken2" > "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_weighted.mpa"
	# Convert mpa to krona file
	echo "4"
	perl "${shareScript}/Methaplan_to_krona.pl" -p "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_weighted.mpa" -k "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_weighted.krona"
	# Create taxonomy list file from kraken2 file
	echo "5"
	kraken2 --report --db "${kraken2_mini_db}" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.kraken2" > "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.list"
	# Weigh taxonomy list file
	echo "6"
	python3 ${shareScript}/Kraken_Assembly_Summary_Exe.py "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.kraken2" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.labels" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP.list" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_BP_data.list"
	# Change perl version to allow ktimporttext to work ( cant use anything but 5.12.3
	. "${shareScript}/module_changers/perl_5221_to_5123.sh"
	# Run the krona graph generator from krona output
	echo "7"
	ktImportText "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_weighted.krona" -o "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}_weighted_BP_krona.html"
	# Return perl version back to 5.22.1
	 "${shareScript}/module_changers/perl_5123_to_5221.sh"
	# Runs the extractor for pulling best taxonomic hit from a kraken2 run
	echo "8"
	"${shareScript}/best_hit_from_kraken.sh" "${1}" "${2}" "${3}_BP_data" "${4}"
else
	echo "Argument combination is incorrect"
	exit 1
fi

# Run the metaphlan generator on the kraken2 output
echo "[:] Generating metaphlan compatible report."
kraken2 --report --use-mpa-style --db "${kraken2_mini_db}" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2" > "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.mpa"
# Run the krona generator on the metaphlan output
echo "[:] Generating krona output for ${1}."
# Convert mpa to krona file
perl "${shareScript}/Methaplan_to_krona.pl" -p "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.mpa" -k "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.krona"
# Change perl version to allow ktimporttext to work ( cant use anything but 5.12.3
. "${shareScript}/module_changers/perl_5221_to_5123.sh"
# Run the krona graph generator from krona output
ktImportText "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.krona" -o "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.html"
# Return perl version back to 5.22.1
. "${shareScript}/module_changers/perl_5123_to_5221.sh"

# Creates the taxonomy list file from the kraken2 output
echo "[:] Creating alternate report for taxonomic extraction"
kraken2 --report --db "${kraken2_mini_db}" "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.kraken2" > "${OUTDATADIR}/kraken2/${2}Assembly/${1}_${3}.list"
# Parses the output for the best taxonomic hit
echo "[:] Extracting best taxonomic matches"
# Runs the extractor for pulling best taxonomic hit from a kraken2 run
"${shareScript}/best_hit_from_kraken.sh" "${1}" "${2}" "${3}" "${4}"

#Script exited gracefully (unless something else inside failed)
exit 0