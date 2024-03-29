#!/usr/bin/env python
#  @ Author: Nick Vlachos
#  + Version .1
#  + 1 August 2017
#  Dependencies:  none

# Usage python ./entrez_get_taxon_from_number.py ncbi-taxonomy-number your_email(for entrez tools)
#
# Requires module Entrez/E-utilities
#

from Bio import Entrez
import sys
import argparse

#Create an arg parser...someday
def parseArgs(args=None):
	parser = argparse.ArgumentParser(description='Tool to retrieve taxonomy information from entrez using the ncbi assigned taxonomy number')
	parser.add_argument('-e', '--email', required=True, help='email of submitter, required by entrez')
	parser.add_argument('-n', '--number', required=True, help='taxonomy number to look up')
	return parser.parse_args()

args = parseArgs()
#Set the required email value to the supplied 2nd argument
Entrez.email = args.email
#Creates the data structure from a pull from entrez nucleotide database using accession id with return type of genbank text mode
handle = Entrez.efetch(db="taxonomy", id=args.number, mode="text", rettype="xml")
#Parses the returned output into lines
result= Entrez.read(handle)
#Goes through each line until it finds (and prints) the organism name that the accession number represents
for taxon in result:
	print(taxon)
	taxid = taxon["TaxId"]
	name = taxon["ScientificName"]
	lineage=["root"]
	for t in taxon["LineageEx"]:
		#print(t)
		lineage.append(t["ScientificName"])
	lineage.append(name)
	print("%s\t|\t%s\t|\t%s" % (taxid, name, ";".join(lineage)))
	#print(' '.join(line.split()[1:]))
