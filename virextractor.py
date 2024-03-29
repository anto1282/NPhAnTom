#!/usr/bin/env python3


#Program that extracts viral contigs from various phage prediction tools

import sys, os

contigfile = str(sys.argv[1])
outputfilename = str(sys.argv[2])
dvfcutoff = float(sys.argv[3])
dvffile = str(sys.argv[4])
seekercutoff = float(sys.argv[5])
seekerfile = str(sys.argv[6])
phagerfile = str(sys.argv[7])
intersectionOrUnion = str(sys.argv[8])

DVFset = set()
def DVFExtract(DVFfile,dvfcutoff):
    linecount = 0
    for line in DVFfile:
        if linecount > 0:
            if float(line.split()[2]) > dvfcutoff:
                DVFset.add(line.split()[0])
        linecount += 1
    return DVFset




SeekerSet = set()
def SeekerExtract(SeekerInFile, seekercutoff):
    SeekerFlag = False
    for line in SeekerInFile:
        if len(line) == 1:
            continue
        if SeekerFlag == True:
            if line.split()[1]== "Phage" and float(line.split()[-1]) > seekercutoff:
                SeekerSet.add(line.split()[0])
        if line.split()[0] =="name":
            SeekerFlag = True
    return  SeekerSet               



PhagerSet = set()
def PhagerExtract(file):
    linecount = 0
    for line in file:
        if linecount > 0:
            if int(line.split()[3]) == 1:
                PhagerSet.add(line.split()[1])
        linecount += 1
    return PhagerSet


try:
    DVFfile = open(dvffile,"r")
    SeekerInFile = open(seekerfile,"r")
    PhagerInfile = open(phagerfile,"r")
except FileNotFoundError:  
    sys.exit(1)
            
DVFset = DVFExtract(DVFfile,dvfcutoff)
SeekerSet = SeekerExtract(SeekerInFile, seekercutoff)
PhagerSet = PhagerExtract(PhagerInfile)



print(DVFset)
print(SeekerSet)
print(PhagerSet)

if intersectionOrUnion == "intersection":
    #Creates intersection of each of the three pairs of sets, and then takes the union of the intersections
    SeekerDVFInter = SeekerSet.intersection(DVFset)
    SeekerPhagerInter = SeekerSet.intersection(PhagerSet)
    DVFPhagerInter = DVFset.intersection(PhagerSet)

    final_viral_set = SeekerDVFInter.union(SeekerPhagerInter,DVFPhagerInter)

elif intersectionOrUnion == "union":
    #The union of the three sets, used if the virus predictors have a hard time predicting viruses on a specific dataset
    final_viral_set = SeekerSet.union(DVFset,PhagerSet)





with open("vir_pred_file.tsv",'w') as pred_file:
    #Writes header to file
    pred_file.write("Phagename\tPred_counts\tSeeker\tPhager\tDVF\n")
    for phage in sorted(final_viral_set):
        Seeker, Phager, DVF = False, False, False
        if phage in SeekerSet:
            Seeker = True
        if phage in PhagerSet:
            Phager = True
        if phage in DVFset:
            DVF = True
        pred_string = "\t".join([phage, str([Seeker,Phager,DVF].count(True)), str(Seeker), str(Phager), str(DVF)]) + "\n"
        pred_file.write(pred_string)



#Prints out all phages into one file
with open(contigfile, 'r') as file:
    virusflag = False

    seqcount = 0
    if len(final_viral_set) >= 1:
        seqlength = 0
        virusoutfile = open(outputfilename,'w')
        for line in file:

            if line.startswith(">") and line[1:].strip().split()[0] in final_viral_set:
                virusflag = True
                virusoutfile.write(line)
                seqcount += 1
                print("Phage in viral set:", line)
            elif line.startswith(">"):
                virusflag = False             
                
            elif virusflag == True:
                virusoutfile.write(line)
                if len(final_viral_set) == 1:
                    seqlength += len(line.strip())
        virusoutfile.close()
        print("Final viral set: ", final_viral_set)
        print("Length of final viral set:", len(final_viral_set))
        if len(final_viral_set) == 1 and seqlength < 20000:
            newname = "SINGLEPHAGE" + outputfilename
            os.rename(outputfilename,newname)
            print("Only found one phage with length:", seqlength, "bp")
            print("Output file not useful, renamed it so pipeline stops")
        else:
            print("Sequences written to", outputfilename + ":", seqcount)
        
    
    else:
        print("No viruses was predicted by the virus prediction tools")



