#!/bin/sh -l

#$ -o ablmq_srst2.out
#$ -e ablmq_srst2.err
#$ -N ablmq_srst2
#$ -cwd
#$ -q short.q

#Import the config file with shortcuts and settings
if [[ ! -f "./config.sh" ]]; then
	cp ./config_template.sh ./config.sh
fi
. ./config.sh

#Import the module file that loads all necessary mods
. "${mod_changers}/pipeline_mods"

#List all currently loaded modules
#. ./module_changers/list_modules.sh

#
# Usage ./abl_mass_qsub_srst2.sh path_to_list max_concurrent_submissions output_directory_for_scripts clobberness[keep|clobber]
#

# Number regex to test max concurrent submission parametr
number='^[0-9]+$'

# Checks for proper argumentation
if [[ $# -eq 0 ]]; then
	echo "No argument supplied to $0, exiting"
	exit 1
# Shows a brief uasge/help section if -h option used as first argument
elif [[ "$1" = "-h" ]]; then
	echo "Usage is ./abl_mass_qsub_srst2.sh path_to_list_file(single sample ID per line, e.g. B8VHY/1700128 (it must include project id also)) max_concurrent_submissions path_to_alt_database output_directory_for_scripts clobberness[keep|clobber]"
	exit 1
elif [[ ! -f "${1}" ]]; then
	echo "${1} (list) does not exist...exiting"
	exit 1
elif ! [[ ${2} =~ $number ]] || [[ -z "${2}" ]]; then
	echo "${2} is not a number or is empty. Please input max number of concurrent qsub submissions...exiting"
	exit 2
elif [[ -z "${3}" ]]; then
	echo "Output directory parameter is empty...exiting"
	exit 1
elif [[ -z "${4}" ]]; then
	echo "Clobberness was not input, be sure to add keep or clobber as 4th parameter...exiting"
	exit 1
fi

# Check that clobberness is a valid option
if [[ "${4}" != "keep" ]] && [[ "${4}" != "clobber" ]]; then
	echo "Clobberness was not input, be sure to add keep or clobber as 5th parameter...exiting"
	exit 1
else
	clobberness="${4}"
fi

# create an array of all samples in the list
arr=()
while IFS= read -r line || [ "$line" ];  do
  arr+=("$line")
done < ${1}

arr_size="${#arr[@]}"
last_index=$(( arr_size -1 ))
echo "-${arr_size}:${arr[@]}-"

# Create counter and set max number of concurrent submissions
counter=0
max_subs=${2}

# Set script directory
main_dir="${3}/srst2_subs"
if [[ ! -d "${3}/srst2_subs" ]]; then
	mkdir "${3}/srst2_subs"
	mkdir "${3}/srst2_subs/complete"
elif [[ ! -d  "${3}/srst2_subs/complete" ]]; then
	mkdir "${3}/srst2_subs/complete"
fi

start_time=$(date "+%m-%d-%Y_at_%Hh_%Mm_%Ss")

# Creates and submits qsub scripts to check all isolates on the list against the newest ResGANNCBI DB
while [ ${counter} -lt ${arr_size} ] ; do
	sample=$(echo "${arr[${counter}]}" | cut -d'/' -f2)
	project=$(echo "${arr[${counter}]}" | cut -d'/' -f1)
	if [[ "${clobberness}" = "clobber" ]]; then
		rm ${processed}/${project}/${sample}/srst2/${sample}__fullgenes__${ResGANNCBI_srst2_filename}_srst2__results.txt
		rm ${processed}/${project}/${sample}/srst2/${sample}__genes__${ResGANNCBI_srst2_filename}_srst2__results.txt
	fi
	echo ${counter}
	# Check if counter is below max number of concurrent submissions
	if [ ${counter} -lt ${max_subs} ]; then
		#echo "if [[ ! -f ${processed}/${project}/${sample}/srst2/${sample}__genes__${ResGANNCBI_srst2_filename}_srst2__results.txt ]] || [[ ! -f ${processed}/${project}/${sample}/srst2/${sample}__fullgenes__${ResGANNCBI_srst2_filename}_srst2__results.txt ]]; then"
		# Check if either one of the output files of srst2 files exist, skip submission if so
		if [[ ! -f "${processed}/${project}/${sample}/srst2/${sample}__genes__${ResGANNCBI_srst2_filename}_srst2__results.txt" ]] || [[ ! -f "${processed}/${project}/${sample}/srst2/${sample}__fullgenes__${ResGANNCBI_srst2_filename}_srst2__results.txt" ]]; then
			echo  "Index is below max submissions, submitting"
			echo -e "#!/bin/bash -l\n" > "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "#$ -o srst2AR_${sample}.out" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "#$ -e srst2AR_${sample}.err" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "#$ -N srst2AR_${sample}"   >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "#$ -cwd"  >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "#$ -q short.q\n"  >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module unload Python/2.7" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module unload Python/3.5.2" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module unload perl/5.22.1" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module load Python/2.7.15" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module load bowtie2/2.2.4" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module load samtools/0.1.18" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module load perl/5.16.1-MT" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "module load srst2" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			# Can we somehow consolidate into one srst2 analysis to do MLST/AR/SEROTYPE
			echo -e "cd ${shareScript}" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "\"${shareScript}/run_srst2_on_singleDB.sh\" \"${sample}\" \"${project}\"" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			echo -e "echo \"$(date)\" > \"${main_dir}/complete/${sample}_srst2AR_complete.txt\"" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"

			#cd "${main_dir}"
			if [[ "${counter}" -lt "${last_index}" ]]; then
				qsub "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			else
				qsub -sync y "${main_dir}/srst2AR_${sample}_${start_time}.sh"
			fi
			mv "${shareScript}/srst2AR_${sample}.err" ${main_dir}
			mv "${shareScript}/srst2AR_${sample}.out" ${main_dir}
		# Old data existed, skipping
		else
			echo -e $(date) > "${main_dir}/complete/${sample}_srst2AR_complete.txt"
			echo "${project}/${sample} already has newest srst2 ResGANNCBI ${ResGANNCBI_srst2_filename}"
		fi
	# Counter is above max submission, must wait for previous ones to finish before moving on
	else
		waiting_for_index=$(( counter - max_subs ))
		waiting_sample=$(echo "${arr[${waiting_for_index}]}" | cut -d'/' -f2)
		timer=0
		echo "Index is above max submissions, waiting for index ${waiting_for_index}:${waiting_sample} to complete"
		while :
		do
			# Check if timer is above max time allowed
			if [[ ${timer} -gt 1800 ]]; then
				echo "Timer exceeded limit of 1800 seconds 30 minutes"
				break
			fi
			# Check if waiting sample is finished
			if [ -f "${main_dir}/complete/${waiting_sample}_srst2AR_complete.txt" ]; then
				# Check if current sample has etiher one of the output files from srst2, skip analysis if so
				if [[ ! -f "${processed}/${project}/${sample}/srst2/${sample}__genes__${ResGANNCBI_srst2_filename}_srst2__results.txt" ]] && [[ ! -f "${processed}/${project}/${sample}/srst2/${sample}__fullgenes__${ResGANNCBI_srst2_filename}_srst2__results.txt" ]]; then
					echo "${waiting_sample} has completed, starting ${sample}"
					echo -e "#!/bin/bash -l\n" > "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "#$ -o srst2AR_${sample}.out" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "#$ -e srst2AR_${sample}.err" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "#$ -N srst2AR_${sample}"   >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "#$ -cwd"  >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "#$ -q short.q\n"  >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module unload Python/2.7" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module unload Python/3.5.2" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module unload perl/5.22.1" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module load Python/2.7.15" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module load bowtie2/2.2.4" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module load samtools/0.1.18" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module load perl/5.16.1-MT" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "module load srst2" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					# Can we somehow consolidate into one srst2 analysis to do MLST/AR/SEROTYPE
					echo -e "cd ${shareScript}" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "\"${shareScript}/run_srst2_on_singleDB.sh\" \"${sample}\" \"${project}\"" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					echo -e "echo \"$(date)\" > \"${main_dir}/complete/${sample}_srst2AR_complete.txt\"" >> "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					cd "${main_dir}"
					#if [[ "${counter}" -lt "${last_index}" ]]; then
						qsub "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					#else
					#	qsub -sync y "${main_dir}/srst2AR_${sample}_${start_time}.sh"
					#fi
					#mv "${shareScript}/srst2AR_${sample}.err" ${main_dir}
					#mv "${shareScript}/srst2AR_${sample}.out" ${main_dir}
				# Old data existed, skipping
				else
					echo -e $(date) > "${main_dir}/complete/${sample}_srst2AR_complete.txt"
					echo "${project}/${sample} already has newest srst2 ResGANNCBI ${ResGANNCBI_srst2_filename}"
				fi
				break
			# Wait 5 seconds and then check if "waiting" sample is complete
			else
				timer=$(( timer + 5 ))
				echo "sleeping for 5 seconds, so far slept for ${timer}"
				sleep 5
			fi
		done
	fi
	counter=$(( counter + 1 ))
done

# Check for completion of all samples
timer=0
for item in "${arr[@]}"; do
	waiting_sample=$(echo "${item}" | cut -d'/' -f2)
	if [[ -f "${main_dir}/complete/${waiting_sample}_srst2AR_complete.txt" ]]; then
		echo "${item} is complete"
		if [[ -f "${shareScript}/srst2AR_${waiting_sample}.out" ]]; then
			mv "${shareScript}/srst2AR_${waiting_sample}.out" "${main_dir}"
		fi
		if [[ -f "${shareScript}/srst2AR_${waiting_sample}.err" ]]; then
			mv "${shareScript}/srst2AR_${waiting_sample}.err" "${main_dir}"
		fi
	else
		while :
		do
				if [[ ${timer} -gt 3600 ]]; then
					echo "Timer exceeded limit of 3600 seconds = 60 minutes"
					exit 1
				fi
				if [[ -f "${main_dir}/complete/${waiting_sample}_srst2AR_complete.txt" ]]; then
					echo "${item} is complete"
					if [[ -f "${shareScript}/srst2AR_${waiting_sample}.out" ]]; then
						mv "${shareScript}/srst2AR_${waiting_sample}.out" "${main_dir}"
					fi
					if [[ -f "${shareScript}/srst2AR_${waiting_sample}.err" ]]; then
						mv "${shareScript}/srst2AR_${waiting_sample}.err" "${main_dir}"
					fi
					break
				else
					timer=$(( timer + 5 ))
					echo "sleeping for 5 seconds, so far slept for ${timer}"
					sleep 5
				fi
		done
	fi
done

exit 0
