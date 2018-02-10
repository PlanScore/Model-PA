all: PA-Precinct-Model.US-House-2016.votes.geojson \
     PA-Precinct-Model.PA-House-2016.votes.geojson \
     PA-Precinct-Model.PA-Senate-2016.votes.geojson

# Spatial votes are calculated from raw votes and geographic areas
%.geojson: %.csv.gz
	./merge-layers.py PA-Geographies.gpkg $< $@

# Raw votes are calculated from Dem proportion and turnout estimates
%.votes.csv.gz: %.propD.csv.gz %.turnout.csv.gz
	./premultiply.py $^ $@
