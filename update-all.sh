#!/bin/bash
# Compare all the files in directory 1 with the files in directory 2
# Replace older versions in dir 2 with newer versions in dir 1
# If no older version exists, copy file from dir 1 to dir 2

# rsync -at --include '*.draft' --exclude '*' draft/ live/

# to be honest maybe a new rsync command for each update script

# Update css

rsync -at --include '*.css' --exclude '*' draft/css/ live/

# Update images

rsync -at draft/images live/images

# Update single pages



# Update blog
