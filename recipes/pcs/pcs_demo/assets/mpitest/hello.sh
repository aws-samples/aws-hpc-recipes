#!/bin/bash

#SBATCH -J MPItest          # Name the job as 'MPItest'
#SBATCH -o MPItest-%j.out   # Write the standard output to file named 'jMPItest-<job_number>.out'
#SBATCH -e MPItest-%j.err   # Write the standard error to file named 'jMPItest-<job_number>.err'
#SBATCH -t 0-12:00:00        # Run for a maximum time of 0 days, 12 hours, 00 mins, 00 secs
#SBATCH --nodes=1            # Request N nodes
#SBATCH --ntasks-per-node=2 # Request n cores or task per node


cd /shared
mpirun hello_world_c

