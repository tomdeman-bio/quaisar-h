#!/bin/sh -l

#$ -o run_SNVPhyl.out
#$ -e run_SNVPhyl.err
#$ -N run_SNVPhyl
#$ -cwd
#$ -q short.q

#Import the config file with shortcuts and settings
if [[ ! -f ./config.sh ]]; then
	cp config_template.sh config.sh
fi
. ./config.sh
#Import list of modds used during pipeline analysis (or downstream)
module purge
. "${mod_changers}/load_SNVPhyl.sh"
. ${mod_changers}/list_modules.sh

#
# Runs LyveSET on a group of samples to determine relatedness
#
# Usage ./run_LyveSET.sh group_name (must have sample list file in Phylogeny_analyses folder before starting as group_name.samples. First sample on list will be reference)
#
# requires modules Lyve_SET/1.1.4, ncbi-BLAST+/2.3.0 (using2.6.0), java/latest
#

# Checks for proper argumentation
if [[ $# -eq 0 ]]; then
	echo "No argument supplied to run_SNVPhyl.sh, exiting"
	exit 1
elif [[ -z "${1}" ]] || ([ ! -f ${share}/Phylogeny_analyses/${1}/${1}.samples ] && [ ! -f ${share}/Phylogeny_analyses/${1}.samples ] && [ ! -f ${share}/Phylogeny_analyses/${1}/${2}/${1}.samples ] && [ ! -f ${share}/Phylogeny_analyses/${1}/SNVPhyl/${1}.samples ] && [ "${1}" != "-h" ] ); then
	echo "Empty group name or non-existent sample list file supplied to run_SNVPhyl.sh, exiting"
	exit 1
# Gives the user a brief usage and help section if requested with the -h option argument
elif [[ "${1}" = "-h" ]]; then
	echo "Usage is ./run_LyveSET.sh group_name (to identify the different groups analyzed) Alternate_output)folder_name(optional)"
	echo "Phylogeny_analyses folder must contain list of samples (in format of project_id/sample_name) to be compared labelled by group_name.samples. First sample on list will be reference"
	echo "Output is saved to ${share}/Phylogeny_analyses/group_name/SNVPhyl(or alt_name)"
	exit 0
elif [[ -z "${2}" ]]; then
	echo "Empty output directory name, using SNVPhyl"
	out_folder="SNVPhyl"
elif [[ ! -z "${2}" ]]; then
	out_folder="${2}"
#elif [ -z "$2" ] || [ ! -s "${share}/Phylogeny_analyses/${1}.samples" ]; then
#	echo "Empty group name supplied to run_LyveSET.sh, exiting"
#	exit 1
fi

# Not being run on cluster=no run
#if [[ ${host} != "cluster"* ]]; then
#	echo "No scheduling system, can not run LyveSET"
#	exit 1
#fi



# Sets the parent folder to processed samples so it can zip necessary fastq files of matching samples
DATADIR="${processed}"
# Sets output folder to group_name under Phylogeny_analyses in MMB_Data folder
OUTDATADIR=${share}/Phylogeny_analyses/${1}/${out_folder}
if [[ ! -d "${share}/Phylogeny_analyses/${1}" ]]; then
	mkdir "${share}/Phylogeny_analyses/${1}"
	mkdir "${OUTDATADIR}"
	mkdir "${OUTDATADIR}/FASTQs"
elif [[ ! -d "${OUTDATADIR}" ]]; then
	mkdir "${OUTDATADIR}"
	mkdir "${OUTDATADIR}/FASTQs"
elif [[ ! -d "${OUTDATADIR}/FASTQs" ]]; then
	mkdir "${OUTDATADIR}/FASTQs"
fi
if [[ -d "${OUTDATADIR}/output" ]]; then
	rm -r "${OUTDATADIR}/output"
fi

if [[ ! -f ${OUTDATADIR}/${1}.samples ]]; then
	if [[ ! -f ${share}/Phylogeny_analyses/${1}/${1}.samples ]]; then
		if [[ ! -f ${share}/Phylogeny_analyses/${1}.samples ]]; then
			echo "No sample list found in ${OUTDATADIR} or ${share}/Phylogeny_analyses/${1}/ or ${share}/Phylogeny_analyses/   ...   exiting"
			exit 1
		else
			mv ${share}/Phylogeny_analyses/${1}.samples ${OUTDATADIR}/${1}.samples
		fi
	else
		mv ${share}/Phylogeny_analyses/${1}/${1}.samples ${OUTDATADIR}/${1}.samples
	fi
fi


counter=0
while IFS= read -r var
do
	echo "var:$var"
	sample=$(echo "${var}" | awk -F"/" '{print $2}' | tr -d '[:space:]')
	# Lists are used in both SNVPhyl and LyveSET, but LyveSET can simulate reads on assemblies, :asm at the end of the filename is the designation for this action, It is unused in SNVPhyl and just removed
	if [[ ${#sample} -gt 4 ]]; then
		if [[ ${sample: -4} = ":asm" ]]; then
			sample=${sample::-4}
		fi
	fi
	echo "sample:$sample"
	project=$(echo "${var}" | awk -F"/" '{print $1}' | tr -d '[:space:]')
	echo "project:$project"
	if [[ ${counter} -eq 0 ]]; then
		#echo "Setting reference as ${sample} from ${project}"
		ref=${sample}
		ref_proj=${project}
		counter=$(( counter + 1))
		continue
	fi
	echo "Copying: ${sample} from ${project}"
	# Copy over standard FASTQs not compressed
	if [[ -f "${processed}/${project}/${sample}/trimmed/${sample}_R1_001.paired.fq.gz" ]]; then
		cp "${processed}/${project}/${sample}/trimmed/${sample}_R1_001.paired.fq.gz" "${OUTDATADIR}/FASTQs/${sample}_R1_001.fq.gz"
	elif [[ -f "${processed}/${project}/${sample}/trimmed/${sample}_R1_001.fq.gz" ]]; then
		cp "${processed}/${project}/${sample}/trimmed/${sample}_R1_001.fq.gz" "${OUTDATADIR}/FASTQs/${sample}_R1_001.fq.gz"
	elif [[ -f "${processed}/${project}/${sample}/trimmed/${sample}_R1_001.paired.fq" ]]; then
		echo "Copying ${processed}/${project}/${sample}/trimmed/${sample}_R1_001.paired.fq"
		cp "${processed}/${project}/${sample}/trimmed/${sample}_R1_001.paired.fq" "${OUTDATADIR}/FASTQs/${sample}_R1_001.fq"
		gzip "${OUTDATADIR}/FASTQs/${sample}_R1_001.fq"
	else
		echo "No zipped or unzipped trimmed R1 exists...."
		exit
	fi
	if [[ -f "${processed}/${project}/${sample}/trimmed/${sample}_R2_001.paired.fq.gz" ]]; then
		cp "${processed}/${project}/${sample}/trimmed/${sample}_R2_001.paired.fq.gz" "${OUTDATADIR}/FASTQs/${sample}_R2_001.fq.gz"
	elif [[ -f "${processed}/${project}/${sample}/trimmed/${sample}_R2_001.fq.gz" ]]; then
		cp "${processed}/${project}/${sample}/trimmed/${sample}_R2_001.fq.gz" "${OUTDATADIR}/FASTQs/${sample}_R2_001.fq.gz"
	elif [[ -f "${processed}/${project}/${sample}/trimmed/${sample}_R2_001.paired.fq" ]]; then
		echo "Copying ${processed}/${project}/${sample}/trimmed/${sample}_R2_001.paired.fq"
		cp "${processed}/${project}/${sample}/trimmed/${sample}_R2_001.paired.fq" "${OUTDATADIR}/FASTQs/${sample}_R2_001.fq"
		gzip "${OUTDATADIR}/FASTQs/${sample}_R2_001.fq"
	else
		echo "No zipped or unzipped trimmed R2 exists...."
		exit
	fi
	counter=$((counter + 1))
done < ${OUTDATADIR}/${1}.samples
echo "Reference is ${ref} from ${ref_proj}"
cp "${processed}/${ref_proj}/${ref}/Assembly/${ref}_scaffolds_trimmed.fasta" "${OUTDATADIR}/reference(${ref}).fasta"

owd=$(pwd)
cd ${OUTDATADIR}/

#snvphyl --fastq-dir ./FASTQs --reference-file "./reference(${ref}).fasta" --output-dir ./output --relative-snv-abundance 0.95 --min-coverage 5 --min-mean-mapping 10 --filter-density-window 20 --filter-density-threshold 2
#snvphyl --fastq-dir ./FASTQs --reference-file "./reference(${ref}).fasta" --output-dir --deploy-docker ./output --relative-snv-abundance 0.75 --min-coverage 10 --min-mean-mapping 30 --filter-density-threshold 2
snvphyl --fastq-dir ./FASTQs --reference-file "./reference(${ref}).fasta" --output-dir ./output --relative-snv-abundance 0.75 --min-coverage 10 --min-mean-mapping 30 --filter-density-threshold 2 --filter-density-window 11 --workflow-id "f2db41e1fa331b3e"
#snvphyl --fastq-dir ./FASTQs --reference-file "./reference(${ref}).fasta" --output-dir ./output --relative-snv-abundance 0.75 --min-coverage 10 --min-mean-mapping 30 --filter-density-threshold 2 --filter-density-window 11

snv_all_est=$(tail -n 1 "${OUTDATADIR}/output/vcf2core.tsv")
snv_est=$(echo "${snv_all_est}" | cut -d '	' -f7)

sed -i "s/reference/${ref}/g" "${OUTDATADIR}/output/snvMatrix.tsv"
sed -i "s/reference/${ref}/g" "${OUTDATADIR}/output/phylogeneticTree.newick"

echo -e "\nReference:\t${ref}\nSNVPhyl core estimate:\t${snv_est}%\n" >> "${OUTDATADIR}/output/snvMatrix.tsv"



. "${mod_changers}/unload_SNVPhyl.sh"
cd ${owd}

exit 0
