#!/bin/bash

#SBATCH --job-name=NPhAnToM_%j
#SBATCH --output=/projects/mjolnir1/people/%u/nextflowout/%j_stdout
#SBATCH --error=/projects/mjolnir1/people/%u/nextflowout/errors_%j
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=4G
#SBATCH --time=10:00:00
#SBATCH --mail-type=begin
#SBATCH --mail-type=end
#SBATCH --mail-type=fail


mkdir -p /maps/projects/mjolnir1/people/${USER}/SingularityTMP
export SINGULARITY_LOCALCACHEDIR="/maps/projects/mjolnir1/people/${USER}/SingularityTMP"
export SINGULARITY_TMPDIR="/maps/projects/mjolnir1/people/${USER}/SingularityTMP"



export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)
export NXF_CONDA_ENABLED=true

module purge
module load openjdk/20.0.0
module load singularity/3.8.0 nextflow miniconda/4.11.0


# srun nextflow run NPhAnToM.nf ${SRRNUMBER} -profile ${PROFILE} ${RESUME} -with-mpi -with-tower --accessToken ${TOWERTOKEN} --minLength ${MINLENGTH} --contigs ${CONTIGS}
srun nextflow run NPhAnToM.nf $@ 
