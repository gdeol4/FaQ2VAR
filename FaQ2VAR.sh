#!/bin/bash

#using getopt
#first creating a usage function that will outline what arguments to enter if nothing is entered
usage () {
  echo "Usage: $0 [-b <barcode file.txt>] [-f <fastq file.fastq>] [-S <sam file.sam>] [-B <bam file.bam>] [-r <reference genome>]" 1>&2; exit 1;
}

#This uses getopts and a while loop to allow the user to put data in as arguments
#the way this is set up it will only allow you to continue if you add data to all three fields. Otherwise the usage function will echo an error and show the user the appropriate format to use 
while getopts ":b:f:S:B:r:" o; do
  case "${o}" in
    b )
      b=${OPTARG}
      if [[ -z "${b}" ]]
        then
          echo -en "the barcode file does not exist"
          usage
      fi
      ;;
    f )
      f=${OPTARG}
      ;;
    S )
      S=${OPTARG}
      ;;
    B )
      B=${OPTARG}
      ;;
    r )
      r=${OPTARG}
      if [[ -z "${r}" ]]
        then
          echo -en "the reference genome file does not exist"
          usage
      fi
      ;;
    * )
      usage
      ;;
  esac
done
shift $((OPTIND-1))

#checking to make sure that both the barcode file and the ref genome are there
#if not a error message will echo then the usage function will flash the correct way to add arguments to the script and exit the script 
if [ -z "${b}" ] || [ -z "${r}" ]; then
  echo -en "\nNo file found \nBoth of these arguments must be specified with files to continue."
  usage
fi

#this generates eror message if a fastq, sam, or bam file isnt entered, and will exit the script
if [ -z "${f}" ] && [ -z "${S}" ] && [ -z "${B}" ]; then
  echo -en "\nNo file found \nOne of these arguments must be passed a file \n"
  usage
fi

#what variables are present
echo "b = ${b}"
echo "f = ${f}"
echo "S = ${S}"
echo "B = ${B}"
echo "r = ${r}"

#assign to new variables
BARCODES=$b
RAW_FASTQ=$f
RAW_SAM=$S
RAW_BAM=$B
REF=$r

#Who is using this pipeline
echo Hello, who am I talking to?
read USER_NAME
echo "Hello $USER_NAME – It’s nice to meet you!"

echo ===================================
#set up menu to direct work flow based on input values
echo ===================================

#make a simple press_enter function
press_enter () {
  echo -en "\nPress Enter to continue"
}

#so this menu will set up everything, allowing you to pick what analysis you want done 
#create menu to work from
selection=
until [ "$selection" = "0" ]; do
  echo "
  PROGRAM MENU
  1 - run program with fastq file
  2 - run progrm with sam file
  3 - run program with a bam file

  0 - end the program (will exit the program)
  "
#allow the user to select an option to continue
  echo -n "Enter selection: "
  read selection
  echo ""
  case $selection in
    1 )
    #make parent directory variant_calling
    echo "$USER_NAME I am making a working directory for this pipeline"

    mkdir -pv variant_calling

    #now copy files into that directory
    cp $BARCODES variant_calling
    cp $RAW_FASTQ variant_calling
    cp $REF variant_calling

    #export these variables
    export $BARCODES
    export $RAW_FASTQ
    export $REF

    #move to variant_calling, this will be our main WD for this pipeline
    echo "$USER_NAME moving you to variant_calling directory"

    cd variant_calling

    #make directories for our ref genome and fastq file(s)
    echo "$USER_NAME making some directories for your data"

    mkdir -pv raw/ref_genome
    mkdir -pv raw/fastq_files
    mkdir -pv raw/barcodes
    
#move data to approprite directories 
    mv $BARCODES raw/barcodes
    mv $RAW_FASTQ raw/fastq_files
    mv $REF raw/ref_genome

    #asking the user if they would like to preform a FastQC analysis on their data
    selection=
    until [ "$selection" = "0" ]; do
      echo "
      PROGRAM MENU
      1 - Preform FastQC

      0 - return to current working directory
      "
#user picks an option to continue 
      echo -n "Enter selection: "
      read selection
      echo ""
      case $selection in
        1 )
          echo "Enter the command for FastQC tool on your computer: "
          read -r FastQC
          echo ""
          TOOL_FASTQC=$FastQC
          echo "Running FastQC"
          $TOOL_FASTQC raw/fastq_files/$RAW_FASTQ
          echo -en "Done \nWould you like to view the summary? (open another window)"
          read -p "[y/n]: " choice
          case "$choice" in
            y|Y )
              #opens a separate window to view the fastqc report 
              xdg-open raw/fastq_files/*.html 
              press_enter
              ;;
            n|N )
              echo "$USER_NAME you are returning to variant_calling directory"
              cd variant_calling
              press_enter
              ;;
            * )
              echo "please enter y or n"
              press_enter
          esac
          ;;
        0 )
          echo "$USER_NAME you are returning to variant_calling directory"
          cd variant_calling
          press_enter
          ;;
        * )
        echo "Please enter 1 or 0"
        press_enter
        ;;
      esac
    done

    echo =================================
    #use Sabre for demultiplexing
    echo =================================

    #ask the user for the path to sabre
    echo "$USER_NAME please enter the command for sabre, going to make it into a variable: "
    read sabre
      TOOL_SABRE=$sabre

    #make directory for the results
    mkdir -pv raw/fastq_sabre

    #run sabre
    echo "running sabre"

    #make some variables
    input_fastq=raw/fastq_files/*.fastq
    input_barcode=raw/barcodes/*.txt
    output_sabre=raw/fastq_sabre/SABRE_DATA.sabre_fq

    #run sabre
    $TOOL_SABRE se -f $input_fastq -b $input_barcode -u $output_sabre
    #$TOOL_SABRE se -f raw/fastq_files/*.fastq -b raw/barcodes/*.txt -u SABRE_DATA.fastq

    echo "sabre complete"

    echo ==================================
    #Use sickle program to trim fastq files
    echo ==================================

    #First have to ask the user to find the sickle program on their computer and provide the path
    echo "$USER_NAME please enter the command for sickle, making it into a variable: "
    read sickle
      TOOL_SICKLE=$sickle

    #make a directory to store the trimmed reads from sickle
    mkdir -pv raw/fastq_trimmed

    #Run the sickle program with the fastq data
    echo "running sickle"

    for FASTQ in "raw/fastq_sabre/*.sabre_fq"
      do
        NAME=$( basename $FASTQ .sabre_fq ) #extracts the name of the file without the path and the .fastq extention and assigns it to the variable name
        echo "working with $NAME"

        #create some variables to make this less confusing

        FASTQ=raw/fastq_sabre/$NAME\.sabre_fq
        TRIMMED=raw/fastq_trimmed/$NAME\.trimmed_fq

        #data is all staged now lets run sickle

        $TOOL_SICKLE se -f $FASTQ -t illumina -o $TRIMMED

    done

    echo "sickle complete"

    echo ================================
    #Align reads to reference genome BWA
    echo ================================

    #To start we have to be in the main directory variant_calling
    cd variant_calling

    #need to load paths for BWA and samtools
    echo "$USER_NAME enter the command for BWA on your computer, making it into a variable: "
    read bwa
      TOOL_BWA=$bwa

    echo "$USER_NAME enter the command for samtools on your computer, making it into a variable: "
    read samtools
      TOOL_SAMTOOLS=$samtools

      echo "$USER_NAME enter the command for bcftools on your computer, making it into a variable: "
      read bcftools
        TOOL_BCFTOOLS=$bcftools

    #remember that we assigned our reference genome to the variable $REF, but want to have a variable that includes the path to this to make it easier
    WORKING_REF=raw/ref_genome/$REF

    #now need to index our reference genome for bwa and samtools
    $TOOL_BWA index $WORKING_REF

    $TOOL_SAMTOOLS index $WORKING_REF

    #now lets create some output paths for intermediate and final result files
    mkdir -pv results/sai
    mkdir -pv results/sam
    mkdir -pv results/bam
    mkdir -pv results/bcf
    mkdir -pv results/vcf

    #now going to create a for loop to run the variant calling workflow on however many fastq files we have
    #remember the files we are using are in the 'trimmed reads' directory and are called FASTQ_TRIMMED.fq
    #this should be able to handle as many files as possible

    for reads in raw/fastq_trimmed/*.trimmed_fq
      do
        NAME=$( basename $reads .trimmed_fq ) #extracts the name of the file without the path and the .fq extention and assigns it to the variable name
        echo "working with $NAME"

          echo "assign file names to variables to make this less confusing"

          FQ=raw/fastq_trimmed/$NAME\.trimmed_fq
          SAI=results/sai/$NAME\_aligned.sai
          SAM=results/sam/$NAME\_aligned.sam
          BAM=results/bam/$NAME\_aligned.bam
          SORTED_BAM=results/bam/$NAME\_aligned_sorted.bam
          VAR_VCF=results/vcf/$NAME\.var.vcf

          #data can now be moved easily with variables
          #align the reads with BWA

          $TOOL_BWA aln $WORKING_REF $FQ > $SAI

          #convert the output to the SAM formate

          $TOOL_BWA samse $WORKING_REF $SAI $FQ > $SAM

          #SAM to BAM

          $TOOL_SAMTOOLS view -S -b -h $SAM > $BAM

          #sort the BAM file - not sure if this is necessary but everything online seems to do it
          #the -f simply ignores upper and lower case for sorting

          $TOOL_SAMTOOLS sort $BAM -o $SORTED_BAM

          #they also index them everywhere online and the command is simple enough so lets do that

          $TOOL_SAMTOOLS index $SORTED_BAM

          #reindex Ref genome
          $TOOL_SAMTOOLS faidx $WORKING_REF

          #use bcftools to run the mpileup command can get get the SNP varient calls
          $TOOL_BCFTOOLS mpileup -Ou -f $WORKING_REF $SORTED_BAM | \
          $TOOL_BCFTOOLS call -Ou -mv | \
          $TOOL_BCFTOOLS filter -s LowQual -e '%QUAL<20 || DP>100' > $VAR_VCF
            if [ $? -ne 0 ]; then
              printf "There is a problem converting the bcf file to a vcf file"
            fi

          #view the file
          less $VAR_VCF
    done
      press_enter
      ;;
    2 )
    #make parent directory variant_calling
    echo "$USER_NAME I am making a working directory for this pipeline"

    mkdir -pv variant_calling

    #now copy
    cp $BARCODES variant_calling
    cp $REF variant_calling
    cp $RAW_SAM variant_calling

    #export these variables
    export $BARCODES
    export $REF
    export $RAW_SAM

    #move to variant_calling, this will be our main WD for this pipeline
    echo "$USER_NAME moving you to variant_calling directory"

    cd variant_calling

    #make directories for our ref genome and fastq file(s)
    echo "$USER_NAME making some directories for your data"

    mkdir -pv raw/ref_genome
    mkdir -pv raw/barcodes
    mkdir -pv raw/raw_sam

#move files to correct directories
    mv $BARCODES raw/barcodes
    mv $REF raw/ref_genome
    mv $RAW_SAM raw/raw_sam

    #need to load some programs
    echo "$USER_NAME enter the command for BWA on your computer, making it into a variable: "
    read bwa
      TOOL_BWA=$bwa

    echo "$USER_NAME enter the command for samtools on your computer, making it into a variable: "
    read samtools
      TOOL_SAMTOOLS=$samtools

      echo "$USER_NAME enter the command for bcftools on your computer, making it into a variable: "
      read bcftools
        TOOL_BCFTOOLS=$bcftools

    #remember that we assigned our reference genome to the variable $REF, but want to have a variable that includes the path to this to make it easier
    WORKING_REF=raw/ref_genome/$REF

    #now need to index our reference genome for bwa and samtools
    $TOOL_BWA index $WORKING_REF

    $TOOL_SAMTOOLS index $WORKING_REF

    #now lets create some output paths for intermediate and final result files
    mkdir -pv results/sam
    mkdir -pv results/bam
    mkdir -pv results/vcf

    #now going to create a for loop to run the variant calling workflow on however many sam files are found in the directory raw_sam
    for reads in raw/raw_sam/*.sam
      do
        NAME=$( basename $reads .sam ) #extracts the name of the file without the path and the .fq extention and assigns it to the variable name
        echo "working with $NAME"

          echo "assign file names to variables to make this less confusing"

          SAM=raw/raw_sam/$NAME\.sam
          BAM=results/bam/$NAME\_aligned.bam
          SORTED_BAM=results/bam/$NAME\_aligned_sorted.bam
          VAR_VCF=results/vcf/$NAME\.var.vcf

          #SAM to BAM

          $TOOL_SAMTOOLS view -S -b -h $SAM > $BAM

          #sort the BAM file - not sure if this is necessary but everything online seems to do it
          #the -f simply ignores upper and lower case for sorting

          $TOOL_SAMTOOLS sort $BAM -o $SORTED_BAM

          #they also index them everywhere online and the command is simple enough so lets do that

          $TOOL_SAMTOOLS index $SORTED_BAM

          #reindex Ref genome
          #make a new empty variable
          $TOOL_SAMTOOLS faidx $WORKING_REF

          #use bcftools to run the mpileup command can get get the SNP varient calls
          $TOOL_BCFTOOLS mpileup -Ou -f $WORKING_REF $SORTED_BAM | \
          $TOOL_BCFTOOLS call -Ou -mv | \
          $TOOL_BCFTOOLS filter -s LowQual -e '%QUAL<20 || DP>100' > $VAR_VCF
            if [ $? -ne 0 ]; then
              printf "There is a problem converting the bcf file to a vcf file"
              exit 1
            fi

          #view the file
          less $VAR_VCF
    done

      press_enter
      ;;
    3 )
      #make parent directory variant_calling
      echo "$USER_NAME I am making a working directory for this pipeline"

      mkdir -pv variant_calling

      #now copy
      cp $BARCODES variant_calling
      cp $REF variant_calling
      cp $RAW_BAM variant_calling

      #export these variables
      export $BARCODES
      export $REF
      export $RAW_BAM

      #move to variant_calling, this will be our main WD for this pipeline
      echo "$USER_NAME moving you to variant_calling directory"

      cd variant_calling
      
      #make directories for our ref genome and fastq file(s)
      echo "$USER_NAME making some directories for your data"

      mkdir -pv raw/ref_genome
      mkdir -pv raw/barcodes
      mkdir -pv raw/raw_bam

#move files to the correct directories
      mv $BARCODES raw/barcodes
      mv $REF raw/ref_genome
      mv $RAW_BAM raw/raw_bam

      #need to load some programs
      need to load paths for BWA and samtools
      echo "$USER_NAME enter the command for BWA on your computer, making it into a variable: "
      read bwa
        TOOL_BWA=$bwa

      echo "$USER_NAME enter the command for samtools on your computer, making it into a variable: "
      read samtools
        TOOL_SAMTOOLS=$samtools

        echo "$USER_NAME enter the command for bcftools on your computer, making it into a variable: "
        read bcftools
          TOOL_BCFTOOLS=$bcftools

      #remember that we assigned our reference genome to the variable $REF, but want to have a variable that includes the path to this to make it easier
      WORKING_REF=raw/ref_genome/$REF

      #now need to index our reference genome for bwa and samtools
      $TOOL_BWA index $WORKING_REF

      $TOOL_SAMTOOLS index $WORKING_REF

      #now lets create some output paths for intermediate and final result files
      mkdir -pv results/bam
      mkdir -pv results/vcf

      #now going to create a for loop to run the variant calling workflow on however many bam files are in raw_bam

      for reads in raw/raw_bam/*.bam
        do
          NAME=$( basename $reads .bam ) #extracts the name of the file without the path and the .fq extention and assigns it to the variable name
          echo "working with $NAME"

            echo "assign file names to variables to make this less confusing"

            BAM=raw/raw_bam/$NAME\.bam
            SORTED_BAM=results/bam/$NAME\_aligned_sorted.bam
            VAR_VCF=results/vcf/$NAME\.var.vcf

            #sort the BAM file - not sure if this is necessary but everything online seems to do it
            #the -f simply ignores upper and lower case for sorting

            $TOOL_SAMTOOLS sort $BAM -o $SORTED_BAM

            #they also index them everywhere online and the command is simple enough so lets do that

            $TOOL_SAMTOOLS index $SORTED_BAM

            #reindex Ref genome
            #make a new empty variable
            $TOOL_SAMTOOLS faidx $WORKING_REF

            #use bcftools to run the mpileup command can get get the SNP varient calls
            $TOOL_BCFTOOLS mpileup -Ou -f $WORKING_REF $SORTED_BAM | \
            $TOOL_BCFTOOLS call -Ou -mv | \
            $TOOL_BCFTOOLS filter -s LowQual -e '%QUAL<20 || DP>100' > $VAR_VCF
              if [ $? -ne 0 ]; then
                printf "There is a problem converting the bcf file to a vcf file"
                exit 1
              fi

            #view the file
            less $VAR_VCF
      done

      press_enter
      ;;
    0 )
      exit 1
      press_enter
      ;;
    * )
    echo "Please enter 1, 2, 3, or 0"
    press_enter
    ;;
  esac
done
