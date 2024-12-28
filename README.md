Για να κάνουμε compile to helperFile

```bash
gcc -o helperFile helperFile.c -lm
```
Για να κάνουμε compile τον κώδικα του tinyOS

```bash
make micaz sim
```

Για να τρέξουμε τον κώδικα του tinyOS

```bash
python mySimulation.py path/to/topology.txt
```

Για να τρέξει το scrpt της ανάλυσης των αποτελεσμάτων πρέπει να τρέξουμε το παρακάτω

```bash
# pipe the output of the simulation to a file
python mySimulation.py path/to/topology.txt > path/to/output.txt
# run the analysis script with the output file as an argument
python LostMessagesAnalysis.py path/to/output.txt
```

Η έξοδος του αρχείου ανάλυσης έχει την εξής μορφή:

```txt
0
 +-- 1
 |   +-- 2
 |   |   +-- 3
 |   |   |   +-- 4
 |   |   |   +-- 9
 |   |   +-- 8
 |   +-- 7
 +-- 5
 |   +-- 11
 |   +-- 10
 |       +-- 15
 |           +-- 20
 +-- 6
     +-- 12
         +-- 13
         |   +-- 19
         +-- 17
         |   +-- 21
         +-- 16
         +-- 18
             +-- 24
             +-- 22
             +-- 23
             +-- 14
Node  0  is missing messages from  ['6']  on epoch  2
Node  2  is missing messages from  ['8']  on epoch  3
Node  18  is missing messages from  ['22']  on epoch  5
Node  0  is missing messages from  ['1']  on epoch  11
```
