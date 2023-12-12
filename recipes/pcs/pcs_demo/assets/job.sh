#!/bin/bash

#SBATCH -J testjob
#SBATCH -o testjob-%j.out   # Write the standard output to file named 'jMPItest-<job_number>.out'
#SBATCH -e testjob-%j.err   # Write the standard error to file named 'jMPItest-<job_number>.err'

echo "Hello world. This is job ${SLURM_JOB_NAME} [${SLURM_JOB_ID}] running on ${SLURMD_NODENAME}, submitted from ${SLURM_SUBMIT_HOST}" && sleep 60 && echo "Job complete"
