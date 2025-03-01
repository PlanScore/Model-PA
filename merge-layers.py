#!/usr/bin/env python3
import sys, argparse, gzip, csv, re, collections, logging, json, math
from osgeo import ogr

logging.basicConfig(stream=sys.stderr, level=logging.INFO, format='%(levelname)09s - %(message)s')

parser = argparse.ArgumentParser(description='Merge layers and votes')
parser.add_argument('geo_name', help='Spatial file with layers and areas')
parser.add_argument('pres_votecsv_name', help='Tabular CSV file with Presidential vote counts')
parser.add_argument('acs_name', help='Tabular CSV file with ACS population')
parser.add_argument('census_name', help='Tabular CSV file with Census population')
parser.add_argument('votecsv_name', help='Tabular CSV file with vote counts')
parser.add_argument('out_name', help='Output GeoJSON file with areas and votes')

args = parser.parse_args()

logging.info('Reading ACS population from {}...'.format(args.acs_name))

populations = collections.defaultdict(lambda: collections.defaultdict(int))

with open(args.acs_name, 'r') as acs_file:
    rows = csv.DictReader(acs_file)
    vpop_keys = [f'B010010{male:02d}' for male in range(7, 26)] \
              + [f'B010010{female:02d}' for female in range(31, 50)]
    
    for row in rows:
        geoid, _ = row.pop('geoid'), row.pop('name')
        populations[geoid]['Population 2016'] = int(row['B01001001'])
        populations[geoid]['Population 2016, Error'] = int(row['B01001001, Error'])
        populations[geoid]['Households 2016'] = int(row['B11001001'])
        populations[geoid]['Households 2016, Error'] = int(row['B11001001, Error'])
        populations[geoid]['Black Population 2016'] = int(row['B02009001'])
        populations[geoid]['Black Population 2016, Error'] = int(row['B02009001, Error'])
        populations[geoid]['Hispanic Population 2016'] = int(row['B03002012'])
        populations[geoid]['Hispanic Population 2016, Error'] = int(row['B03002012, Error'])
        populations[geoid]['Household Income 2016'] = int(row['B19013001'])
        populations[geoid]['Household Income 2016, Error'] = int(row['B19013001, Error'])
        
        vpop = [int(row[k]) for k in vpop_keys]
        populations[geoid]['Voting-Age Population 2016'] = sum(vpop)

        vpop_var = [int(row[f'{k}, Error']) ** 2 for k in vpop_keys]
        populations[geoid]['Voting-Age Population 2016, Error'] = round(math.sqrt(sum(vpop_var)))
        
        populations[geoid]['Education Population 2016'] = int(row['B15003001'])
        populations[geoid]['Education Population 2016, Error'] = int(row['B15003001, Error'])

        populations[geoid]['High School or GED 2016'] = \
            int(row['B15003017']) + int(row['B15003018'])
        populations[geoid]['High School or GED 2016, Error'] = \
            int(math.sqrt(int(row['B15003017, Error'])**2 + int(row['B15003018, Error'])**2))

logging.info('Read population for {} areas.'.format(len(populations)))
logging.info('Reading vote counts from {}...'.format(args.votecsv_name))

votes = collections.defaultdict(lambda: collections.defaultdict(float))
column_pattern1 = re.compile(r'^(DEM|REP)\d+$')

with gzip.open(args.votecsv_name, 'rt') as file2:
    rows = csv.DictReader(file2)
    
    for row in rows:
        #break
        psid = int(row['psid'].split(':', 2)[1])
        for (key, value) in row.items():
            if column_pattern1.match(key):
                votes[psid][key] += float(value)

logging.info('Read counts for {} areas.'.format(len(votes)))
logging.info('Reading presidential vote counts from {}...'.format(args.pres_votecsv_name))

column_pattern2 = re.compile(r'^US ')

with gzip.open(args.pres_votecsv_name, 'rt') as file2:
    rows = csv.DictReader(file2)
    
    for row in rows:
        #break
        psid = int(row['psid'].split(':', 2)[1])
        for (key, value) in row.items():
            if column_pattern2.match(key):
                votes[psid][key] += float(value)

logging.info('Read presidential counts for {} areas.'.format(len(votes)))

ds = ogr.Open(args.geo_name)
features_json = list()

logging.info('Reading Census population from {}...'.format(args.census_name))

with gzip.open(args.census_name, 'rt') as census_file:
    for row in csv.DictReader(census_file):
        geometry = dict(type='Point', coordinates=[float(row['lon']), float(row['lat'])])
        feature_json = dict(type='Feature', geometry=geometry, properties={})
        for (key, value) in row.items():
            if key in ('lat', 'lon'):
                continue
            elif key == 'geoid':
                feature_json['properties'][key] = value
            else:
                try:
                    property = int(value)
                except ValueError:
                    property = round(float(value), 3)
                finally:
                    feature_json['properties'][key] = property
        features_json.append(json.dumps(feature_json, sort_keys=True))

block_count = len(features_json)
logging.info('Read population for {} blocks.'.format(block_count))
logging.info('Reading areas from {}...'.format(args.geo_name))

for feature in ds.GetLayer('tracts'):
    feature_json = json.loads(feature.ExportToJson())
    properties = feature_json['properties']
    feature_geoid = properties['geoid']
    properties.update(populations[f'14000US{feature_geoid}'])
    features_json.append(json.dumps(feature_json, sort_keys=True))

for feature in ds.GetLayer('precincts'):
    feature_json = json.loads(feature.ExportToJson())
    properties = feature_json['properties']
    properties.update({key: round(value, 1) for (key, value)
        in votes[properties['psid']].items()})
    features_json.append(json.dumps(feature_json, sort_keys=True))

logging.info('Read {} areas.'.format(len(features_json) - block_count))
logging.info('Writing areas to {}...'.format(args.out_name))

with open(args.out_name, 'w') as file3:
    print('{"type": "FeatureCollection", "features": [', file=file3)
    print(',\n'.join(features_json), file=file3)
    print(']}', file=file3)
