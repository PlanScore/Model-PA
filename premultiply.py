#!/usr/bin/env python3
import csv, sys, statistics, gzip

filename1, filename2, filename3 = sys.argv[1:]

with gzip.open(filename1, 'rt') as file1, gzip.open(filename2, 'rt') as file2:
    rows1 = csv.reader(file1)
    rows2 = csv.reader(file2)
    
    head1, head2 = next(rows1), next(rows2)
    
    if head1[:7] != head2[:7] or len(head1) != 1009 or len(head2) != 1008:
        raise Exception()
    
    with gzip.open(filename3, 'wt') as file3:
        columns = ['cntyname', 'mcdname', 'vtdname', 'name', 'stf', 'psid']
        for i in range(1000):
            columns += [f'DEM{i:03d}', f'REP{i:03d}']
        
        out = csv.writer(file3)
        out.writerow(columns)
        
        for (row1, row2) in zip(rows1, rows2):
            row = row1[1:7]
            propDs = list(map(float, row1[9:]))
            turnouts = list(map(float, row2[8:]))
            
            print(' '.join(row),
                #'{:.3f} ±{:.3f}'.format(statistics.mean(propDs),
                #statistics.stdev(propDs)),
                #'{:.0f} ±{:.0f}'.format(statistics.mean(turnouts),
                #statistics.stdev(turnouts)),
                file=sys.stderr)
            
            for (propD, turnout) in zip(propDs, turnouts):
                dem_votes = propD * turnout
                rep_votes = turnout - dem_votes
                row += [f'{dem_votes:.1f}', f'{rep_votes:.1f}']
            
            out.writerow(row)
