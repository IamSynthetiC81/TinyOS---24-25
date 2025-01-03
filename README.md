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
python mySimulation.py path/to/topology.txt path/to/logfile
```

Με τον παραπάνω τρόπο, αποθηκεύουμε την έξοδο του προγράμματος σε ένα αρχείο (.log αρχεία φουλεύουν καλύτερα) και παράλληλα τρέχουμε και προγράμματα ανάλυσης τα οποία αναλύουν το δέντρο και εντοπίζουν χαμένα μυνήματα.


Η έξοδος του αρχείου ανάλυσης έχει την εξής μορφή:

```log
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
