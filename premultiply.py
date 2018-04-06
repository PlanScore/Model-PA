#!/usr/bin/env python3
import csv, sys, statistics, gzip, argparse

parser = argparse.ArgumentParser()
parser.add_argument('--100', dest='scale', default=1, action='store_const', const=100)
parser.add_argument('--year', dest='year', action='store_true')
parser.add_argument('open')
parser.add_argument('turnout')
parser.add_argument('votes')
args = parser.parse_args()
off = 9 if args.year else 7

with gzip.open(args.open, 'rt') as file1, gzip.open(args.turnout, 'rt') as file2:
    rows1 = csv.reader(file1)
    rows2 = csv.reader(file2)
    
    head1, head2 = next(rows1), next(rows2)

    if head1[:off] != head2[:off] or len(head1) != 1000+off or len(head2) != 1000+off:
        print(off, len(head1), len(head2))
        raise Exception()
    
    with gzip.open(args.votes, 'wt') as file3:
        columns = ['cntyname', 'mcdname', 'vtdname', 'name', 'stf', 'psid']
        for i in range(1000):
            columns += [f'DEM{i:03d}', f'REP{i:03d}']
        
        out = csv.writer(file3)
        out.writerow(columns)
        
        for (row1, row2) in zip(rows1, rows2):
            row = row1[2:8] if args.year else row1[1:7]
            propDs = list(map(float, row1[off:]))
            turnouts = [float(val) * args.scale for val in row2[off:]]
            
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
