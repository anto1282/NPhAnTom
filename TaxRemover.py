#!/usr/bin/python3

def EuRemover(read1TrimmedSub, read2TrimmedSub):
    infile = open("Report.kraken.txt", "r")
    Flag = False
    TaxIDSet = set()

    for line in infile:
        if line.split()[-1] == "Eukaryota":
            Flag = True
        if line.split()[-1] == "Archaea":
            Flag = False
            break
        if Flag == True:
            TaxIDSet.add(line.split()[-2])
    infile.close()

    Flag = False

    ReadNumSet = set()
    infile = open("Read.kraken")

    for line in infile:
        if line.split()[2] in TaxIDSet:
            ReadNumSet.add(line.split()[1])

    TaxIDSet.clear()
    infile.close()

    infile1 = open(read1TrimmedSub)
    infile2 = open(read2TrimmedSub)
    OutName1 = "read_1_TrimmedSubNoEu.txt"
    OutName2 = "read_2_TrimmedSubNoEu.txt"
    outfile1 = open(OutName1,"w")
    outfile2 = open(OutName2, "w")


    for line in infile1:
        if line[0] == "@":
            if line.split()[0][1:] in ReadNumSet:
                Flag = True
            else:
                Flag = False
        if Flag == False:
            print(line.strip(), file = outfile1)
        if Flag == True:
            print(line.strip())
    infile1.close()
    outfile1.close()

    for line in infile2:
        if line[0] == "@":
            if line.split()[0][1:] in ReadNumSet:
                Flag = True
            else:
                Flag = False
        if Flag == False:
            print(line.strip(), file = outfile2)
        if Flag == True:
            print(line.strip())
    
    ReadNumSet.clear()
    infile2.close()
    outfile2.close()

    return OutName1, OutName2
