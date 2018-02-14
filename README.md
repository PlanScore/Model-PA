Pennsylvania Model
===

PlanScore bases its scores on predicted votes for each office: State House, State Senate, and U.S. House.  We generate these predicted votes using demographic and political variables entered into an ordinary least squares regression model. 

To predict turnout we regress total major-party vote for the race in question on total major-party presidential vote.  To predict vote share we regress the Democratic share of the major-party vote on the Democratic share of the major-party presidential vote and the white share of the voting-age population.  Using the coefficients and standard errors from these models, we then generate 1000 simulated total votes and Democratic vote shares for each precinct.  These numbers are the inputs for calculating 1000 sets of efficiency gaps, partisan biases, and mean-median differences, which produce the means and margins of error reported on the site.

Model coefficients, standard errors, and goodness-of-fit statistics are in the tables below.
