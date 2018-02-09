all: PA-Precinct-Model.US-House-2016.votes.csv.gz \
     PA-Precinct-Model.PA-House-2016.votes.csv.gz \
     PA-Precinct-Model.PA-Senate-2016.votes.csv.gz

# Raw votes are calculated from Dem proportion and turnout estimates
%.votes.csv.gz: %.propD.csv.gz %.turnout.csv.gz
	./premultiply.py $^ $@
